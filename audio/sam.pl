#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Speak with the Linux recompile of Don't Ask Software's "S.A.M."

open my $fp, '<', $ARGV[0];
foreach my $line (<$fp>) {
  chomp $line;

  if (length($line) > 100) {
    # Try to divide the line on punctuation -
    #  SAM only supports up to 255 chars, or less?!
    my $s = 0;
    foreach my $sentence (split /(?<=[;\.!\?,])/, $line) {
      if (substr($sentence, 0, 1) eq '-') { $sentence = ' ' . $sentence }
      die "Sentence too long: $sentence" if length($sentence) > 100;

      my $file = "/home/grkenn/macbeth/audio/Duncan/" . md5_hex($line) . "." . $s . ".wav";

      print "$s: $sentence\n";

      my @args = ( '/home/grkenn/src/SAM/sam', '-wav', $file, $sentence);
      #my $result = system { '/home/grkenn/src/SAM/sam' } ('-wav', $file, $sentence);
      my $result = system @args;
      if ($result != 0) { die "Result bad! $result reading $sentence" }
      $s ++;
    }

    # build sox concat thing
    my @args = ( 'sox', '-D' );
    for (my $i = 0; $i < $s; $i ++) {
      push @args, "/home/grkenn/macbeth/audio/Duncan/" . md5_hex($line) . "." . $i . ".wav";
      print "$i ...";
    }
    push @args, "/home/grkenn/macbeth/audio/Duncan/" . md5_hex($line) . ".wav";

    say "!";
    system @args;
    for (my $i = 0; $i < $s; $i ++) {
      unlink "/home/grkenn/macbeth/audio/Duncan/" . md5_hex($line) . "." . $i . ".wav";
    }
  } else {
    my $file = "/home/grkenn/macbeth/audio/Duncan/" . md5_hex($line) . ".wav";

    my @args = ( '/home/grkenn/src/SAM/sam', '-wav', $file, $line);
    #my $result = system { '/home/grkenn/src/SAM/sam' } ('-wav', $file, $line);
    my $result = system @args;
    if ($result != 0) { die "Result bad! $result reading $line" }
  }

}
