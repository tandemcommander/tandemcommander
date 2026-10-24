# Fix log - 335-uniso-raw-track-lost

Backlog item `iso-plug-in-a-data-track-in-which-no-file-system-is-found` - ISO plug-in: a data track in
which no file system is found lists nothing and is not marked.

## Measurement before (main e363177e)

- Read: `CISOImage::Open` (`src/plugins/uniso/isoimage.cpp`) - a track-table track for which
  `DetectTrackFS` returns `ERR_CONTINUE` becomes `fsData`; feature 334 sets `Track::OutsideImage` only
  when sector 16 is not within the file. `MarkTrack` -> `SalIsoTrackMarksListing(kind, outsideImage,
  outcome)` (`src/common/salisotrack.h`): a data track that opens and lists (CRawFS lists nothing,
  returns TRUE) or that a single listing does not try is not marked.
- Reachable: Unpack (Alt+F9) of the whole image, "Delete archive after unpacking" - the default
  configuration (uniso on, "Session NN" folders on).
- Probe `probe/iso335_probe.ps1` (new; seeds by 334's `mkimg334.sh` in WSL Ubuntu, NRG images by
  `probe/img335.py`) on the Debug build of e363177e (`.\build.cmd` - BUILD SUCCEEDED, up to date):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso335_probe.ps1 -Exe ...\Debug_x64\tandemcommander.exe -Label before -Lib ...\fix_probe_lib.ps1 -MkImg ...\mkimg334.sh"
  ```

  Result `probe/result_before.txt`: PASS 10, FAIL 4 - M-NOFS, M-NOFS-F1, S-NOFS, S-RAW: the image
  DELETED (b.txt of track 2 lost); controls M-OK-2336 (Mode 2 / 2336 Form 1 intact: both files),
  M-FORM2 and S-VCD (Form 2 streams): image deleted, as wanted. Registry restored, identical.

## Decision

A data track's sector 16 (where every file system the plug-in reads is looked for) tells a Mode 2
Form 2 stream (a Video CD's MPEG track - descriptors are never in Form 2 sectors) from a file system
area no reader understands. Not Form 2 (Mode 1, Form 1, destroyed / unreadable header, 2048-byte
sectors) -> marked, fails closed. See spec *Clarifications*.

## speckit-analyze

One run: 0 CRITICAL, 0 HIGH. LOW accepted: C1 (FR-006 "no track table unaffected" rests on the code
site - the change is inside the `ReadSessionInfo` branch of `Open` - and the regression probes of
322 / 329 / 330 on plain images), C2 (a one-session image whose only data track has no file system -
unchanged path, not a probe row), A1 (SC-001 counts END + RUN rows).

## Implementation

- `src/common/salisotrack.h`: `SalIsoSectorIsForm2(raw, len, sectorRawSize)` - 2352+ bytes a sector:
  sync `00 FF x10 00`, mode byte 2 at 15, submode bit 0x20 at 18 and 22; 2336: bit 0x20 at 2 and 6;
  any other size, a short read, NULL: false. `SalIsoTrackMarksListing`'s second parameter renamed
  `rawLost` (logic unchanged; 334's tests unchanged).
- `src/plugins/uniso/isoimage.h` / `.cpp`: `Track::OutsideImage` -> `Track::RawLost`; `Open` sets it
  for an fsData track to `outside || !form2`, reading 24 bytes (2352+) or 8 bytes (2336) of the stored
  sector 16 at `GetSectorOffset(0x10) - SectorHeaderSize` with `ReadDataByPos` (only when not outside).
  `MarkTrack` passes `RawLost`; comments in `ListImage` updated. Only the `ReadSessionInfo` branch
  (track tables) is touched.
- `src/saltests/saltests.cpp`: `TestIsoSectorForm2_335` (36 checks).
- clang-format of the changed lines only (`--lines`, 334's trap); the ternary it laid out over two
  lines was rewritten as an if-chain.

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (warnings C4267 in untouched uniso files, as before) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 28,425 -> 28,461 checks, 0 failed |
| mutant: always Form 2 (the stored header ignored) | the rule's last line `return true;` | saltests 9 failed; probe `result_mutant_form2_always.txt` 13 / 1 (M-NOFS-F1 deleted - a 2336 Form 1 track taken as a stream) |
| mutant: never Form 2 (every raw track marked) | `return false;` | saltests 7 failed; probe `result_mutant_form2_never.txt` 12 / 2 (S-VCD, M-FORM2 kept - every Video CD's whole unpack would fail) |
| probe after | `iso335_probe.ps1 -Label after` (hidden desktop) | `result_after.txt` 14 / 0 (before 10 / 4); registry restored, identical |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| regressions | `iso322/329/330/333/334_probe.ps1 -Label regress-335` on the fixed build | `probe/regress_322.txt` 18 / 0, `regress_329.txt` 14 / 0, `regress_330.txt` 30 / 0, `regress_333.txt` 20 / 0, `regress_334.txt` 23 / 1 - the one FAIL is 334's S-RAW (a Mode 1 track of zeros: image now KEPT, want deleted) - the intended change (spec *Clarifications* Q3; the same image is this probe's S-RAW, PASS); registry restored + identical each |

FR-006 (images without a track table unaffected): the plain ISO / UDF / HFS+ / Xbox images of 322, 329,
330 and 333 pass unchanged.

## Deviations

None from the item. Not driven: a real Video CD / SVCD image and a CCD/IMG (2352-byte) image - no such
image in the repository and no tool in WSL writes one here; the 2352 layout is covered by saltests only
(person step at closing).

## Review

### Review 1 (stopped - partial work)

The first reviewer agent wrote no report: its last file (`%TEMP%\rev335\rev_ff.txt`) was written at
05:47, nothing followed until 06:10 (two wakeups without progress, the agent no longer listed) - treated
as stopped (SKILL.md step 7). Its partial work, from its files in `%TEMP%\rev335`:

- negative control at 3b0c315f (worktree `rev335\neg`) with its own CloneCD writer (`ccd335.py`, raw
  2352-byte sectors): before 14 / 6 (C-NOFS-M1, C-NOFS-F1 deleted too; C-VCD control deleted), on the
  fixed build 20 / 0 - the 2352 layout works as the rule says;
- **a hole (MUST level)**: rows M-FF-F1 / M-TXT-F1 - a 2336-byte Form 1 track with destroyed descriptors
  whose sector 16 (subheader included) is overwritten with 0xFF or with text: still taken as a Form 2
  stream, the image DELETED. A 2336-byte sector has no sync; the rule checked only the Form 2 bit of the
  two submode copies (0xFF and "lorem ip" both set it).

Fix: `SalIsoSectorIsForm2` accepts a subheader only when it is a valid CD-ROM XA subheader - both
copies equal (all four bytes), the channel number below 32, at most one of the data / audio / video
submode bits - and the Form 2 bit is set (for 2352+ in addition to the sync and mode byte). saltests
+82 checks (0xFF / text / equal-copies text, a table of valid and invalid subheaders in both layouts,
copies differing in each byte) -> 28,543 / 0. The reviewer's rows taken into the feature's probe
(`img335.py` kinds multi_ff_f1 / multi_txt_f1, `ccd335.py` copied, rows M-FF-F1, M-TXT-F1, C-VCD,
C-NOFS-M1, C-NOFS-F1). Negative control: the extended probe on the a5af8563 build
(`result_review1_before.txt`) 22 / 2 (M-FF-F1, M-TXT-F1 deleted); on the fixed build
(`result_after_review1.txt`) 24 / 0. (A first attempt to patch the probe from a Bash here-document
collapsed its backslashes - an assert stopped it, nothing written; done with the editor, CLAUDE.md 123.)
