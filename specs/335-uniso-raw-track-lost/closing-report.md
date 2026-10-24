# Closing report - 335-uniso-raw-track-lost
Backlog item: iso-plug-in-a-data-track-in-which-no-file-system-is-found - ISO plug-in: a data track in which no file system is found lists nothing and is not marked
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SalIsoSectorIsForm2` (a stored sector is CD-ROM XA Mode 2 Form 2: 2352+
  bytes - sync, mode byte 2; 2336 bytes - no sync; a valid subheader - equal copies, channel < 32, at most
  one of data / audio / video - with the Form 2 bit) and `SalIsoForm2SectorsToCheck` (sectors 16..31
  within the track and the file; 0 when sector 16 is not in the track). `SalIsoTrackMarksListing`'s
  second parameter renamed `rawLost` (logic unchanged).
- `src/plugins/uniso/isoimage.h` / `.cpp`: `Track::OutsideImage` -> `Track::RawLost`; `CISOImage::Open`
  sets it for a track-table data track without a file system when sector 16 is outside the image (334)
  or the track is not a Form 2 stream (335); `MarkTrack` marks such a track in every listing path, so a
  whole unpack fails and "Delete archive after unpacking" keeps the image. Video CD / SVCD stream tracks
  (Form 2) are not marked. No message, no UI string, no translation change.
- `src/saltests/saltests.cpp`: `TestIsoSectorForm2_335`.
- Probe `probe/iso335_probe.ps1` (+ `img335.py`, `ccd335.py`; reviewer 3's real-vcdimager scripts in
  `probe/review3/`).

## Measurements (before / after, commands)

- Before (main e363177e): `iso335_probe` 10 / 4 - M-NOFS, M-NOFS-F1, S-NOFS, S-RAW: the image deleted
  (`probe/result_before.txt`).
- After (final code d9406b9b): 32 / 0 (`probe/result_after_review4.txt`); each review row fails on the
  build before its fix (`result_review1_before.txt` 22 / 2, `result_review2_before.txt` 28 / 2,
  `result_review3_before.txt` 7 / 1).
- Real vcdimager Video CD / SVCD (CCD, NRG): still deleted with all files (`result_review3_realvcd.txt`
  10 / 0 on the review-3 build).
- Command form: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\335-uniso-raw-track-lost\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\335-uniso-raw-track-lost\probe\iso335_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (C4267 warnings in untouched uniso files, as before). No UI strings,
  so no `build.cmd full` / `.slt` refresh.
- saltests: 28,425 -> 28,565 checks, 0 failed. Mutants: always Form 2 - 9 failed (probe 13 / 1), never
  Form 2 - 7 failed (probe 12 / 2), no track-end clamp - 6, one sector only - 12.
- Regression probes: 322 18 / 0, 329 14 / 0, 330 30 / 0, 333 20 / 0, 334 23 / 1 - its S-RAW (a Mode 1
  track of zeros) now keeps the image: the intended change (spec *Clarifications*).

## Reviews (findings and what was done)

- Reviews 1, 2, 3: each agent stopped without a report in the middle of a hidden-desktop probe; each one's
  partial work found a MUST-level hole, fixed with a negative control: (1) a 2336-byte sector overwritten
  with 0xFF / text passed as Form 2 -> valid XA subheader required; (2) UTF-16 text starting with spaces is
  a valid subheader -> sectors 16..31 must all be Form 2; (3) a 10-sector damaged track before a stream
  read the stream's sectors -> sector 16 must be inside the track. Twice the registry was restored from
  the interrupted probe's `%TEMP%\tc335_backup.reg` (identical afterwards).
- Review 4: no MUST. SHOULD S1 (the window as a tested rule) fixed; SHOULD S2 (a Form 2 track no listed
  file covers) and NOTEs (reader geometry) -> Inbox.

## Owed to a person (with the new person-step items)

- `check-feature-335-with-real-nrg-and-clonecd-dumps-of-video` - real Video CD / SVCD dumps (Nero,
  CloneCD / Alcohol, with subchannel) still deleted after a whole unpack, a damaged multi-session copy kept.
- The maintainer started the installed Tandem Commander (from Explorer) at 07:42:16 while the probe
  `after-review4` (07:41 - 07:43:26) had its settings in the shared registry key
  (`HKCU\Software\Tandem Commander`: language English, the close confirmation off). The probe restored
  the key afterwards (identical to the state before every probe). If that instance saves the probe's
  settings when it is closed, import `%TEMP%\tc335_state_after_probes.reg` (exported after the restore,
  SHA-256 F92E573A..., the state before the probes) with Tandem Commander closed.

## New Inbox items (slug - title)

- iso-plug-in-a-form-2-track-that-no-listed-file-covers-is - ISO plug-in: a Form 2 track that no listed file covers is deleted with the image
- iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables - ISO plug-in: NRG ETNF / ETN2 and multi-session CCD track tables get wrong sector sizes or ends
- iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may - ISO plug-in: Video CD MPEG files in Form 2 sectors may extract cut to 2048 bytes a sector
- check-feature-335-with-real-nrg-and-clonecd-dumps-of-video - Check feature 335 with real NRG and CloneCD dumps of Video CDs and a damaged data CD (person step)

Also seen, not this feature's: `specs/FEATURE-HISTORY.md` on `main` holds a BEL byte (0x07) in an older
entry (`T:` + BEL + `rc.zip`, a path whose backslash a here-document turned into `\a`); left unchanged.
