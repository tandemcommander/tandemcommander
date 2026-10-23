# Closing report - 329-uniso-other-readers-refused
Backlog item: iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses - ISO plug-in: UDF, Xbox and HFS+ entries the listing refuses end their folder with Error
Outcome: closed

## What changed

The ISO plug-in's UDF, Xbox (XDVDFS), HFS+ and audio-track readers now treat an entry the panel
listing refuses as feature 328's ISO 9660 reader does: they ask the listing's rule first
(`sallistingname.h`, the core's own), leave the entry out alone (a folder with its contents), record
it in `CISOImage::ListingLeftOut` - one "(206)" report per listing names it with its whole in-image
path, and a whole-image unpack fails, so "Delete archive after unpacking" keeps the image - and go on
with the rest of the folder and every later folder.

- `src/plugins/uniso/udf.cpp/.h`, `xdvdfs.cpp/.h`: `AddFileDir` returns listed / left out / failed;
  `ScanDir` descends only a listed folder; the refused name is no longer allocated (it leaked).
- `src/plugins/uniso/hfs.cpp`: a refused folder or file is recorded and the walk continues; records
  inside a left-out folder are skipped (`CSalLeftOutIds::Under`), never listed at the HFS+ root.
- `src/plugins/uniso/audio.cpp`: a refused track name is recorded; the listing is never cleared.
- Out of memory and a core refusal after the rule mark the listing incomplete in all four readers.
- `src/common/salisonamefit.h`: `CSalLeftOutIds` (+ `Under`); `src/saltests/saltests.cpp`:
  `TestIsoLeftOut329`.
- No UI string added or removed (`IDS_ERR_TOO_LONG_PATH` is no longer shown; it stays in the module).

## Measurements (before / after, commands)

Probe `probe/iso329_probe.ps1` through `tools\run_on_hidden_desktop.ps1` (seeds: `mkimg329.sh` in WSL -
genisoimage `-udf`, xorriso `-hfsplus on`; `img329.py` - XDVDFS, two-track NRG):

- before (branch start = main aa939af0): `probe/result_before.txt` - RUN rows **0 / 7** ("Error" /
  "too long path", `zlast\z.txt` lost in UDF / Xbox / HFS+, the image deleted by all three unpacks,
  the audio listing empty).
- after: `probe/result_after.txt` **7 / 7** (14 / 0 with END rows); after review 1 (deeper tree):
  `probe/result_after_review1.txt` 14 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `build.cmd` -> BUILD SUCCEEDED (Debug x64). No `build.cmd full`: no UI string, resource or plug-in
  list changed.
- `saltests.exe` -> 28266 checks, 0 failed (a mutant of `CSalLeftOutIds::Under` fails 2).
- Regression probes on the fixed build: `iso328_probe` 20 / 0, `iso327_probe` 77 / 0,
  `iso322_probe` 18 / 0 (`probe/regress_*.txt`); every registry restored and identical.

## Reviews (findings and what was done)

Review 1 (independent refute-first agent): no MUST. Its negative control (uniso.spl from HEAD~1) 0 / 7,
its HFS+ mutation FAIL, a deeper tree PASS. SHOULD 1 (the HFS+ subtree decision untested by saltests)
-> `CSalLeftOutIds::Under` + a simulated-catalog walk in saltests; SHOULD 2 (probe one level deep) ->
`mkimg329.sh` adds `e/f/g.txt`, `e/f/h/hh.txt`; NOTE 5 (`free()` of a `DupStr` name in audio.cpp) fixed;
NOTE 3 and NOTE 4 -> Inbox items. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

Nothing. Every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a` - ISO plug-in: an NRG audio track label of 257+ bytes overruns a stack buffer (measure:329)
- `iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent` - ISO plug-in: an HFS+ folder whose ID is lower than its parent lists its contents at the root (review:329)
- `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let` - ISO plug-in: UDF and HFS+ entries skipped as damaged let Unpack delete the image (review:329)
