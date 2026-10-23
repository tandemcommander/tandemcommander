# Closing report - 330-iso-unreadable-folder
Backlog item: iso-plug-in-unpack-deletes-image-with-unreadable-folder - ISO plug-in: Unpack with Delete archive deletes an image whose folder could not be read
Outcome: closed

## What changed

A listing of the ISO plug-in (`uniso`) that met a folder it could not read is now marked incomplete
(feature 328's `CISOImage::ListingLeftOut`), so a whole-image Unpack fails and "Delete archive after
unpacking" keeps the image. Before, the files of the unreadable folder and of every later folder (the
walk descends no later folder after an error) were lost with the deleted image.

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectory`, `src/plugins/uniso/xdvdfs.cpp`
  `CXDVDFS::ListDirectory`, `src/plugins/uniso/udf.cpp` `CUDF::ListDirectory`: a walk result other
  than `ERR_OK` marks the listing (read errors, record checks, empty extents, invalid UDF tags,
  unreadable UDF file entries, out of memory; return values unchanged).
- `udf.cpp`: also the early returns (File Set Descriptor not read / not found, root ICB not mapped or
  not a directory) and, in `ScanDir`, a folder whose file entry `MapICB` cannot read (it was listed
  empty without a word).
- `src/plugins/uniso/udfiso.h/.cpp`, `isoimage.cpp`: `CUDFISO` learns the parts the track type
  declares; a declared ISO 9660 part, or a UDF part with an anchor at sector 256, that does not open
  marks the listing.
- Messages unchanged; no UI string, resource or dialog changed (no `.slt` refresh, no manual change).

## Measurements (before / after, commands)

- Before, main at ae41208d: review 4 of 328's `rd_probe.ps1` row RDERR-UNP-DEL - the box, 1 of 3
  files, the image deleted.
- New probe `probe/iso330_probe.ps1` through `tools\run_on_hidden_desktop.ps1` (seeds `mkimg330.sh`
  in WSL genisoimage, damaged copies and Xbox images `img330.py`): on main's build
  `probe/result_before_final.txt` **20 / 10** (all ten damaged rows FAIL - image deleted; the five
  controls PASS); after `probe/result_after.txt` **30 / 0** (15 RUN rows: RD-EXT, RD-REC, RD-ZERO,
  RD-ROOT, UD-EXT, UD-ICB, UD-TAG, UDH-ROOT, UDH-AVDP, XD-EXT keep the image; RD/UD/UDH/XD/NEST-OK
  deleted as before).
- Negative controls: `result_before.txt` (first version, 10 / 4), `result_before_review1.txt`
  (16 / 8), `result_before_review2.txt`, `result_before_review3.txt` (NEST-OK FAIL at 7caf4ae7).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (C4267 warnings only on existing lines).
- saltests -> 28266 checks, 0 failed (no change in `src/common/`).
- Probes: `iso330_probe` 30 / 0; regressions `iso322_probe` 18 / 0, `iso327_probe` 77 / 0,
  `iso328_probe` 20 / 0, `iso329_probe` 14 / 0 (`probe/regress_*.txt`). Registry restored identical
  in every run (SHA-256 4F221E76...51E7).

## Reviews (findings and what was done)

- Review 1 stopped with the session (no report); its interrupted probe left `%TEMP%\tc330_backup.reg`
  - restored and verified first. Its partial results: three UDF cases (unmapped folder entry, invalid
  tag, root ICB not found) still deleted the image - fixed (walk-result rule for UDF / Xbox, early
  returns, unmapped folder), probe rows added.
- Review 2: MUST - a UDF part that does not open (anchor's descriptor sequence past the end) was
  dropped silently and the image deleted - fixed (`CUDFISO` declared parts). SHOULD multi-session
  tracks and NOTE HFS+ part -> Inbox. NOTE "no message in silent cases" accepted (spec FR-004).
- Review 3: no MUST; SHOULD - a valid ISO holding a UDF image was detected as a hybrid and its whole
  unpack always failed - fixed (a UDF part counts only with an anchor at sector 256), row NEST-OK with
  a negative control.

## Owed to a person (with the new person-step items)

Nothing - every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-after-a-folder-that-cannot-be-read-no-later` - ISO plug-in: after a folder that
  cannot be read, no later folder of the image is listed
- `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` - ISO plug-in: Unpack with Delete archive
  deletes a multi-session image whose session track cannot be opened
- `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is` - ISO plug-in: an HFS+ part of a hybrid
  that does not open is dropped without a mark
