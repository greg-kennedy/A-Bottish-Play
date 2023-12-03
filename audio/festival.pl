#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Makes a request to Festival's text2wave script
#  to record lines.

# Alan
my $voice = "voice_cmu_us_awb_arctic_clunits";

# James
#my $voice = "voice_cmu_us_jmk_arctic_clunits";

# Just a reader for Festival
open my $fp, '<', $ARGV[0];
foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  # pronunc. corrections
  $line =~ s/th' /the /ig;
  $line =~ s/i' /in /ig;
  $line =~ s/ 't([ .,?])/ it$1/ig;
  $line =~ s/ 't\./ it./ig;
  $line =~ s/ 's / us /ig;

  # write line to text for reading
  if (! -e $hex . ".txt") {
    open my $fpo, '>', $hex . ".txt";
    print $fpo $line;
    close $fpo;
  }

  # speak the phrase

  #my $result = system( "/usr/bin/espeak -v $voice -f $hex.txt");
  my $result = system( "/home/grkenn/src/festival/bin/text2wave -o $hex.wav -eval '($voice)' $hex.txt" );
  if ($result != 0) { die "Result bad! $result reading $line" }
}
my $result = system( "/home/grkenn/src/festival/bin/text2wave -o credit.wav -eval '($voice)' credit.txt" );
my $result = system( "/home/grkenn/src/festival/bin/text2wave -o meow.wav -eval '($voice)' meow.txt" );
