# Closing report - 369-nrg-sinf-chunk-size

Backlog item: iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard - ISO plug-in: NRG SINF and ETN2 chunks are read without regard to their size
Outcome: closed

## What changed

- `src/common/salnrgcdtext.h`: `SAL_NRG_SINF_SIZE` and `SalNrgSinfUsable(pos, size, fileSize)` - a SINF
  chunk gives its session's track count only when it is exactly 4 bytes and lies within the image.
- `src/plugins/uniso/nrg.cpp`:
  - `readSINF` takes the count only from a usable chunk read whole. Any other chunk gives no count and
    marks the listing incomplete (a whole unpack fails, so "Delete archive after unpacking" keeps the
    image).
  - `ReadNRGRoot` reads every next chunk header at the end of the chunk as its header declares it,
    whatever the reader took. This covers DAOX too.
- `src/saltests/saltests.cpp`: `TestNrgSinf369` (15 checks).
- ETN2 (the item's second half) needed no change: feature 365 had already rewritten the reader (whole
  entries only, never past its buffer, ends at the chunk's end).

## Measurements (before / after, commands)

- Probe `specs/369-nrg-sinf-chunk-size/probe/iso369_probe.ps1` (images `img369.py`, seeds from 334's
  `mkimg334.sh`), run through `tools\run_on_hidden_desktop.ps1`; the images hold two Mode 1 tracks.
- Before (720a7472): `result_before.txt` PASS 6 / FAIL 4. Each of the four images with a SINF chunk of
  8 (first or last), 2 or 0 bytes extracted only `Session 01/a.txt`, showed "Unknown track type." and
  lost session 2's `b.txt`.
- After: `result_after.txt` PASS 10 / FAIL 0, with no box in any row:
  - control: both sessions extracted, the image deleted;
  - 8 / 8-tail / 2 bytes: `b.txt` extracted, the image kept;
  - 0 bytes: both sessions extracted, the image kept.
- Mutants (fix-log *Checks*):
  - every SINF size accepted: saltests 5 failed;
  - no incomplete mark: probe 9 / 1 (S-SINF0 deletes the image);
  - no loop seek: probe 9 / 1 (S-SINF2 misread).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests`: 30078 checks, 0 failed (+15).
- `iso369_probe`: 10 / 0.
- Regression probes: `iso340_probe` 14 / 0, `nrg350_probe` 20 / 0, `iso365_probe` 22 / 0.
- Registry restored and identical after every run.
- clang-format: no difference in the changed lines.
- No UI strings changed, so no `.slt` refresh.

## Reviews (findings and what was done)

Refute-first review 1 found no MUST.
- Its own pre-fix build gave 6 / 4.
- Its extra rows R-DAOXFIT (unchanged) and R-DAOXTRAIL (fixed by the loop seek) confirm the change.
- SHOULD: a SINF chunk whose size runs past the image now ends the chunk table. The plain-image fallback
  then keeps the NRG tracks already read (R-SINFHUGE: only `a.txt`, the image kept; before, both
  sessions came out by accident and the image was deleted). It is data-safe and the fallback defect is
  older. Recorded in the spec and fix-log, with an Inbox item.
- NOTE 1: the libmirage citation was wrong; corrected.
- NOTEs 2-4: recorded.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (CHANGELOG.md has no `## [Unreleased]` section):

```text
- **A damaged session table in a Nero disc image (.nrg) lost a session's files** (feature 369).
  - **Before:** when a Nero image's session information block had an unexpected size (damaged, or written
    by another tool), the rest of its track table was read from the wrong place: unpacking gave only the
    first session's files with the message "Unknown track type.", and the other session's files were not
    extracted.
  - **Now:** such a block is ignored and the rest of the table is read from its proper place. The image is
    listed from what remains, and "Delete archive after unpacking" keeps the image because its listing is
    known to be incomplete. Other blocks whose size does not match their contents no longer shift the
    table either.
  - **Limits:** with the block ignored, fewer sessions are listed, so some files may not be shown (no
    message names them). A block whose size runs past the end of the file still ends the table, and the
    image is then opened as a plain image (kept after unpacking).
```

- No person-step item: the change is measured on crafted images. Well-formed images read exactly as
  before (regression probes), and the loop now steps through the table by each chunk's size as libmirage
  does.

## New Inbox items (slug - title)

- `iso-plug-in-an-nrg-daox-chunk-applies-track-entries-read` - ISO plug-in: an NRG DAOX chunk applies track entries read past its own end (measure:369)
- `iso-plug-in-a-failed-nrg-table-read-leaves-its-tracks-for` - ISO plug-in: a failed NRG table read leaves its tracks for the plain-image fallback (review:369)
