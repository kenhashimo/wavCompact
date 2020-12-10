use strict;
use warnings;
use File::Temp;
use IO::Handle;

#
# ========== WAV�t�@�C����Z�k���� ====================================
#
# Usage: %data = &mutecut(\%data);
#   In:  $data{'infile'} = ����WAV�t�@�C����
#        $data{'outfile'} = �o��WAV�t�@�C����
#        $data{'thres'} = �������肵�����l (0�`1)
#        $data{'time_b'} = �ύX�ΏۂƂȂ�ŏ��������� [�b]
#        $data{'time_a'} = �����Z�k��
#                          (0���Ə��time_b�ɂȂ� 1���ƒZ�k����Ȃ�)
#        $data{'tmp'} = �e���|�����f�B���N�g��(�ȗ����͎�������)
#   Out: $data{'error'} = �G���[���b�Z�[�W�BOK�̏ꍇ�� ''

sub mutecut {

  my %data = %{$_[0]};
  my ($d, $infile, $i, $buf, $outlen, $tmp, $tmpf);
  my ($srate);             # �T���v�����O���[�g[Hz] (44100 �Ȃ�)
  my ($nsmpl);             # �T���v����
  my ($thres);             # �������l (0�`128 or 0�`32768)
  my ($timeb);             # �ŏ��������� [�T���v����]
  my ($timea);             # �����Z�k�� (�������̂܂�)
  my ($bs);                # �o�C�g/�T���v�� (1or2)
  my ($cha);               # ���m����=1 �X�e���I=2
  my ($fp0);

  ($infile, $data{'error'}) = ($data{'infile'}, '');
  $fp0 = IO::Handle -> new();

  unless (open $fp0, '< ' . $infile) {
    # $infile �̃I�[�v���Ɏ��s
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���I�[�v���o���܂���B';
    return %data;
  }
  binmode $fp0;

  unless (seek($fp0, 0x14, 0)) {
    # $infile �̃V�[�N�Ɏ��s
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')��seek�o���܂���B';
    return %data;
  }
  unless (read($fp0, $d, 2)) {
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(1)�B';
    return %data;
  }
  $d = unpack('n', reverse($d));
  unless ($d == 1) {
    # �񈳏k PCM �łȂ�
    $data{'error'} .= '���̓t�@�C��(' . $infile .
      ')���񈳏kPCM�t�H�[�}�b�g�ł͂���܂���B';
  }
  unless (read($fp0, $d, 2)) {
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(2)�B';
    return %data;
  }
  $cha = unpack('n', reverse($d));
  if ($cha != 1 && $cha != 2) {
    # ���m�ł��X�e���I�ł��Ȃ�
    $data{'error'} .= '���̓t�@�C��(' . $infile .
      ')�����m�����ł��X�e���I�ł�����܂���B';
  }
  unless (read($fp0, $d, 4)) {
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(3)�B';
    return %data;
  }
  $srate = unpack('N', reverse($d));
  $timeb = $data{'time_b'} * $srate;
  $data{'error'} .= '����time_b�������ł��B' if ($timeb < 0);
  $timea = $data{'time_a'};
  $data{'error'} .= '����time_a�������ł��B' if ($timea < 0);
  unless (seek($fp0, 0x22, 0)) {
    # $infile �̃V�[�N�Ɏ��s
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')��seek�o���܂���B';
    return %data;
  }
  unless (read($fp0, $d, 2)) {
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(4)�B';
    return %data;
  }
  $d = unpack('n', reverse($d));
  if ($d != 8 && $d != 16) {
    # 8�r�b�g�ł�16�r�b�g�łȂ�
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')�̃T���v���r�b�g��(' .
      $d . ')���s���ł��B';
  }
  if ($data{'error'}) {
    close $fp0;
    return %data;
  }
  ($bs, $thres) = ($d / 8, $data{'thres'} * 2 ** ($d - 1));
  if ($thres < 0 || $thres > 2 ** ($d - 1)) {
    $data{'error'} .= '����thres�̒l���s���ł��B';
  }
  unless (seek($fp0, 0x28, 0)) {
    # $infile �̃V�[�N�Ɏ��s
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')��seek�o���܂���B';
    return %data;
  }
  unless (read($fp0, $d, 4)) {
    close $fp0;
    $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(5)�B';
    return %data;
  }
  $nsmpl = unpack('N', reverse($d));
  $nsmpl /= $bs * $cha;
  if (int($nsmpl) != $nsmpl) {
    $data{'error'} .= '���̓t�@�C��(' . $infile .
      ')�̃f�[�^���̃T�C�Y��' . ($bs * $cha) . '�̔{���ł���܂���B';
  }
  if ($data{'tmp'}) {
    ($tmp, $tmpf) = File::Temp::tempfile(DIR => $data{'tmp'});
  }
  else {
    $tmp = File::Temp::tempfile();
  }
  unless ($tmp) {
    # �I�[�v���Ɏ��s
    close $fp0;
    $data{'error'} .= '�e���|�����t�@�C�����I�[�v���o���܂���B';
  }
  if ($data{'error'}) {
    close $fp0;
    return %data;
  }
  binmode $tmp;
  ($outlen, $buf) = (0, '');

  for ($i = 0; $i < $nsmpl; $i ++) {
    my (@sd, $j);

    ($d, $sd[1]) = ('', 0);
    for ($j = 0 ; $j < $cha; $j ++) {
      my ($d0);
      unless (read($fp0, $d0, $bs)) {
        close $fp0;
        close $tmp;
        unlink $tmpf if ($data{'tmp'});
        $data{'error'} .= '���̓t�@�C��(' . $infile . ')���ǂݍ��߂܂���(6)�B';
        return %data;
      }
      if ($bs == 2) {
        $sd[$j] = unpack('n', reverse($d0));
        $sd[$j] -= 65536 if ($sd[$j] > 32767);
      }
      else {
        $sd[$j] = unpack('C', $d0) - 127;
      }
      $d .= $d0;
    }
    if (abs($sd[0]) > $thres || abs($sd[1]) > $thres) {
      my ($outadd);
      $outadd = &tachiagari($buf, $timeb, $timea, $bs, $cha);
      unless (print $tmp $outadd) {
        close $tmp;
        unlink $tmpf if ($data{'tmp'});
        close $fp0;
        $data{'error'} .= '�e���|�����t�@�C���ɏ������߂܂���(1)�B';
        return %data;
      }
      $outlen += length($outadd);
      $buf = '';
      unless (print $tmp $d) {
        close $tmp;
        unlink $tmpf if ($data{'tmp'});
        close $fp0;
        $data{'error'} .= '�e���|�����t�@�C���ɏ������߂܂���(2)�B';
        return %data;
      }
      $outlen += length($d);
    }
    else {
      $buf .= $d;
    }
  }
  close $fp0;
  if ($buf ne '') {
    my ($outadd);
    $outadd = &tachiagari($buf, $timeb, $timea, $bs, $cha);
    unless (print $tmp $outadd) {
      close $tmp;
      unlink $tmpf if ($data{'tmp'});
      $data{'error'} .= '�e���|�����t�@�C���ɏ������߂܂���(3)�B';
      return %data;
    }
    $outlen += length($outadd);
  }
  unless (seek($tmp, 0, 0)) {
    close $tmp;
    unlink $tmpf if ($data{'tmp'});
    $data{'error'} .= '�e���|�����t�@�C����seek�o���܂���B';
    return %data;
  }

  {
    my ($head, $riffsize, $fmtsize, $c, $fp1);

    $fmtsize = 16;
    $riffsize = 12 + $fmtsize + 8 + $outlen;

    $head = 'RIFF' . reverse(pack('N', $riffsize));
    $head .= 'WAVEfmt ';
    $head .= reverse(pack('N', $fmtsize));
    $head .= reverse(pack('n', 1));
    $head .= reverse(pack('n', $cha));
    $head .= reverse(pack('N', $srate));
    $head .= reverse(pack('N', $srate * $bs * $cha));
    $head .= reverse(pack('n', $bs * $cha));
    $head .= reverse(pack('n', 8 * $bs));
    $head .= 'data';
    $head .= reverse(pack('N', $outlen));

    $fp1 = IO::Handle -> new();

    unless (open $fp1, '> ' . $data{'outfile'}) {
      # �I�[�v���Ɏ��s
      close $fp1;
      close $tmp;
      unlink $tmpf if ($data{'tmp'});
      $data{'error'} .= '�o�̓t�@�C��(' . $data{'outfile'} .
        ')���I�[�v���o���܂���B';
      unlink $data{'outfile'};
      return %data;
    }
    binmode $fp1;
    unless (print $fp1 $head) {
      close $tmp;
      unlink $tmpf if ($data{'tmp'});
      close $fp1;
      $data{'error'} .= '�o�̓t�@�C��(' . $data{'outfile'} .
        ')�ɏ������߂܂���B';
      unlink $data{'outfile'};
      return %data;
    }
    while (read($tmp, $c, 1)) {
      unless (print $fp1 $c) {
        close $tmp;
        unlink $tmpf if ($data{'tmp'});
        close $fp1;
        $data{'error'} .= '�o�̓t�@�C��(' . $data{'outfile'} .
          ')�ɏ������߂܂���B';
        unlink $data{'outfile'};
        return %data;
      }
    }
    close $tmp;
    unlink $tmpf if ($data{'tmp'});
    close $fp1;
  }

  return %data;

}


sub tachiagari {
  my ($buf, $timeb, $timea, $bs, $cha) = @_;
  my $o;

  if (length($buf) <= $timeb * $bs * $cha) {
    $o = $buf;
  }
  else {
    my ($olen, $nlen);
    $olen = length($buf) / ($bs * $cha);
    $nlen = int($timeb + ($olen - $timeb) * $timea);
    if ($nlen * 2 > $olen) {
      my ($len0, $len1, $len2, $i);
      $len1 = $olen - $nlen;
      $len0 = int(($nlen - $len1) / 2);
      $len2 = $nlen - $len0 - $len1;
      $o = substr($buf, 0, $len0 * $bs * $cha);
      $buf = substr($buf, $len0 * $bs * $cha);
      for ($i = 0; $i < $len1; $i ++) {
        my ($d0, $d1, @sd0, @sd1, $d2, $sd2, $j);
        $d0 = substr($buf, $i * $bs * $cha, $bs * $cha);
        $sd0[1] = 0;
        for ($j = 0; $j < $cha; $j ++) {
          my ($d00);
          $d00 = substr($d0, $bs * $j, $bs);
          if ($bs == 2) {
            $sd0[$j] = unpack('n', reverse($d00));
            $sd0[$j] -= 65536 if ($sd0[$j] > 32767);
          }
          else {
            $sd0[$j] = unpack('C', $d00) - 127;
          }
        }
        $d1 = substr($buf, ($i + $olen - $nlen) * $bs * $cha, $bs * $cha);
        $sd1[1] = 0;
        for ($j = 0; $j < $cha; $j ++) {
          my ($d10);
          $d10 = substr($d1, $bs * $j, $bs);
          if ($bs == 2) {
            $sd1[$j] = unpack('n', reverse($d10));
            $sd1[$j] -= 65536 if ($sd1[$j] > 32767);
          }
          else {
            $sd1[$j] = unpack('C', $d10) - 127;
          }
        }
        $d2 = '';
        for ($j = 0; $j < $cha; $j ++) {
          $sd2 = int(($i + 1) / ($len1 + 1) * $sd1[$j]
                     + ($len1 - $i) / ($len1 + 1) * $sd0[$j]);
          if ($bs == 2) {
            $sd2 += 65536 if ($sd2 < 0);
            $sd2 = 0 if ($sd2 < 0);
            $sd2 = 65535 if ($sd2 > 65535);
            $d2 .= reverse(pack('n', $sd2));
          }
          else {
            $sd2 += 127;
            $sd2 = 0 if ($sd2 < 0);
            $sd2 = 255 if ($sd2 > 255);
            $d2 .= pack('C', $sd2);
          }
        }
        $o .= $d2;
      }
      $buf = substr($buf, ($len1 + $olen - $nlen) * $bs * $cha,
             $len2 * $bs * $cha);
      $o .= $buf;
    }
    else {
      my ($i);
      $o = '';
      for ($i = 0; $i < $nlen; $i ++) {
        my ($d0, $d1, @sd0, @sd1, $d2, $sd2, $j);
        ($d0, $sd0[1]) = (substr($buf, $i * $bs * $cha, $bs * $cha), 0);
        for ($j = 0; $j < $cha; $j ++) {
          my ($d00);
          $d00 = substr($d0, $bs * $j, $bs);
          if ($bs == 2) {
            $sd0[$j] = unpack('n', reverse($d00));
            $sd0[$j] -= 65536 if ($sd0[$j] > 32767);
          }
          else {
            $sd0[$j] = unpack('C', $d00) - 127;
          }
        }
        $d1 = substr($buf, ($i + $olen - $nlen) * $bs * $cha, $bs * $cha);
        $sd1[1] = 0;
        for ($j = 0; $j < $cha; $j ++) {
          my ($d10);
          $d10 = substr($d1, $bs * $j, $bs);
          if ($bs == 2) {
            $sd1[$j] = unpack('n', reverse($d10));
            $sd1[$j] -= 65536 if ($sd1[$j] > 32767);
          }
          else {
            $sd1[$j] = unpack('C', $d10) - 127;
          }
        }
        $d2 = '';
        for ($j = 0; $j < $cha; $j ++) {
          $sd2 = int($i / ($nlen - 1) * $sd1[$j]
                     + ($nlen - 1 - $i) / ($nlen - 1) * $sd0[$j]);
          if ($bs == 2) {
            $sd2 += 65536 if ($sd2 < 0);
            $sd2 = 0 if ($sd2 < 0);
            $sd2 = 65535 if ($sd2 > 65535);
            $d2 .= reverse(pack('n', $sd2));
          }
          else {
            $sd2 += 127;
            $sd2 = 0 if ($sd2 < 0);
            $sd2 = 255 if ($sd2 > 255);
            $d2 .= pack('C', $sd2);
          }
        }
        $o .= $d2;
      }
    }
  }

  return $o;
}

1;
