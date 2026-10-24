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

### Review 2 (stopped - partial work)

The fresh reviewer (launched 06:16) wrote its last file at 06:26 and stopped in the middle of a probe
run: no tandemcommander.exe running, `%TEMP%\tc335_backup.reg` and the `tc335` fixture left. The
registry was restored from that backup first (its hash F92E57... = the known state; the key differed:
7F195C...; after the import identical F92E57...). Two wakeups without progress -> treated as stopped.
Its partial work (`%TEMP%\rev335b`):

- **a hole (MUST level)**: rows X-U16-F1 / X-U16S-F1 - a 2336-byte Form 1 track with destroyed
  descriptors whose sector 16 is overwritten with UTF-16LE text that starts with spaces ("20 00 20 00"
  twice: file 0x20, channel 0, submode 0x20 = Form 2, coding 0 - a valid XA subheader): image deleted
  on the review-1 build.
- X-VCDREAL (CCD, vcdimager-like subheaders: front margin 0x60, video 0x62 / 0x10 trigger, audio 0x64,
  file 1, channels 0 / 1): image deleted - correct (a control).
- F-NOFS / F-FORM2 with "Session NN" off: kept / deleted - correct. F-OK-2336 (flat listing of two
  intact sessions, s2.iso made without -M) lists only b.txt - feature 334's recorded by-design limit
  (the reviewer's row expected both files); not this feature.
- X-VCDFILE: a.txt's directory record patched (no XA attributes) to point into track 2's Form 2
  sectors - extracted with the wrong content. The ISO 9660 reader's existing handling of file extents in
  Form 2 sectors, outside this item (it neither lists nor marks anything differently); real Video CD
  files carry XA attributes - left to the person step with a real Video CD image.

Fix: a track is a Form 2 stream only when every sector from 16 on, up to `SAL_ISO_FORM2_STREAM_SECTORS`
(16) of them within the track (`DataEnd`, when after `DataOffset`) and the file, is Form 2 - sector 16
always (`CISOImage::Open`). A Video CD's MPEG track is Form 2 throughout; the Form 1 sectors after a
damaged sector 16 decide. Rows taken into the probe (`img335.py` multi_u16_f1 / multi_u16s_f1,
`ccd335.py` ccd_vcdreal; rows M-U16-F1, M-U16S-F1, C-VCDREAL). Negative control: the extended probe on
the review-1 build e1747a28 (`result_review2_before.txt`) 28 / 2 (M-U16-F1, M-U16S-F1 deleted); fixed
build (`result_after_review2.txt`) 30 / 0. saltests 28,543 / 0 (the per-sector rule unchanged).
Regressions again: `regress_329.txt` 14 / 0, `regress_334.txt` 23 / 1 (S-RAW, the intended change).
Encoding guard 0. Residual limit: a damaged track whose sectors 16..31 are all overwritten with data
that forms valid Form 2 subheaders is still taken as a stream.

### Review 3 (stopped - partial work)

The third reviewer (launched ~07:00) stopped like the first two: its last file at 07:11:42, in the
middle of its negative-control probe (at 3b0c315f, in its own tree) - `%TEMP%\tc335_backup.reg` and
the `tc335` fixture left, no tandemcommander.exe. Registry restored from the backup at 07:23 (backup
F92E57..., the key 9F2928..., after the import identical F92E57...). Its partial work (`%TEMP%\rev335c`;
scripts kept in `probe/review3/`):

- **real Video CD / SVCD images** (vcdimager 2.0.1, ffmpeg pal-vcd / pal-svcd in WSL): every sector from
  INDEX 01 -150 .. +59 of each MPEG track is Mode 2 Form 2 with valid XA subheaders (00 00 20 00 pregap;
  01 00 60 00 front margin x30; 01 01 62 0F video; 01 01 64 7F audio; SVCD 62 80 / 64 80). On the
  review-2 build: R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG (ETNF 2336) all files extracted, the image deleted
  (as before the feature); R-VCD-HOLE (track 2's sector 20 zero-filled, a dumper's fill) kept - the
  accepted cost (fails closed).
- **a hole (MUST level)**: X-SHORT - one session: s1, a 10-sector Mode 2 / 2336 Form 1 track, then a
  64-sector Form 2 stream track: the short track's "sector 16" lies in the stream track, so the loop read
  the stream's sectors and took the damaged track as a stream - the image deleted.

Fix: sector 16 itself must lie within the track (when the track's end is known: `DataEnd` after
`DataOffset`) and within the file, else the track is not a stream (`CISOImage::Open`). Row taken into
the probe (`img335.py` single_short, row S-SHORT). Negative control on the review-2 build d1217c5e
(`result_review3_before.txt`, `-Only S-SHORT,S-VCD,C-VCD,C-VCDREAL`): 7 / 1 (S-SHORT deleted); fixed
build: `result_after_review3.txt` 32 / 0; the reviewer's real-vcdimager probe on the fixed build
(`result_review3_realvcd.txt`, its images in `%TEMP%\rev335c\imgs`) 10 / 0 - real VCD (CCD, NRG) and
SVCD still deleted with all files, the zero-filled VCD kept, X-SHORT kept. saltests 28,543 / 0.

### Review 4 (report)

No MUST. Ran saltests 28,543 / 0 and a probe of an MDF image without .mds (the path without a track
table): F-MDF-OK deleted with a.txt, F-MDF-NOFS (every CD001 destroyed) 0 files, kept - PASS; registry
restored + identical.

- **S1 (fixed)**: the stream window of reviews 2 / 3 (sectors 16..31 within the track and the file,
  sector 16 inside the track) lived only in the plug-in - no saltests check executed it (FR-005, the
  standing rule on pure decisions). Now `SalIsoForm2SectorsToCheck(sector16At, sectorRawSize,
  trackStart, trackEnd, fileSize)` in `salisotrack.h` returns how many sectors to read (0 = not a
  stream); `Open` reads them. saltests +22 -> 28,565 / 0; mutants: no track-end clamp - 6 failed, one
  sector only - 12 failed. Probe on the final code `result_after_review4.txt` 32 / 0 (registry restored,
  identical; "fixture removed: False" - an empty `%TEMP%\tc335` folder stayed).
- **S2 (Inbox)**: a Form 2 track is taken as safe even when no listed file covers it (S-VCD, M-FORM2:
  the synthetic stream is referenced by no directory; on real Video CDs AVSEQnn.DAT covers it) -
  a stricter rule (a listed file's extent must start in the Form 2 track) is beyond the item -> Inbox.
- NOTEs: `DataEnd` per reader (DAOX / ETNF right; ETN2 sets `End` from a length field; a multi-session
  CloneCD image's session split on `Index == 0` may fail - existing, not this feature's; a corrupt DAOX
  End < Start skips the clamp - the file bound applies); ETNF's sector size from `mode & 1` reads mode
  0x06 (raw Mode 2, 2352) as 2048 and 0x05 (raw Mode 1) as 2336 - existing, now such tracks are kept
  (fails closed) -> Inbox; 2448-byte layouts only reach this code through DAOX; images without a track
  table never set `RawLost`; the 16-sector window can still be fooled by a 4-byte-periodic fill of all
  of sectors 16..31 (residual limit, recorded).

Not re-run on the final code: reviewer 3's real-vcdimager probe (the refactor keeps the window; the
maintainer started the installed Tandem Commander at 07:42:16 from Explorer - while probe
`after-review4` (07:41 - 07:43:26) had its settings in the shared registry key - so no further GUI probe
ran; the key's state after the probe's restore, F92E57... = the state before every probe, is saved as
`%TEMP%\tc335_state_after_probes.reg` for the maintainer, see the closing report).
