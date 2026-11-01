# Fix log - 369-nrg-sinf-chunk-size

Backlog item `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard`.

## Measurement at 720a7472 (before)

- By reading (`src/plugins/uniso/nrg.cpp`):
  - `readSINF` reads `sizeof(DWORD)` whatever `header->Size`, does not check `read`, never seeks:
    still defective.
  - `readETN2` was rewritten by feature 365: whole `SAL_NRG_ETN2_ENTRY` entries into a stack buffer, each
    read checked, a chunk outside the image (`SalNrgChunkFits`) or implausible
    (`SalNrgEtn2ChunkPlausible`) skipped, `Seek(pos + Size)` at the end. The ETN2 half of the item's
    *Expected* already holds - no change.
  - `ReadNRGRoot` seeks to a chunk's end only for unknown chunks; `readDAOX` and `readSINF` do not end at
    their chunk's end themselves.
- Reachable: a `.nrg` file in the panel, Enter / Alt+F9 -> `CISOImage::Open` -> `ReadSessionInfo` ->
  `ReadSessionNRG` -> `ReadNRGRoot` -> `readSINF`.
- `.\build.cmd` (Debug x64, HEAD 720a7472) -> BUILD SUCCEEDED.
- Probe `probe/iso369_probe.ps1` + `probe/img369.py` (built on 340's; seeds by 334's `mkimg334.sh` in WSL),
  run from the session scratchpad with `-Lib` / `-MkImg` given:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile
  -ExecutionPolicy Bypass -File ...\iso369_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe
  -Lib ... -MkImg ... -Label before -OutFile ..."` -> `probe/result_before.txt` **PASS 6, FAIL 4**:
  - F-FIT (SINF 4: 1, 4: 1): PASS - both sessions, image deleted;
  - S-SINF8, S-SINF8TAIL, S-SINF2: only `Session 01/a.txt`, a box "UnISO - Unknown track type.", `b.txt`
    lost (image kept);
  - S-SINF0: only `Session 01/a.txt`, the same box, `Session 02/b.txt` lost.
  - Registry restored, identical SHA-256.
- `BL verify` recorded.

## Decisions

- A SINF chunk is used only at exactly 4 bytes, within the image, read whole; any other is refused (no
  count) and marks the listing incomplete (spec Assumptions: conservative - refuse rather than guess).
- `ReadNRGRoot` reads the next chunk header at `chunk start + Size` after every known reader (the item's
  first option), covering DAOX too.

## Analyze

- No CRITICAL / HIGH. LOW U1 (scenario 2's files named only in the probe) and LOW I1 (mutant (c) of
  T007 is the before build) accepted. Coverage 100 % (FR-001..006, SC-001..003).

## Implementation

- `src/common/salnrgcdtext.h`: `SAL_NRG_SINF_SIZE` (4) and `SalNrgSinfUsable(pos, size, fileSize)` -
  exactly 4 bytes and `SalNrgChunkFits`; the top comment names feature 369.
