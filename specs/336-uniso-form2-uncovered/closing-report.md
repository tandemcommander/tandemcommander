# Closing report - 336-uniso-form2-uncovered
Backlog item: iso-plug-in-a-form-2-track-that-no-listed-file-covers-is - ISO plug-in: a Form 2 track that no listed file covers is deleted with the image
Outcome: closed

## What changed

- `src/common/salisotrack.h`: `SalIsoTrackOfExtent` (the unpack's rule for the track a file's start
  extent lies in), `SalIsoNoteFileStart` (an ISO 9660 file of more than zero bytes covers the track it
  starts in; not a disc address, an empty file or a track above 255 covers nothing),
  `SalIsoStreamTrackMarksListing`.
- `src/plugins/uniso/isoimage.h` / `.cpp`: `Track::Form2Stream` (the tracks 335 took as Form 2 streams);
  `GetTrackFromExtent` calls the shared rule; `ListImage` = `ListTracks` + `MarkUncoveredStreams` (walks
  the listed tree once, without recursion, when a stream exists; an uncovered stream marks
  `ListingLeftOut` - a whole unpack fails, "Delete archive after unpacking" keeps the image). No UI
  string, no plug-in interface change.
- `src/saltests/saltests.cpp`: `TestIsoStreamCovered_336` (37 checks).
- `CHANGELOG.md`: entry under 0.1.11 (unreleased); 335's limitation updated.

## Measurements (before / after, commands)

- Before (e2e41399): 335's `result_after_review4.txt` on the same code - S-VCD, M-FORM2, C-VCD, C-VCDREAL
  (a Form 2 stream no file covers) deleted the image. Negative control on this branch (the mark call
  commented out): `probe/result_before.txt` 36 / 6 - S-VCD, M-FORM2, C-VCD, C-VCDREAL, S-VCDCOV2,
  S-VCDZERO deleted.
- After: `iso336_probe.ps1` (hidden desktop, `tools\run_on_hidden_desktop.ps1`)
  `probe/result_after_review2.txt` 44 / 0; `-FoldersOff` `probe/result_after_review2_foldersoff.txt` 6 / 0;
  real vcdimager VCD / SVCD (`specs/335-uniso-raw-track-lost/probe/review3/rev335c_probe.ps1 -ImgDir
  %TEMP%\rev335c\imgs`) `probe/result_realvcd_review2.txt` 10 / 0 - covered streams still deleted, every
  file extracted.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no UI string -> no `.slt` refresh, no `build.cmd full`).
- saltests: 28,565 -> 28,602 checks, 0 failed; mutants: coverage ignored 3 failed, empty files cover 2.
- Probes: above; regressions `probe/regress_322..334.txt` 18 / 0, 14 / 0, 30 / 0, 20 / 0, 23 / 1 (334's
  S-RAW - feature 335's intended change, the same verdict as 335 recorded); registry restored +
  identical after every run.

## Reviews (findings and what was done)

- Review 1: MUST - covered real Video CD video files extract cut (2048 of 2324 bytes a sector; 61,272
  bytes of a vcdimager VCD, 39,468 of an SVCD) and the image is deleted. Pre-existing, outside this item
  (whose *Expected* wants covered Video CDs deleted as before; 336 deletes strictly fewer images than
  main); the interim choice is a real trade-off -> decision item; claims corrected. SHOULD - content
  check of covered files in the probe (done). NOTE - only ISO 9660 entries are disc addresses (done).
- Review 2: no MUST; confirmed the fix incl. folders off, with a negative control on main. SHOULD - the
  cut item lacks review 1's measurement (not edited: agent mode extends only items of its own session;
  see below). NOTEs: track above 255 (fixed), stale wording (fixed), folders-off rows (taken), partial
  coverage (Inbox).

## Owed to a person (with the new person-step items)

- The maintainer: decide `keep-video-cd-images-after-a-whole-unpack-until-their-video` (Inbox); when
  triaging `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may`, note that review 1 of 336 measured the
  cut on real vcdimager images (the numbers are in the decision item) - it loses data with "Delete archive
  after unpacking", so its severity 5 / "may" is out of date.
- No new person step; a physical-disc Video CD dump remains 335's person step
  `check-feature-335-with-real-nrg-and-clonecd-dumps-of-video`.

## New Inbox items (slug - title)

- keep-video-cd-images-after-a-whole-unpack-until-their-video - Keep Video CD images after a whole unpack until their video extracts whole? (decision, severity 7)
- iso-plug-in-a-file-covering-part-of-a-form-2-stream-lets-the - ISO plug-in: a file covering part of a Form 2 stream lets the image be deleted (bug, severity 7)
