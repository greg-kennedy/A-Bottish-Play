#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Build an AutoHotkey script to type into a window, and wait.
#  Used w/ Hatari to enter the SOLDIER lines!

open my $fp, '<', $ARGV[0];
open my $fpo, '>', 'CAPTAIN.ahk';

my $key = 'j';
say $fpo '^' . $key . '::{';

foreach my $line (<$fp>) {
  chomp $line;

  say $fpo "; " . md5_hex($line);

  # Try to divide the line on punctuation -
  foreach my $sentence (split /(?<=[;\.!\?,])\s*/, $line) {
    die "Sentence too long: $sentence" if length($sentence) > 255;

    say $fpo "\tSend \";" . $sentence . '{enter}"';
    say $fpo "\tSleep " . (2000 + length($sentence) * 100);
  }
  say $fpo "\tSleep 10000";
}

say $fpo '}';
$key ++;
