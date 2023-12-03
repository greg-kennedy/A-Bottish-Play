#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use HTTP::Tiny;
use URI::Escape qw(uri_escape);
use Digest::MD5 qw(md5_hex);

# Make a request to the aeiou DECTalk online service

my $http = HTTP::Tiny->new(
  agent => '[Macbeth TTS Project - https://github.com/NaNoGenMo/2023/issues/27 - kennedy.greg@gmail.com]'
);

# Macbeth - default [:np] perfect paul
my $voice = '';
# Lady Macbeth
#my $voice = '[:nb]';

open my $fp, '<', $ARGV[0];
foreach my $line (<$fp>) {
  chomp $line;

  my $file = md5_hex($line) . ".wav";

  if (! -e $file) {

    # dectalk will say the "dash" lol
    $line =~ s/ -//g;
    # other corrections
    $line =~ s/th' /the /ig;
    $line =~ s/i' /in /ig;
    $line =~ s/ 't([ .,?])/ it$1/ig;
    $line =~ s/ 'rt/ art/ig;
    $line =~ s/ 'lt/ wilt/ig;
    $line =~ s/ 's / his /ig;
    $line =~ s/ 'dst/ wouldst/ig;
    $line =~ s/ a-/ a/ig;

    my $url = 'https://tts.cyzon.us/tts?text=' . uri_escape($voice . $line);
    print $line . "\n";

    my $response = $http->mirror($url, $file);
    if ( $response->{success} ) {
      print "$file is up to date\n";
    }

    sleep(30);
  }
}
