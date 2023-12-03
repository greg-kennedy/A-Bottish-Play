#!/usr/bin/env perl
use v5.014;
use warnings;
use autodie;

use utf8;
use open qw/:std :utf8/;

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

push @script, { type => 'META', detail => "default", text => $title };
push @script, { type => 'META', detail => "default", text => "by $author" };

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

# Load the Voices file
#  This is a definition file for how to convert speaker names into ssml attributes
my $voices = XML::LibXML->load_xml(location => $ARGV[1]);
# do a quick check to ensure all voices are defined
my %linecounts;
foreach my $line (@script) {
  if ($line->{type} eq 'SPEECH') {
    foreach my $s (split / /, $line->{detail}) {
      $linecounts{$s} ++;
    }
  }
}
my $missing;
foreach my $speaker (sort { $linecounts{$b} <=> $linecounts{$a} } keys %linecounts)
{
  if (! $voices->findnodes('/voices/voice[@id="' . $speaker . '"]') ) {
    warn "No defined voice for $speaker ($linecounts{$speaker} lines)\n";
    $missing ++;
  }
}
if ($missing) { die "Missing $missing voices, cannot continue." }

#### TIME TO WRITE THE FINAL SSML
my $ssml = XML::LibXML->createDocument('1.0');

# root <speak> node, according to https://www.w3.org/TR/speech-synthesis11/
my $root = $ssml->createElementNS('http://www.w3.org/2001/10/synthesis', 'speak');
$root->setAttribute('version', '1.0');
$root->setNamespace('http://www.w3.org/2001/XMLSchema-instance', 'xsi', 0);
$root->setAttributeNS('http://www.w3.org/2001/XMLSchema-instance', 'schemaLocation', 'http://www.w3.org/2001/10/synthesis http://www.w3.org/TR/speech-synthesis11/synthesis.xsd');
$root->setAttributeNS('http://www.w3.org/XML/1998/namespace', 'lang', 'en');

sub makeSpeakingNode {
  my $root = shift;
  my $line = shift;

  if ($line->{type} eq 'META' ||
       $line->{type} eq 'SPEECH') {

      foreach my $speaker (split / /, $line->{detail}) {
        my $voice = $root->addNewChild(undef, 'voice');

        # set up the voice info
        my @voiceDetail = $voices->findnodes('/voices/voice[@id="' . $speaker . '"]');
        my $v = $voiceDetail[0];
        foreach my $node ($v->nonBlankChildNodes) {
          $voice->setAttribute($node->nodeName, $node->firstChild->textContent)
        }

        # speak a Paragraph
        my $p = $voice->addNewChild(undef, 'p');
        foreach my $sentence (split /(?<=[\.!\?—])\s*/, $line->{text}) {
          # each Sentence in Paragraph
          # do some UTF-8 fixup
          $sentence =~ s/—/ -/g;
          next if $sentence eq ' -';
          $sentence =~ s/’/'/g;
          $sentence =~ s/è/e/g;
          $sentence =~ s/ï/i/g;
          my $s = $p->addNewChild(undef, 's');
          $s->appendTextNode($sentence);
        }

        $root->addChild($voice);
      }
  } elsif ($line->{type} eq 'STAGE') {
    # Stage direction, read it with the Narrator (default)
    my $voice = $root->addNewChild(undef, 'voice');

    # set up the voice info
    my @voiceDetail = $voices->findnodes('/voices/voice[@id="default"]');
    my $v = $voiceDetail[0];
    foreach my $node ($v->nonBlankChildNodes) {
      $voice->setAttribute($node->nodeName, $node->firstChild->textContent)
    }

    # speak a Paragraph
    my $p = $voice->addNewChild(undef, 'p');
    foreach my $sentence (split /(?<=[\.!\?—])\s*/, $line->{detail}) {
      # each Sentence in Paragraph
      $sentence =~ s/—/ -/g;
      next if $sentence eq ' -';
      $sentence =~ s/’/'/g;
      $sentence =~ s/è/e/g;
      $sentence =~ s/ï/i/g;
      my $s = $p->addNewChild(undef, 's');
      $s->appendTextNode($sentence);
    }

    $root->addChild($voice);
  } elsif ($line->{type} eq 'SOUND') {
    # Microsoft SSML doesn't seem to support audio tags
    #my $audio = $root->addNewChild(undef, 'audio');
    #$audio->setAttribute('src', 'audio/' . $line->{detail} . '/' . $line->{ana} . '.wav');
    #$audio->appendTextNode($line->{ana});
    #$root->addChild($audio);
  } else {
    die "Unknown type " . $line->{type};
  }
}
# now we may declare all speakings and sounds
foreach my $line (@script) {
  makeSpeakingNode($root, $line);
}

# we are short on words
my $str = 'Thank you, thank you!  And now, for the encore: a special presentation of... Cats!';
my $v = '#Macbeth_Mac';
my @avail_voices = keys %linecounts;
for (0 .. 2750) {
  my $new_v = $avail_voices[rand(scalar @avail_voices)];
  if ($new_v ne $v) {
    makeSpeakingNode($root, { type => 'SPEECH', detail => $v, text => $str });
    $str = ''; $v = $new_v;
  }
  $str .= 'Meow. ';
}

$ssml->setDocumentElement($root);
print $ssml->toString(1);


