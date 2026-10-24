# Fix log - 340-nrg-session-count

Backlog item `iso-plug-in-an-nrg-session-count-above-the-image-s-tracks`.

## Measurement at 2b3f0716 (before)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED (HEAD built, incremental).
- By reading: the session loop is now `CISOImage::ListTracks` (`src/plugins/uniso/isoimage.cpp`, called by
  `ListImage`): `int trackCount = Session[session]; int lastSessionTrack = firstSessionTrack + trackCount;
  for (track = firstSessionTrack; track < lastSessionTrack; track++) switch (Tracks[track]->FSType)` - no
  bound. `Session` is `TDirectArray<int>`; `nrg.cpp` `readSINF` stores the byte-swapped DWORD through
  `AddSessionTracks(int)`, so a count >= 2^31 is negative.
- Reachable: a `.nrg` file in the panel, Enter or Alt+F9 (`CISOImage::Open` -> `ReadSessionNRG` ->
  `ReadNRGRoot` -> `readSINF`; listing `ListImage` -> `ListTracks`), "session as directory" on by default
  (`uniso.cpp`), two or more SINF chunks.
- Probe (scratch, then `probe/iso340_probe.ps1` + `probe/img340.py`; seeds by 334's `mkimg334.sh` in WSL):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\iso340_probe.ps1 -Exe build\...\tandemcommander.exe -Lib
  ... -MkImg ... -Label before"` -> `probe/result_before.txt`: **PASS 5, FAIL 9**:
  - F-FIT (1, 1), F-ZERO (0, 2): PASS (extracted, image deleted);
  - S-OVER (1, 2), S-OVER1000 (1, 1000), S-EXTRA (1, 1, 1): TRACE_C "arraylt.h Line 115: Index is out of
    range (index = 2, Count = 2)";
  - S-NEG (0xFFFFFFFF, 2): "Index is out of range (index = -1, Count = 2)";
  - S-NEGEND (1, 0xFFFFFFFF): no stop, `Session 02/b.txt` not extracted (image kept by 334's left-out mark).
  - Registry restored, identical SHA-256.
- `BL verify` recorded.
- Other readers of `Session` (enumerated): `img.cpp` (CCD: counts derived from its own track list, sum
  = tracks), `isoimage.cpp` `Session.Add(1)` (plain image), `ListTracks` (this item), `viewer.cpp`
  `DumpInfo` (F3 information: walks the track table, reads `Session[session]` when a track index reaches
  the running sum - past the session table when the counts add up to *fewer* tracks; another defect,
  Inbox item below).

## Analyze

- No CRITICAL / HIGH. LOW: T001 already done at the start commit (marked); CCD images have no row of
  their own - 335's probe (CCD rows) covers them in T006. Accepted.

## Implementation

- `src/common/salisotrack.h`: `SalIsoSessionTracks(first, declared, trackCount, fits)` - the tracks a
  session gets: `min(declared, left)` with `left` = `trackCount - first` (0 when `first` is outside the
  table), in `long long`; `fits` = `declared <= left`. The header's top comment names feature 340.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::ListTracks`: the session's track count from the rule with
  `(unsigned int)Session[session]`; `!fits` -> `TRACE_I` + `ListingLeftOut.SetIncomplete()`. The rest of
  the loop and 334's leftover loop unchanged (the running start now stays within `[0, Tracks.Count]`).
- `src/saltests/saltests.cpp`: `TestIsoSessionTracks_340` (19 direct checks, 9 count lists walked as
  `ListTracks` walks them - the probe's seven, 334's M-EXTRA, two huge counts).
- A Python edit wrote the header with LF endings; restored to CRLF before the build (git showed no
  whole-file change).

## Checks (after)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (C4267 warnings in untouched lines of audio / hfs / xdvdfs / iso9660 / udf) |
| saltests | `saltests.exe` | `saltests: 28807 checks, 0 failed` (28,761 before -> +46) |
| probe | `iso340_probe.ps1 -Label after` | `probe/result_after.txt` **PASS 14, FAIL 0** (before 5 / 9); registry restored, identical |
| regression 334 | `iso334_probe.ps1 -Label regress-340` | `probe/regress_334.txt` 23 / 1 - S-RAW, 335's intended change (as 336's and 337's runs) |
| regression 335 | `iso335_probe.ps1 -Label regress-340` | `probe/regress_335.txt` 28 / 4 - M-FORM2, S-VCD, C-VCD, C-VCDREAL: image kept where 335's rows want it deleted - 336's intended change (a Form 2 stream no file covers; 336's fix-log names the same four rows in its negative control); no other row changed |
| mutant A (bound removed: `return (int)declared`) | header edited, built, saltests | `28807 checks, 18 failed` |
| mutant B (bound kept, `fits = true`: never marks) | header edited, built, saltests + probe | saltests 16 failed; `probe/result_mutant_no_mark.txt` PASS 9, FAIL 5 - S-OVER, S-OVER1000, S-EXTRA, S-NEG, S-NEGEND image DELETED: the mark is what keeps them |
| restore | header copied back, `sha256sum -c` OK, rebuilt | saltests 28807 / 0 |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| clang-format | VS 2022 clang-format, `--lines` of the changed ranges | no change in the three files |

- Release build not driven (spec Assumptions): the Debug range check stops at exactly the index a Release
  build read past the table.
- No UI string, dialog or menu changed: no `.slt` refresh.
- 334's and 335's images all have session counts that fit (`img334.py`: 1, 1 or 2 for two tracks, 1, 1
  for M-EXTRA's three tracks; `img335.py`: 1, 1 or 2, and 2 for `single_short`'s three tracks in one
  session - not the session listing): the rule returns the declared count with `fits` for each, so this
  feature changes none of their rows; their FAILs are the recorded intended changes of 335 and 336
  (spec SC-002 and quickstart reworded - they had claimed 335 32 / 0, its result before 336).

## Inbox (measure:340)

- `iso-plug-in-the-image-information-of-an-nrg-image-reads-past` - `CISOImage::DumpInfo` (F3 on an image)
  reads `Session[Session.Count]` when the counts add up to fewer tracks than the image holds (by reading,
  not measured).
- `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard` (source `review:340`) - `readSINF` reads 4
  bytes whatever the chunk's size and does not check a short read; `readETN2` reads past its buffer for a
  chunk under 16 bytes and adds one track per chunk (review 1's NOTEs 3 and 4, confirmed by reading).

## Review

### Review 1 (refute-first, general-purpose agent) - no MUST, no SHOULD

- Re-ran on the branch build: saltests 28807 / 0; `iso340_probe` PASS 14 / FAIL 0.
- Negative control: `uniso.spl` built from a worktree at b4971538 (before the fix) into a copy of the
  build tree: `iso340_probe` PASS 5 / FAIL 9 - the same rows as `result_before.txt` (index 2 / -1 range
  stops, S-NEGEND's b.txt missing). 334's probe 23 / 1 (S-RAW) on both builds, identical rows - SC-002.
- Code: the bound holds (`first` in `[0, Tracks.Count]`, `n <= Tracks.Count - first`), 334's left-out loop
  bounded too; an empty track table with two or more sessions lists nothing and marks (before: read
  `Tracks[0]`); when every count fits `n == declared` - no case where the old code kept an image the new
  one deletes. Only caller `ListImage` <- `ListArchive`; whole unpack reads the incomplete flag. Other
  readers of `Session` enumerated (CCD always fits; `DumpInfo` - the Inbox item).
- NOTE 1 (S-NEG lists both tracks under "Session 01": a real multi-session disc would merge same-named
  files into one folder): chosen by the spec (*Clarifications*: the tracks left go to the session whose
  count does not fit); F-ZERO (valid counts 0, 2) already does the same; the listing is marked, so a
  whole unpack keeps the image. Accepted.
- NOTE 2 (no message says why the image was kept): as 328 / 334, spec FR-004. Accepted.
- NOTE 3 (`readSINF` short read / chunk size) and NOTE 4 (`readETN2` one track a chunk): Inbox item
  `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard` (review:340) - reading `readETN2` also
  showed an over-read of a chunk under 16 bytes.
- NOTE 5 (old reviewers' worktrees registered under `%TEMP%\rev325|328|330|332|335`): not this
  feature's; left for the maintainer (no `git worktree prune` by a run).
- `git status --short` after the review: empty.
