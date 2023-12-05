#!/usr/bin/env perl
use v5.014;
use warnings;
use autodie;

use utf8;
use open qw/:std :utf8/;

use Digest::MD5 qw(md5_hex);

use XML::LibXML;
use XML::LibXML::XPathContext;

my @script;

# Load the TEI file
my $tei = XML::LibXML->load_xml(location => $ARGV[0]);

# TEI files use a namespace, so we need to set up an XPath Context
#  if we want to do XPath walking
# To be "most correct", we should hardcode the tei-c.org url here,
#  but for flexibility we will just use the one off the doc
#  and not support "merged" XML which may have conflicts
my $xpc = XML::LibXML::XPathContext->new($tei);
$xpc->registerNs('tei', $tei->documentElement->namespaceURI);

# Get the title and author
my $title = $xpc->findvalue('/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title');
my $author = $xpc->findvalue('/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author');

# Parse lines, stage directions, and sounds
#  These are stored in the "text/body" part, where div1 is the Act and div2 is scene
# In theory, this would work with any TEI file, but practically the organization of each work
#  is going to be organized / typeset / attribute'd very specifically - so we're lucky
#  if it even works for more than one Shakespeare play...

sub parse_block {
  # parses a block - this would be e.g. an "ab" or similar
  #  these share common features like "w', "c", and also do recursive "q" or "title"
  my $p = shift;

  my $str = '';

  foreach my $node ($p->nonBlankChildNodes) {
    if ($node->nodeName eq 'w' || $node->nodeName eq 'c' || $node->nodeName eq 'pc') {
      # Word, character, or punctuation.
      if (defined $node->firstChild) {
        $str .= $node->firstChild->textContent;
      }
    } elsif ($node->nodeName eq 'lb' || $node->nodeName eq 'pb') {
      # A line break.  Try to avoid adding spaces for no reason
      if ($str ne '' && substr($str, -1) ne ' ') {
        $str .= ' '
      }
    } elsif ($node->nodeName eq 'name') {
      # referring to another person - just extract it and put it here
      $str .= parse_block($node);
    } elsif ($node->nodeName eq 'title' || $node->nodeName eq 'q' || $node->nodeName eq 'seg') {
      # the title of a song, or a quote, etc
      $str .= '"' . parse_block($node) . '"';
    } elsif ($node->nodeName eq 'milestone') {
      # this indicates a verse number, or grouping.
      #  a more advanced parser might try to use these to identify verses,
      #  pronunciation, grouping.  we don't bother
    } elsif ($node->nodeName eq 'fw') {
      # act / scene header as shown on the page
    } else {
      print STDERR "BLOCK: don't know node " . $node->nodeName . ", content " . $node->textContent . "\n"
    }
  }

  return $str;
}

sub parse_stage {
  # Parses a stage direction
  #  This may lead to other stage dirs, in which case, we concatenate them.
  my $p = shift;

  my @sound = ();
  my $str = '';

  foreach my $node ($p->nonBlankChildNodes) {
    if ($node->nodeName eq 'stage') {
      # an inner stage direction.
      my ($subsound, $substr) = parse_stage($node);
      push @sound, @$subsound;
      $str .= $substr;
    } elsif ($node->nodeName eq 'sound') {
      # a sound.  add details of it to the sounds list
      #  this could also be music, in which case, the title is in the sub-parts
      if ($node->getAttribute('type') eq 'music') {
        my $ana = parse_block($node);
        push @sound, [ $node->getAttribute('type'), $ana ];
        $str .= $ana;
      } else {
        push @sound, [ $node->getAttribute('type'), $node->getAttribute('ana') ];

        # there are further stage directions within sounds, sometimes
        my ($subsound, $substr) = parse_stage($node);
        push @sound, @$subsound;
        $str .= $substr;
      }
    } elsif ($node->nodeName eq 'w' || $node->nodeName eq 'c' || $node->nodeName eq 'pc') {
      # Word, character, or punctuation.
      if (defined $node->firstChild) {
        $str .= $node->firstChild->textContent;
      }
    } elsif ($node->nodeName eq 'lb' || $node->nodeName eq 'pb') {
      # A line break.  Try to avoid adding spaces for no reason
      if ($str ne '' && substr($str, -1) ne ' ') {
        $str .= ' '
      }
    } elsif ($node->nodeName eq 'title' || $node->nodeName eq 'q') {
      # the title of a song, or a quote, etc
      $str .= '"' . parse_block($node) . '"';
    } elsif ($node->nodeName eq 'app') {
      # "critical apparatus", generally indicates a variant from previous publication
    } else {
      print STDERR "STAGE: don't know node " . $node->nodeName . ", content " . $node->textContent . "\n"
    }
  }

  # at the end, return the sounds list, and the stage dir we extracted
  return (\@sound, $str);
}

