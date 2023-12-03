#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Speak with Dr. Sbaitso on MS-DOS
#  Batch file creates the commands to read the lines
#  record wave with ctrl+F6

my $name = "Doctor2";

open my $fp, '<', $ARGV[0];
open my $fpp, '>:crlf', "Doctor2.bat";

foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  open my $fps, '>:raw', $hex . ".txt";
  print $fps "$line";
  close $fps;

  say $fpp 'REM ' . $hex . ' ========================';
  say $fpp 'REM ' . substr($line, 0, 40) . "...";
  say $fpp 'READ.EXE < ' . $hex . '.txt';

  # say some blank lines to cause delay
  say $fpp 'READ.EXE "..................................."';
}
