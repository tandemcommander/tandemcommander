# Fix log: feature 132 - PictView's Update Thumbnail keeps the picture

Branch `132-pictview-thumbnail-verify` from `131-plugin-defect-batch`. Session 2026-10-13, asked
for by the maintainer ("do all four", point 1: the Exif writer and a damaged JPEG).

## 1. Measure first - and the premise was half wrong

| What | Result | Record |
|---|---|---|
| EXIF.DLL of 0.1.9 called directly on 13 shapes of JPEG file | **6 are written with a loss and reported as success**: XMP gone (3 shapes), a file with 8 fill bytes written as 1,036 bytes, an Exif block over 64 KB written with a wrapped length, the last two bytes of data behind the picture gone | `probe/exifdll_result_before_v019.txt` |
| The command in the program, 0.1.9 and the build of 131 | **never reaches the library**: "Unable to save the image. This operation is not supported by the built-in image engine." for every file; every file unchanged | `probe/thumb132_result_before_v019.txt` |

So the loss noted by 131 was real in the library and **unreachable in the program** - in every
release since feature 006 (it was in `specs/NEXT-WORK.md` as functional item 7, "Regenerate
thumbnail cannot work since 006"; the note of 131 and the recommendation built on it did not
check that). The accented-path fix of 131 in this command had no visible effect for the same
reason.

Decision (research R2): repair the command, with the protection as its condition.

## 2. What was done

- **The rule** `src/common/saljpegkeep.h`: `SalJpegRewriteKeepsFile` - the new file may differ
  from the original only in Exif APP1 / JFXX APP0 blocks before the first SOS; all bytes from the
  SOS marker to the end of the file are the same; a file that had Exif still has it; a file the
  walker does not understand is never "the same". `SalJpegHasExif`. 96 checks in `saltests`
  (`TestJpegKeep132`), among them every loss measured above.
- **The plug-in** `thumbs.cpp`: `ThumbNewFileKeepsOriginal` after the library's success and
  before the replace; a refusal removes the temporary file and shows the existing "Unable to
  create a file with the new thumbnail ... remains unmodified". `ThumbFileHasExif`: the question
  "this file does not contain EXIF data, create a JFXX thumbnail instead?" is asked only for a
  file without an Exif block (the engine never reports Exif, so every file was asked).
- **The library** `exif/libjpeg/jpeg-data.c`, `.h`: an APP1 that is not Exif stays generic bytes
  (`JPEGSection::exif`); a loader that left early marks the data incomplete and the writer
  refuses them; a block over 64 KB, an Exif block that cannot be serialised and low memory fail
  the save (no file is left); the end marker is recognised by both bytes.
