#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Build a PowerShell script for Windows, to record lines to .wav files automatically

#my $name = "Angus";
#my $voice = "Microsoft David Desktop";

#my $name = "Caithness";
#my $voice = "Microsoft Mark";

#my $name = "Lennox";
#my $voice = "Microsoft Sean";

#my $name = "Lord";
#my $voice = "Microsoft Ravi";

#my $name = "Menteith";
#my $voice = "Microsoft James";

my $name = "Ross";
my $voice = "Microsoft George";

open my $fp, '<', $ARGV[0];
open my $fpp, '>:crlf', "$name.ps1";

say $fpp 'Add-Type -AssemblyName System.Speech';
say $fpp '$Speech = New-Object System.Speech.Synthesis.SpeechSynthesizer';
say $fpp '$Speech.SelectVoice("' . $voice . '")';

foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  # pronunciation corrections
  $line =~ s/th' /the /ig;
  $line =~ s/i' /in /ig;
  $line =~ s/ 't / it /ig;
  $line =~ s/ 't\./ it./ig;

  open my $fps, '>:raw', $hex . ".txt";
  print $fps "$line";
  close $fps;

  say $fpp '$Text = Get-Content -Path "' . $hex . '.txt" -Raw';
  say $fpp '$Speech.SetOutputToWaveFile("' . $hex . '.wav")';
  say $fpp '$Speech.Speak($Text)';
}

# couple extras
say $fpp '$Speech.SetOutputToWaveFile("meow.wav")';
say $fpp '$Speech.Speak("Meow.")';
say $fpp '$Speech.SetOutputToWaveFile("credit.wav")';
say $fpp '$Speech.Speak("The character of ' . $name . ' was played by ' . $voice . ' on Windows 10.")';

