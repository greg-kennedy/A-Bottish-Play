#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

my $macbeth_words = 17959;

# oh god
my @aud_files  = glob("*/meow.flac */meow.mp3");

`rm -rf /tmp/mix_tmp`;
`mkdir -p /tmp/mix_tmp`;

my @lens;
my @left = ();
my @count = ();
for (my $i = 0; $i < scalar @aud_files; $i ++) {
  my $src_file = $aud_files[$i];
  my $dest_file = "/tmp/mix_tmp/$i.wav";
  `sox --norm $src_file -r 44100 -b16 $dest_file`;
  `./wavegain -y $dest_file`;

  $lens[$i] = `soxi -D $dest_file`;

  $count[$i] = 1;
  $left[$i] = $lens[$i];
}

# count how many of each meow to fit into the minimum time

my $meows = 50000 - $macbeth_words - scalar @count - 1;
while ($meows > 0) {
  # locate the lowest
  my $lowest = 0;
  my $amt = $left[0];
  for (my $i = 1; $i < scalar @left; $i ++) {
    if ($left[$i] < $amt) { $amt = $left[$i]; $lowest = $i }
  }

  # ok we found it, now: set that one to 0 and add its count
  #  and everyone else moves forward by that bit
  for (my $i = 0; $i < scalar @left; $i ++) {
    if ($i == $lowest) {
      $count[$i] ++;
      $left[$i] = $lens[$i];
    } else {
      $left[$i] -= $amt;
    }
  }
  $meows --;
}

# ok let's make huge chains
for (my $i = 0; $i < scalar @count; $i ++) {
  `sox /tmp/mix_tmp/$i.wav /tmp/mix_tmp/final_$i.wav repeat $count[$i]`;
}

# mix em
`sox --norm -m /tmp/mix_tmp/final_*.wav hell-meow.flac`;