- **The engine** `wicengine.cpp`: `WicSaveJpegThumbnail` - the second subset `WicSaveImage`
  accepts (a JPEG picture scaled to a given size into the caller's memory).

## 3. Traps met

- `jpeg-data.c` is ISO-8859-1 with CRLF (the author's name) - edited by a script on bytes.
- The first thought "refuse what the library spoils" would have made every file with XMP
  (most files from phones and from Lightroom) impossible to update - hence the library fix too;
  the plug-in's check stays as the independent second layer (probe mode `oldlib` shows it alone).
- The session started with the measurement and the code; `spec.md` / `plan.md` / `tasks.md`
  were written when the maintainer asked for the Spec Kit order (noted in the checklist).

## 4. Tests

| What | Result | Record |
|---|---|---|
| library measurement, new build | 0 losses; 2 shapes refused (8 fill bytes, Exif over 64 KB), no file left | `probe/exifdll_result.txt` |
| probe, new build (`fixed`) | PASS 16, FAIL 0: plain, Exif, accented folder (owed by 131), Exif+XMP, XMP only, data behind the picture: updated, marks kept; 8 fill bytes, big Exif: unchanged + message | `probe/thumb132_result.txt` |
| the kept files | every updated file decodes to the same pixels and holds a 160 x 120 thumbnail | `probe/check_outputs_result.txt` |
| probe, new plug-in + EXIF.DLL of 0.1.9 (`oldlib`) | PASS 16, FAIL 0: what the old library spoils (XMP, XMP only, trailer, fill bytes, big Exif) is **unchanged + message** - the plug-in's check alone | `probe/thumb132_result_oldlib.txt` |
| probe, 0.1.9 (`before`) | every file unchanged, "not supported by the built-in image engine" | `probe/thumb132_result_before_v019.txt` |
| saltests | 18,567 checks, 0 failed (96 for this feature) | |
| product registry key | identical before and after every run | |

## 5. Independent review (read-only, refute-first; own ASan harness of the library and the rule, about 24,000 mutated files)

- **A real hole - fixed.** A file whose Exif block stands behind a block the library's streaming
  loader does not know (APP12 "Ducky", APP14 "Adobe"): the loader found "no Exif", a JFXX block
  was added, and the Exif block - parsed and serialised again on the way - came back with its
  private tags dropped and six default tags added. The rule said "same" (it does not compare
  Exif content) and, new in 132, the question about JFXX was not even asked. The same for a
  second Exif block. Fixes, in three places:
  - the library parses no APP1 while loading; every block is kept as raw bytes and only
    `jpeg_data_set_exif_data` replaces the first Exif block (`jpeg_data_get_exif_bytes`);
  - `exif.c` takes the Exif data from that same block instead of the streaming loader (so the
    library, the question and the rule agree which block it is); a block of which nothing can be
    read is not replaced by an empty one - the file is refused;
  - the rule: one thing changes - one Exif block or the JFXX blocks, never both, never two Exif
    blocks (`sjkCarriersDiffer`; more than four blocks of a kind = not understood).
- **Wild read in libexif** (`exif-data.c`, IFD 0 offset near 4 GB wraps the bounds check) -
  old, but reached by the repaired command for every selected file: guarded.
- Small: a file the library cannot open or read is "incomplete" (it could write `FF 00 00 02`
  and call it success - only the plug-in's check stopped it); a failed section append no longer
  reuses the previous section; file sizes that do not fit 31 bits are refused in the library;
  the plug-in reads the two files with full sharing (another program holding the picture open
  for writing made the check fail with a misleading message).
- Found sound: bounds of the walker (ASan, 13,000 comparisons), the first SOS (walked by
  lengths, `FF DA` inside a thumbnail cannot be taken for it), fill bytes, MPF offsets, the
  fail paths of the writer, the `exif` flag across `memmove`, COM reference counts and the
  cancel path of the new encoder, that the new branch of `WicSaveImage` cannot capture the
  panel thumbnails or printing (`PVF_RAW`).
- Not checked by the review: MakerNote integrity after libexif serialises the Exif block of
  vendors with TIFF-relative offsets (Sony, Panasonic) - the rule cannot see it; real camera
  files (only synthetic ones were used).

## 6. Final runs (after the review fixes)

| What | Result |
|---|---|
| `build.cmd full` (Debug), `build.cmd full release` | clean |
| saltests | 18,567 checks, 0 failed |
| `tools/check_encoding.py` | `TOTAL: 0` |
| library measurement | 0 losses reported as success |
| the reviewer's 18 crafted files through the new EXIF.DLL | "Ducky" / APP14 / two Exif blocks: the Exif block is updated, no JFXX block added; the crash file and the unreadable Exif block are refused, no file left |
| probe `fixed` / `oldlib` / `before` | 16 / 0 each (see section 4) |
| the kept files | bad files: 0 |
| regressions (run before the review fixes, which touch only the Exif library, the rule and the sharing mode of two reads): 105 Save As 56 / 0 (4 not driven), 111 85 / 0 (2 not driven), 120 20 / 0 (2 not driven), 130 Czech 19 / 0 | |

## 7. Left

- **Owed to a person before a release**: Update Thumbnail on real camera files (Canon, Nikon,
  Sony, Panasonic, a phone). The Exif block is serialised again by the old libexif; a MakerNote
  with offsets relative to the file may not survive that, and the rule does not compare Exif
  content. Only synthetic files were used here. The command rewrites users' files again after
  being dead since 006 - this is the one risk the session could not measure.
- The viewer's Exif dialog and Exif auto-rotation are dead for the reason the command was (the
  engine never reports `PVFF_EXIF`) - a feature of its own.
- A refused file is reported with "Unable to create a file with the new thumbnail. Disk full?"
  (a sentence of its own needs a new string); the message has no "skip all".
