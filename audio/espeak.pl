#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Uses eSpeak on Linux to record lines

# siward
my $voice = "mb-en1";
# young siward
#my $voice = "mb-us2";
# messengers
#my $voice = "en-us";
#my $voice = "en-gb";
#my $voice = "en-sc";

# Just a reader for eSpeak
open my $fp, '<', $ARGV[0];
foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  $line =~ s/ 't([ .,?])/ it$1/ig;

  # write line to text for reading
  open my $fpo, '>', $hex . ".txt";
  print $fpo $line;
  close $fpo;

  # espeak goes fast!  so slow it down to just 150 from default 175 wpm.

  my $result = system( "/usr/bin/espeak -v $voice -s 150 -f $hex.txt -w $hex.wav");
  #my $result = system( "/usr/bin/espeak -v $voice -p 75 -f $hex.txt -w $hex.wav");
  if ($result != 0) { die "Result bad! $result reading $line" }
}
