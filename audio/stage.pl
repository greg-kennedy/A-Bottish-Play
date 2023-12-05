#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Assemble stage direction phrases out of individual recorded words

open my $fp, '<', $ARGV[0];
my @lines = <$fp>;
close $fp;

my %w;
foreach my $line (@lines) {
  chomp $line;

  my $hex = md5_hex($line);

  $line = uc($line);
  $line =~ s/-/ /g;
  $line =~ s/[()':]//g;

  # numbers to phonetic
  $line =~ s/0/ZERO/g;
  $line =~ s/1/ONE/g;
  $line =~ s/2/TWO/g;
  $line =~ s/3/THREE/g;
  $line =~ s/4/FOUR/g;
  $line =~ s/5/FIVE/g;
  $line =~ s/6/SIX/g;
  $line =~ s/7/SEVEN/g;
  $line =~ s/8/EIGHT/g;
  $line =~ s/9/NINE/g;

  $line =~ s/([^A-Z0-9])/ $1 /g;
  $line =~ s/^\s*//g;
  $line =~ s/\s*$//g;

  print "sox ";
  my $q = 0;
  foreach my $word (split /\s+/, $line) {
    if ($word eq '!' || $word eq '?' || $word eq '.') {
      print "words/silence-long.flac ";
      $q = 2;
    } elsif ($word eq ',' || $word eq '"') {
      print "words/silence-short.flac ";
      $q = 1;
    } else {
      print "words/" . $word . ".flac ";
      $q = 0;
    }
  }

  if ($q == 0) { print "words/silence-long.flac "; }
  elsif ($q == 1) { print "words/silence-short.flac "; }

  say "$hex.flac";
}
