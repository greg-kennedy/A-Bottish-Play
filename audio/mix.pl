#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Mixes multi-character speeches together

open my $fp, '<', $ARGV[0];

foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  # Mix all entries together w/ Sox into a wave file
  my @aud_files  = glob("$hex.*.mp3 $hex.*.wav");

  `rm -rf /tmp/mix_tmp`;
  `mkdir -p /tmp/mix_tmp`;

  my $i = 0;
  foreach my $file (@aud_files) {
    print "== $file\n";
    my $dest_file = "/tmp/mix_tmp/$i.wav";
    if ($file =~ m/\.wav$/) {
      `sox --norm $file -r 44100 -b16 $dest_file`;
      $i ++;
    } elsif ( $file =~ m/\.mp3$/) {
      `ffmpeg -i $file /tmp/crap.wav`;
      `sox --norm /tmp/crap.wav -r 44100 -b16 $dest_file`;
      `rm /tmp/crap.wav`;
    } else {
      die "eh";
    }

    `./wavegain -y $dest_file`;

    $i ++;
  }

  `sox --norm -m /tmp/mix_tmp/*.wav $hex.wav`;
}

close $fp;
