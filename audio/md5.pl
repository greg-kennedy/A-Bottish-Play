#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# for entries that don't have a way to do scripting,
#  this at least gives a line-to-md5 mapping

open my $fp, '<', $ARGV[0];

foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  say $hex . ": " . $line;
}

close $fp;