sub parse_speech {
  # Parses a character speech
  #  This may lead to stage dirs, more speeches, etc
  my $p = shift;

  my @script = ();
  my $speaker = $p->getAttribute('who');
  foreach my $node ($p->nonBlankChildNodes) {
    if ($node->nodeName eq 'speaker') {
      # this contains what the text says the speaker is
      #  however, we already have a better representation w/ "who" above
    } elsif ($node->nodeName eq 'ab') {
      # The speech block.
      #  Collect this and put it into the script part.
      my $str = '';
      foreach my $subnode ($node->nonBlankChildNodes) {
        # Word, character, or punctuation.
        if ($subnode->nodeName eq 'stage') {
          # A stage direction intersperses.
          #  Go handle that and then come back.
          push @script, { type => 'SPEECH', detail => $speaker, text => $str };
          $str = '';

          my ($subsound, $substage) = parse_stage($subnode);
          # rearrange all sounds to play first
          push @script, map { { type => 'SOUND', detail => $_->[0], ana => $_->[1] } } @$subsound;
          push @script, { type => 'STAGE', detail => $substage };
 
        } elsif ($subnode->nodeName eq 'w' || $subnode->nodeName eq 'c' || $subnode->nodeName eq 'pc') {
          if (defined $subnode->firstChild) {
            $str .= $subnode->firstChild->textContent;
          }
        } elsif ($subnode->nodeName eq 'lb' || $subnode->nodeName eq 'pb') {
          # A line or page break.  Try to avoid adding spaces for no reason
          if ($str ne '' && substr($str, -1) ne ' ') {
            $str .= ' '
          }
        } elsif ($subnode->nodeName eq 'name') {
          # referring to another person
          $str .= parse_block($subnode);
        } elsif ($subnode->nodeName eq 'title' || $subnode->nodeName eq 'q' || $subnode->nodeName eq 'seg') {
          # the title of a song, or a quote, etc
          $str .= '"' . parse_block($subnode) . '"';
        } elsif ($subnode->nodeName eq 'milestone') {
          # this indicates a verse number, or grouping.
          #  a more advanced parser might try to use these to identify verses,
          #  pronunciation, grouping.  we don't bother
        } elsif ($subnode->nodeName eq 'fw') {
          # act / scene header as shown on the page
        } elsif ($subnode->nodeName eq 'app') {
          # "critical apparatus", generally indicates a variant from previous publication
        } else {
          print STDERR "AB: don't know node " . $subnode->nodeName . "\n"
        }
      }

      push @script, { type => 'SPEECH', detail => $speaker, text => $str };
    } elsif ($node->nodeName eq 'stage') {
      # A stage direction intersperses.
      #  Go handle that and then come back.
      my ($subsound, $substage) = parse_stage($node);
      # rearrange all sounds to play first
      push @script, map { { type => 'SOUND', detail => $_->[0], ana => $_->[1] } } @$subsound;
      push @script, { type => 'STAGE', detail => $substage };
    } else {
      print STDERR "SPEECH: don't know node " . $node->nodeName . "\n"
    }
  }

  # at the end, return the sounds list, and the stage dir we extracted
  return \@script;
}

push @script, { type => 'META', detail => "default", text => "The Robot Community Theater presents" };

push @script, { type => 'META', detail => "default", text => $title };
push @script, { type => 'META', detail => "default", text => "by $author" };

push @script, { type => 'META', detail => "default", text => "Directed by Greg Kennedy" };
push @script, { type => 'META', detail => "default", text => "For NaNoGenMo Twenty Twenty Three" };

foreach my $scene ($xpc->findnodes("/tei:TEI/tei:text/tei:body/tei:div1[\@type='act']/tei:div2[\@type='scene']")) {

  push @script, { type => 'META', detail => "default", text => 'Act ' . $scene->parentNode->getAttribute("n") };
  push @script, { type => 'META', detail => "default", text => 'Scene ' . $scene->getAttribute("n") };

  # locate all stage directions and spoken parts
  foreach my $node ($scene->nonBlankChildNodes) {
    if ($node->nodeName eq 'sp') {
      my ($subscript) = parse_speech($node);
      push @script, @$subscript;
    } elsif ($node->nodeName eq 'stage') {
      my ($subsound, $substage) = parse_stage($node);
      # rearrange all sounds to play first
      push @script, map { { type => 'SOUND', detail => $_->[0], ana => $_->[1] } } @$subsound;
      push @script, { type => 'STAGE', detail => $substage };
    } elsif ($node->nodeName eq 'milestone') {
      # this indicates a verse number, or grouping. ignore here
    } elsif ($node->nodeName eq 'head' || $node->nodeName eq 'fw') {
      # act or scene header, ignored
    } elsif ($node->nodeName eq 'lb' || $node->nodeName eq 'pb') {
      # a page, or line break in the original text.  we can ignore these.
    } else {
      print STDERR "GLOBAL: don't know node " . $node->nodeName . "\n"
    }
  }
}

