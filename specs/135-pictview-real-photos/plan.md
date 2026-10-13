# Implementation Plan: Update Thumbnail on real camera files

**Branch**: `135-pictview-real-photos` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

1. **Measure** (`probe/exif_real_measure.py`): for every JPEG of the sample set call
   `EXIFReplaceThumbnail` of the built `exif.dll` (as `probe/exifdll_measure.py` of 132 does)
   and compare the Exif block before / after with a TIFF walker of the probe's own: every IFD
   entry (tag, type, count, value bytes) of IFD0, Exif, GPS, Interop; the MakerNote's bytes and
   its offset from the TIFF header; IFD1 apart (the thumbnail and its tags are meant to
   change). Outcome per file: `same`, `refused`, or what differs.
2. **Decide by the result** (research R2): where the library moves or alters something, either
   make the library keep it (write the Exif block back with the thumbnail replaced in place),
   or have the rule refuse. The rule (`src/common/saljpegkeep.h`) gets an Exif comparison in
   any case - FR-004: the plug-in must not depend on the library being right.
3. Unit checks for the rule's new part (`saltests`), the probes of 132 again, records.

## Technical Context

- `src/plugins/pictview/exif/` (`exif.c`, vendored libexif 0.6.x with Altap's changes),
  `src/plugins/pictview/thumbs.cpp`, `src/common/saljpegkeep.h`, `src/saltests/saltests.cpp`.
- Sample files: downloaded to a scratch folder outside the repository, each run with Python's
  isolated mode on the reading side; never opened in the program by a person.
- No new strings; `PRIVACY.md` untouched.

## Constitution Check

- Never lose the user's data: the purpose; the rule fails closed.
- Backward compatibility, plug-in ABI: untouched. Build reproducibility: no new dependency in
  the build (Pillow is a probe-only tool, as in 132).

## Structure

1. Spec, plan, research, tasks. 2. Sample set + measurement on the build of 132.
3. Fix by the result; rule + unit checks. 4. Measurement again; probes of 132; review; records.