- `src/plugins/uniso/nrg.cpp`:
  - `readSINF`: file size and position as `readCUEX`; the count only when `SalNrgSinfUsable` holds and
    the 4 bytes are read whole (`getDWord`, the same byte swap as before, cast to `int` as before); else
    `TRACE_I`, `iso->ListingLeftOut.SetIncomplete()`, no count, return FALSE.
  - `ReadNRGRoot`: the position after each chunk header (`chunkStart`, FALSE when negative) and, after
    every chunk - known reader or not - `Seek(chunkStart + Size, FILE_BEGIN)` (FALSE when it fails). For
    an unknown chunk this is what `Seek(Size, FILE_CURRENT)` did; also for the footer "NER5" header
    (the loop's end) the seek is the same as before.
- `src/saltests/saltests.cpp`: `TestNrgSinf369` (15 checks), called after `TestNrgEtn365`.
- Trap: the Edit tool rewrote `nrg.cpp` with LF endings (git normalizes, `autocrlf=true`); the file was
  converted back to CRLF with a Python byte replace before the mutants (`file`: CRLF).

## Checks (after)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `saltests.exe` | `saltests: 30078 checks, 0 failed` (+15: `TestNrgSinf369`) |
| probe | `iso369_probe.ps1 -Label after` | `probe/result_after.txt` **PASS 10, FAIL 0** (before 6 / 4): S-SINF8 / S-SINF8TAIL / S-SINF2 extract `b.txt` (one session left; 334's single-session mark and this feature's mark keep the image), S-SINF0 both sessions, image kept; no box in any row; registry restored, identical |
| mutant A (`SalNrgSinfUsable` = `SalNrgChunkFits` only, every size accepted) | header edited, built, saltests | `30078 checks, 5 failed` |
| mutant B (no `SetIncomplete` in `readSINF`) | built, probe | `probe/result_mutant_no_mark.txt` 9 / 1 - S-SINF0 extracts both sessions and DELETES the image |
| mutant C (no loop seek; unknown chunks seek as before) | built, probe | `probe/result_mutant_no_seek.txt` 9 / 1 - S-SINF2 lists only `a.txt` (the table misread); S-SINF8 passes by chance (its 8 body bytes read as an empty unknown chunk `\0\0\0\1`) |
| restore | backups copied back, no `MUTANT` left, `file`: CRLF, rebuilt | saltests 30078 / 0 |
| regression 340 | `iso340_probe.ps1 -Label regress-369` | `probe/regress_340.txt` 14 / 0 (as recorded) |
| regression 350 | `nrg350_probe.ps1 -Label regress-369` | `probe/regress_350.txt` 20 / 0 (as `result_final.txt`) |
| regression 365 | `iso365_probe.ps1 -Label regress-369` | `probe/regress_365.txt` 22 / 0 (as recorded) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| clang-format | VS 2022 x64 clang-format, diff of the three files | no difference in the changed lines (saltests' include block differs already at HEAD) |

- The item's ETN2 half: no change (feature 365); covered by `iso365_probe` 22 / 0.
- No UI string, dialog or menu changed: no `.slt` refresh.
- Release build not driven; crafted images only.

## Inbox (measure:369)

- `iso-plug-in-an-nrg-daox-chunk-applies-track-entries-read` - `readDAOX` reads as many 0x2A-byte entries
  as its track range claims, past its chunk (by reading, T010).

## Review

### Review 1 (refute-first, independent agent)

- No MUST. Re-ran the measurement on its own pre-fix build (worktree at 703666e0, its own build folder,
  copies of the Debug tree): before 6 / 4, after 10 / 0 - as recorded. saltests 30078 / 0; mutant A's 5
  failures match the five size checks. Extra rows: R-DAOXFIT (a whole DAOX chunk) PASS before and after;
  R-DAOXTRAIL (a DAOX chunk 6 bytes longer than its entries) before only `a.txt`, after both sessions -
  the loop seek covers DAOX. Callers enumerated (`ReadSessionNRG` <- `ReadSessionInfo` <- `Open`);
  CUEX / ETN2 / CDTX seek to the same position twice; `CBufferedFile::Seek` allows a seek past the end;
  the incomplete mark is never reset. Registry restored, identical.
- SHOULD 1: a SINF chunk whose size runs past the end of the image now ends the chunk table and the image
  goes to the plain-image fallback, which keeps the NRG tracks already read (`LastTrack = 0` names the
  first ETNF track) - R-SINFHUGE (SINF declaring 0xFFFFFFF0 bytes): before both sessions extracted and
  the image deleted (the old reader ignored the size - by accident), after only `a.txt`, the image kept,
  no box. Data-safe; the fallback defect existed for unknown / CUEX / ETN2 / CDTX chunks. **Done**:
  recorded in the spec's Edge Cases and here; Inbox `iso-plug-in-a-failed-nrg-table-read-leaves-its-tracks-for`
  (review:369). Not fixed here: the declared size is the only position of the next header the image
  gives - continuing after 4 bytes would be a guess (spec Clarifications).
- NOTE 1: the libmirage citation was wrong (libmirage never reads SINF; it counts DAOX entries as
  `(length - 22) / 42` and steps through the table by each header's size). **Done**: `research.md` R1
  and the `img369.py` docstring corrected; the DAOX Inbox item's Expected already asks for that count.
- NOTE 2: S-SINF8 / S-SINF8TAIL / S-SINF2 now give `b.txt` without a box (before: `a.txt` + "Unknown track
  type."); the image is kept (329 / 334 convention, spec Assumptions). Recorded as a limit.
- NOTE 3: closing artifacts not yet written - expected before step 8.
- NOTE 4: old review worktrees of other features (`%TEMP%\rev325` ... `rev341r3`) are still registered -
  not this feature's; left as they are.
- No source code changed after the review: no rebuild or re-run needed (the edits are documents and a
  probe docstring).
