# The Robot Community Theater Presents: "Macbeth"
A NaNoGenMo 2023 Project

# [Listen to the Performance](https://youtu.be/4Rm85rMs6Tw)
## [Listen to the Encore](https://www.youtube.com/watch?v=xMIxA5kMLI8)
# [Read the GitHub Issue](https://github.com/NaNoGenMo/2023/issues/27)

This is the repository for code and audio to build The Bottish Play, an all-TTS rendition of Shakespeare's Macbeth.  Details about the construction of the play, the speech synthesizers used (casting process), and recordings are in the GitHub Issue linked above.  Most of the information about this project is located there.

The repository (here) contains these files:
* `tei2ssml.pl`: A Perl script to turn a TEI XML file into an SSML file, using content from an associated voices definition.
* `tei_to_sox_cmd.pl`: A Perl script to turn a TEI XML file into a large shell script that concatenates pre-recorded lines into a complete output.
* `audio/` folder: Recordings of each TTS line
  * `audio/*.pl`: Helper Perl scripts for capturing TTS outputs - some retrieve from a website, some call `sam`, some build a script to execute on another machine, etc
  * `audio/*/*.flac`: The recordings themselves - in most cases, named as `md5(line)`.
  * `audio/sound/*`: Sound effect clips as needed, by name
  * `audio/stage/*`: Stage directions
  * `audio/stage/words/*`: Individual word recordings concatenated to build the stage direction phrases
* `hell-meow.pl`: Mixes all `meow.wav` samples together to create one giant meow cacaphony - for the encore
* `processing/` folder: Processing scripts for creating the video components
* `output_*.txt`: Credits, and complete script (for word counts)


You will need `sox`, probably `ffmpeg` (unless your `sox` can handle .mp3 files - mine cannot), also [wavegain](https://github.com/MestreLion/wavegain) to match volumes of disparate samples.

Releases contains a rendered .flac of the performance.  Note that the Youtube version differs, as some pronunciation quirks were not fixed there, and a couple additional sound cues added manually.
