# Closing report - 359-uniso-udf-vat-cut
Backlog item: iso-plug-in-a-cut-udf-vat-image-may-hang-the-listing - ISO plug-in: a UDF VAT image cut a few sectors after its partition start may hang the listing
Outcome: closed

## What changed

- `src/common/salisoudfvat.h`: `SalIsoUdfVatFallback(trackSectors, partStart, extentOffset, failed, taken,
  first, last)` - the VAT search's fallback to the track's last 7 sectors, decided in track sectors, 64-bit: at
  most once; none when the track holds no partition sector (the read error at once); otherwise the old condition
  (the failed read more than 7 sectors past the track's end) without the 32-bit wrap; a window that would cross
  position 0 is clipped.
- `src/plugins/uniso/udf.cpp` `CUDF::ReadSupportingTables` (case `mapVirtual`): the fallback through the rule
  with a per-search `fallbackTaken` flag; a negative track size takes no fallback.
- `src/saltests/saltests.cpp`: `TestIsoUdfVat_359` (35 checks, with a model of the search loop over track sizes,
  partition starts, extent offsets, claimed lengths and readable limits - every search ends, at most 21 reads).
- No UI string, dialog or message changed (no `.slt` refresh).

## Measurements (before / after, commands)

- Probe `probe/iso359_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`), mkudffs `mk_cdr.img`
  by `specs/356-uniso-udf-rest/probe/mkudf356.sh`, cut / raw images by `probe/rawimg359.py`:
  - before (main 13bcb6a1): PASS 9, FAIL 5 - L-RAWCUT and R-RAWCUT (a raw Mode 1 dump cut to 260 sectors,
    partition start 288): the main window stopped answering, ended by the probe; L-CUT0 showed the missing-VAT
    box instead of the read error.
  - after (9858ced4): PASS 14, FAIL 0 - the read-error box, the program answers, the image kept.
- The item's stated trigger (a 2048-byte image cut to partition start + 3) did not hang before either (measured;
  the loop's `continue` ends a wrapped window); the item's row L-CUT3 / R-CUT3 passes before and after.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- `saltests.exe`: 29,578 -> 29,613 checks, 0 failed. Mutants: the old 32-bit arithmetic 20 failed (first test
  set), no extent offset 3 failed, no 32-bit mask 1 failed - each restored and rebuilt to 0 failed.
- Probes: `iso359_probe` 14 / 0; regression `iso358_probe` 52 / 0; registry restored and identical each time.

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD S1 - the first version compared the track's sector count with the absolute
  partition start, so a VAT track of a later session lost its fallback: fixed (the rule decides in track
  sectors), negative control 3 failed. SHOULD S2 - the after probes owed: run (14 / 0, 52 / 0).
- Review 2: no MUST. SHOULD S1 - a fix-log claim overstated, the 32-bit mask untested: claim corrected, two
  checks added (mask mutant 1 failed). Notes recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (CHANGELOG.md has no `[Unreleased]` section; versions are the maintainer's):

  - **A cut UDF disc image of a CD-R / DVD-R could make Tandem Commander stop answering** (feature 359). A disc
    image of a sequentially written UDF disc (with a virtual allocation table) that was cut short - for example a
    raw 2352-byte-sector dump of an interrupted download - could make the program hang for ever when opened or
    unpacked, so it had to be ended and other work in it was lost. Now the image does not open: the ISO plug-in
    shows "Error reading virtual allocation table" (or "Missing virtual allocation table." when the cut file holds
    part of the volume without its table), and the image is kept. Limitation: a raw 2352-byte dump of a whole
    such disc still does not open.

## New Inbox items (slug - title)

- `iso-plug-in-a-raw-2352-byte-sector-dump-of-a-udf-vat-disc` - ISO plug-in: a raw 2352-byte-sector dump of a UDF
  VAT disc does not open (measure:359).
