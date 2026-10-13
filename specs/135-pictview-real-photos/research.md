# Research: feature 135

## R1 - What does the command do to real camera files? (measured)

- **Sample**: the public collection `ianare/exif-samples` - 91 JPEG files: about twenty camera
  models and phones (Canon, Nikon, Olympus, Fujifilm, Kodak, Panasonic, Sony, Casio, Sanyo,
  Samsung, Konica Minolta, Apple, Nokia ...), orientation and GPS sets, deliberately invalid
  files. Downloaded outside the repository; not added to it.
- **Method**: `probe/exif_real_measure.py` calls `EXIFReplaceThumbnail` of the built EXIF.DLL
  and compares the Exif block before / after with its own TIFF walker (not the library): every
  entry of IFD0, the Exif, GPS and Interop IFDs by tag, type, count and value bytes; the
  MakerNote's bytes and its offset.
- **Result on the build of 132** (`probe/real_result_before.txt`): of 82 files with a readable
  Exif block **30 are different in more than the thumbnail**:
  - the MakerNote's bytes changed in 23 (all nine Nikon GPS samples 3,298 -> 3,294 bytes; Canon
    5,414 -> 5,406; Olympus 6,940 -> 144 and 10,368 -> 144; **a Nikon block of 28,378 bytes
    came back as 1,413**; Casio blocks of 31,814 and 32,408 bytes with the same size and other
    content; Sanyo, old Canon, old Nikon);
  - the MakerNote kept its bytes but moved in 3 (Fujifilm, two Kodak - one of them also lost
    two IFD0 tags: ImageDescription and Copyright);
  - an IFD appeared that the file did not have (2), or the block was not readable afterwards.
  The rule of 132 passed all of them: it compared everything but the Exif block's content.
- **Cause**: libexif parses the block into tags, has "MakerNote" readers for some makers that
  parse and re-serialise the maker's block, drops what it does not know and lays the data out
  anew. Nothing can be kept that way.

## R2 - Decision: no byte of the Exif block moves

- **Decision**: the library does not serialise the block. `SalExifReplaceThumbnail`
  (`src/common/salexifthumb.h`) swaps the thumbnail picture:
  - the old JPEG thumbnail is the end of the block (the usual layout): cut there, append the
    new picture, correct the length entry in IFD1 in place;
  - otherwise (no IFD1, an uncompressed thumbnail, a thumbnail followed by other data): the
    whole block is kept, a new IFD1 with the new picture is appended and IFD0's link is set to
    it; the old IFD1's entries that are not about the picture are carried over.
  A block that is not understood, or a result over 64 KB, is refused.
- **Alternatives**: repair libexif's MakerNote handling (per maker, never complete); switch the
  library's fix-up options (does not stop the re-layout); refuse every file with a MakerNote
  (most camera files - the command would be useless).
- **The check** (`SalExifRewriteKeepsData`, called from the rule of 132): every byte of the
  original block outside its IFD0 link, its IFD1 and its old thumbnail is at the same offset
  in the new block. Independent of who wrote the block: with the EXIF.DLL of 0.1.9 beside the
  new plug-in every file with Exif is refused.
- **A file without Exif never gets an Exif block** (it gets a JFXX block, as before) - the
  rule says so now.

## R3 - Result after the change (`probe/real_result.txt`)

82 of 82 files with Exif: every tag of every IFD the same, the MakerNote the same bytes at the
same offset; the new thumbnail is where IFD1 says. 9 files without a readable Exif block get a
JFXX block. Cross-check with Pillow (a reader that shares no code with either side): all 91
results decode to the same pixels as their originals, and in all 82 the IFD1 thumbnail decodes
as a 160 x 120 picture.