push @script, { type => 'META', detail => "default", text => "This concludes the Robot Community Theater production of Macbeth." };

foreach my $char (
  'WITCHES.1',
  'WITCHES.2',
  'WITCHES.3',

  'Duncan',
  'Malcolm',
  'Donalbain',

  'Macbeth',
  'LadyMacbeth',
  'Seyton',
  'MURDERERS.1',
  'Doctor2',
  'Gentlewoman',
  'Porter',

  'Banquo',
  'Fleance',

  'Macduff',
  'LadyMacduff',
  'MacduffsSon',

  'Lennox',
  'Ross',
  'Angus',
  'Menteith',
  'Caithness',

  'Siward',
  'YoungSiward',

  'SOLDIERS.Captain',
  'OldMan',

  'Hecate',
  'SPIRITS.1',

  'MESSENGERS.1',
  'SERVANTS.X.2',
  'Lord'
) {
  push @script, { type => 'CREDIT', detail => $char };
}

push @script, { type => 'META', detail => "default", text => "Thank you for listening." };

# Emit bigass sox command
#  first preprocess every file by doing samplerate / bitrate conv
say "ulimit -n 2048";
say "mkdir -p /tmp/mac";

my $line_count = 0;
# music cues are numbered
my $mus_count = 0;
foreach my $line (@script) {
  my $fname;
  my $txt;
  my $should_hex = 0;
  if ($line->{type} eq 'META') {
    $fname = 'stage';
    $txt = $line->{text};
    $should_hex = 1;
    if ($txt =~ m/Act / || $txt =~ m/Scene /) {
      say "# ===========================================================================";
      say "# $txt";
      say "# ===========================================================================";
    }
  } elsif ($line->{type} eq 'STAGE') {
    $fname = 'stage';

    $txt = $line->{detail};
    $should_hex = 1;
  } elsif ($line->{type} eq 'SPEECH') {
    $fname = $line->{detail};
    $fname =~ s/#//g;
    $fname =~ s/ /+/g;
    $fname =~ s/_Mac//g;

    $txt = $line->{text};
    $should_hex = 1;
  } elsif ($line->{type} eq 'CREDIT') {
    $fname = $line->{detail};
    $txt = 'credit';
  } elsif ($line->{type} eq 'SOUND') {
    $fname = "sound";
    if ($line->{detail} eq "music") { $line->{ana} = $mus_count; $mus_count ++ }
    $txt = $line->{detail} . "/" . $line->{ana};
  } else {
    warn "Skipping unknown type $line->{type}";
    next;
  }

  my $src_file;
  if ($should_hex) {
    $txt =~ s/—/ - /g;
    $txt =~ s/’/'/g;
    $txt =~ s/è/e/g;
    $txt =~ s/ï/i/g;
    $txt =~ s/^\s+//g;
    $txt =~ s/\s+$//g;
    $txt =~ s/\s+/ /g;
    next unless $txt;

    my $hex = md5_hex($txt);
    $src_file = "audio/$fname/$hex";
  } else {
    $src_file = "audio/$fname/$txt";
  }

  my $dest_file = sprintf("/tmp/mac/%05d.wav", $line_count);
  if (-e "$src_file.flac") {
    say "sox --norm $src_file.flac -r 44100 -b16 $dest_file";
    $line_count ++;
  } elsif (-e "$src_file.wav") {
    say "sox --norm $src_file.wav -r 44100 -b16 $dest_file";
    $line_count ++;
  } elsif ( -e "$src_file.mp3") { 
    say "ffmpeg -i $src_file.mp3 /tmp/crap.wav";
    say "sox --norm /tmp/crap.wav -r 44100 -b16 $dest_file";
    say "rm /tmp/crap.wav";
    $line_count ++;
  } else {
    warn "Missing $src_file.wav, the line is supposed to be:\n$txt\n";
  }

  if ($line->{type} eq 'STAGE') {
    say "./wavegain -y -g -6 $dest_file";
  } else {
    say "./wavegain -y $dest_file";
  }
}
say "sox /tmp/mac/*.wav out.flac";
say "rm -rf /tmp/mac/";
