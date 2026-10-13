# Fix log: feature 135 - Update Thumbnail on real camera files

Branch `135-pictview-real-photos` from `134-ftp-mixed-templates`. Session 2026-10-13, asked for
by the maintainer ("fix what you can"; the first critical point: PictView on real photos before
the 0.1.10 tag). Spec Kit order: `spec.md`, `plan.md`, `tasks.md` before the measurement.

**This feature must be in 0.1.10 together with 132** - without it Update Thumbnail damages the
Exif data of about a third of real camera files (section 1).

## 1. Measured first (`research.md` R1, `probe/real_result_before.txt`)

91 real JPEG files of a public collection (`ianare/exif-samples`; not added to the repository)
through the EXIF.DLL built from feature 132, the Exif block compared before / after by the
probe's own TIFF walker:

- **30 of the 82 files with Exif differ in more than the thumbnail.** The maker's block
  (MakerNote) changed in 23 - Nikon 28,378 bytes -> 1,413, Olympus 6,940 -> 144 and 10,368 ->
  144, Canon, Casio, Sanyo, all nine Nikon GPS samples; it moved in 3 (Fujifilm, Kodak - one
  of them also lost ImageDescription and Copyright); an IFD appeared in 2.
- The rule of 132 passed every one of them (it compared everything but the Exif block's
  content - recorded there as "by design"; the review of 132 had named MakerNote integrity as
  not checked).

## 2. The change

- `src/common/salexifthumb.h` (plain C + C++): `SalExifReplaceThumbnail` swaps the thumbnail
  picture and **moves no other byte** of the block (cut and append when the old JPEG picture is
  the end of the block; else a new IFD1 appended and IFD0's link set to it - the old picture's
  bytes are zeroed). `SalExifRewriteKeepsData`: the independent check.
- `exif.c` `EXIFReplaceThumbnail`: uses it; libexif's serialiser is no longer reached by this
  command. `jpeg-data.c`: `jpeg_data_set_exif_bytes`.
- `saljpegkeep.h`: a changed Exif block must pass the check (`sjkExifDataDiffer`); an Exif
  block is never added.

## 3. Independent review (own ASan fuzz harness: 2.8 million writer calls, no memory error; it
could not make the writer damage a real camera file)

Fixed after it:

- **The old thumbnail stayed readable in the file** for about a third of the photos (every
  case that took the "append" way: one or two padding bytes behind the picture, data behind
  it, no Compression tag). People update a thumbnail after cropping or retouching - the old
  picture must not be recoverable. Its bytes are zeroed now, and a JPEG picture at the end
  without a Compression tag takes the cut-and-append way.
- A wrong length in IFD1 (running over the Exif IFD) made the cut remove real data, and the
  check accepted it; a link of IFD0 into the Exif IFD, or a thumbnail range laid over the
  maker's block, made the check take real data for "thumbnail bytes". A block is understood
  only when IFD1 and the thumbnail lie apart from everything IFD0 leads to
  (`SalExifIfdMeets`); only a range that starts with a JPEG marker is cut.
- An IFD1 entry given twice (readers disagree which counts): not understood.
- Bounds written so that they cannot wrap where `size_t` has 32 bits.
- The JFXX branch wrote an empty block for a thumbnail of size 0: refused.

## 4. Result

| What | Result | Record |
|---|---|---|
| real files, build of 132 | 30 of 82 DIFFERENT | `probe/real_result_before.txt` |
| real files, this build | **82 of 82 the same** (every tag, the MakerNote's bytes and offset); 9 without Exif get a JFXX block; 0 refused | `probe/real_result.txt` |
| cross-check with Pillow (no code shared with either side) | all 91 results decode to the pixels of their originals; in all 82 the IFD1 thumbnail decodes as 160 x 120 | |
| the old picture | of 55 files with a JPEG thumbnail none keeps it inside the Exif block (39 cut in place, 16 zeroed); two files hold a second copy in another block (Photoshop's own) - that block is not this command's | |
| the reviewer's reader (WIC): Make, Model, date, MakerNote hash, GPS | identical for all 91 | |
| saltests | 18,710 checks, 0 failed (143 for this feature) | |
| probe of 132 in the program: `fixed` / `oldlib` | 16 / 0; 16 / 0 (with the EXIF.DLL of 0.1.9 a plain file is refused too: that library gives it an Exif block it did not have) | `specs/132-.../probe/` |
| library measurement of 132 | 0 losses | |
| `build.cmd full`, `build.cmd full release`, `tools/check_encoding.py` | clean, `TOTAL: 0` | |

## 5. Left

- Maker-specific decoding of a MakerNote after the update was not run through `exiftool` (not
  installed); the bytes and the offset are identical, which is what such decoding depends on.
- A thumbnail larger than the main picture (a 100-pixel photo) is not shown by Windows.
- A second copy of the thumbnail in Photoshop's own block (APP13) is not updated.
- Owed to a person, now a formality: Update Thumbnail on a few own photos in the program.
