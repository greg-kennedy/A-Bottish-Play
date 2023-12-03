#!/usr/bin/env perl
use v5.014;
use warnings;

use autodie;

use Digest::MD5 qw(md5_hex);

# Makes a request to CereProc demo page and stores the result
#  only make the call if a file does not exist yet

open my $fp, '<', $ARGV[0];
foreach my $line (<$fp>) {
  chomp $line;

  my $hex = md5_hex($line);

  $line =~ s/i' /in /ig;
  $line =~ s/ 't([ .,?])/ it$1/ig;

  open my $fp, '>', $hex . '.txt';
  print $fp "<text>$line</text>";
  close $fp;

  if (! -e $hex . '.wav') {
    $line =~ s/'/\\'/g;
    my $response = `curl 'https://api.cerevoice.com/v2/demo?voice=Heather-CereWave&audio_format=wav'   -H 'authority: api.cerevoice.com'   -H 'accept: */*'   -H 'accept-language: en-US,en;q=0.9'   -H 'content-type: text/plain;charset=UTF-8'   -H 'origin: https://www.cereproc.com'   -H 'referer: https://www.cereproc.com/'   -H 'sec-ch-ua: "Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-fetch-dest: empty'   -H 'sec-fetch-mode: cors'   -H 'sec-fetch-site: cross-site'   -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'   --data \@$hex.txt   --compressed > $hex.wav`;

    print "$hex: $response\n";

    sleep(20);
  }
}
