# Fix log - 336-uniso-form2-uncovered

Backlog item `iso-plug-in-a-form-2-track-that-no-listed-file-covers-is` - ISO plug-in: a Form 2 track that
no listed file covers is deleted with the image.

## Measurement before (main e2e41399)

- `git log -- src/plugins/uniso src/common/salisotrack.h`: last change d9406b9b (feature 335, review 4) -
  the code feature 335's final probe ran on.
- `specs/335-uniso-raw-track-lost/probe/result_after_review4.txt` (that code, hidden desktop): rows S-VCD
  (one session; track 2 a 64-sector Mode 2 / 2336 Form 2 stream no directory references) and M-FORM2 (the
  stream in a session of its own, "Session NN" folders) extract `a.txt` only and DELETE the image; C-VCD
  and C-VCDREAL (CloneCD, 2352-byte sectors; the same: no file covers track 2) likewise. Reviewer 3's real
  vcdimager images (`result_review3_realvcd.txt`): every file extracted, the image deleted.
- Code trace at e2e41399: `CISOImage::Open` sets `RawLost = outside || !form2` - a Form 2 stream is never
  marked; `ListImage` opens it as `CRawFS` (lists nothing, TRUE) -> `MarkTrack(LISTED / NOT_TRIED)` ->
  `SalIsoTrackMarksListing` false -> `ListingLeftOut.Incomplete` stays false -> `UnpackWholeArchive` succeeds
  -> the core deletes the image. Reachable in the default configuration (uniso on; Alt+F9, "Delete archive
  after unpacking").
- A fresh GUI run on the e2e41399 build (`.\build.cmd`: BUILD SUCCEEDED, up to date) was refused by the
  probe: `REFUSED: tandemcommander.exe already runs` - the maintainer's installed Tandem Commander
  (`C:\Program Files\Tandem Commander`, started 07:50) runs; probes share its registry key and are never
  run beside it, and it is never stopped by a run. Retried later (see *Probes*).

## Decision

After the listing, the listed tree is walked once: every file of more than zero bytes notes the track its
start extent maps to by the unpack's own rule (`GetTrackFromExtent`, now the shared
`SalIsoTrackOfExtent`). A track feature 335 decided to be a Form 2 stream (new `Track::Form2Stream`) that
no file starts in marks the listing (`ListingLeftOut.SetIncomplete()`). See spec *Clarifications*.

## Implementation

- `src/common/salisotrack.h`: `SalIsoTrackOfExtent(trackCount, extent, extentOffsetOf)` (the rule of
  `GetTrackFromExtent`, a template over the offset accessor), `SalIsoNoteFileStart(covered, trackCount,
  extent, size, extentOffsetOf)` (a file of more than zero bytes covers the track it starts in),
  `SalIsoStreamTrackMarksListing(form2Stream, covered)`.
- `src/plugins/uniso/isoimage.h` / `.cpp`: `Track::Form2Stream` (FALSE; set in `Open`'s track-table branch
  to `!outside && form2`); `GetTrackFromExtent` calls `SalIsoTrackOfExtent`; the listing body renamed
  `ListTracks`, `ListImage` = `ListTracks` + `MarkUncoveredStreams(dir)`: only when a track is a Form 2
  stream, walks the listed tree without recursion (`TDirectArray` stack; out of memory -> nothing counts
  as covered), notes each file's start track, marks `ListingLeftOut` for each uncovered stream (NULL
  `dir` or no memory for the flags -> marked).
- `src/saltests/saltests.cpp`: `TestIsoStreamCovered_336` (32 checks).
- clang-format on the changed lines only (`--lines` from `git diff -U0 main`, never an empty list -
  335's trap): it re-laid the test's lambdas and table only.

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 28,565 -> 28,597 checks, 0 failed |
| mutant: coverage ignored | `SalIsoStreamTrackMarksListing` returns `form2Stream` | saltests 3 failed |
| mutant: zero-byte files cover | the `size == 0` guard of `SalIsoNoteFileStart` removed | saltests 2 failed |
| negative control (probe) | the `MarkUncoveredStreams(dir)` call commented out, built, `iso336_probe.ps1 -Label before-negative-control` | `probe/result_before.txt` PASS 36, FAIL 6 - S-VCDCOV2, S-VCDZERO, M-FORM2, S-VCD, C-VCD, C-VCDREAL: image DELETED; the covered controls (S-VCDCOV, C-VCDCOV, M-FORM2COV) and 335's other rows PASS; registry restored + identical |
| probe after | `iso336_probe.ps1 -Label after` | `probe/result_after.txt` PASS 42, FAIL 0; registry restored + identical |
| real Video CDs | 335's `review3/rev335c_probe.ps1 -ImgDir %TEMP%\rev335c\imgs -Label after-336` | `probe/result_realvcd.txt` PASS 10, FAIL 0 - real VCD (CCD, NRG) and SVCD (CCD) by vcdimager: every file (AVSEQ01/02.DAT 608,256 bytes, AVSEQ01.MPG 292,864) extracted, the image deleted; R-VCD-HOLE, X-SHORT kept |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| regressions | `iso322/329/330/333/334_probe.ps1 -Label regress-336` on the fixed build | `probe/regress_322.txt` 18 / 0, `regress_329.txt` 14 / 0, `regress_330.txt` 30 / 0, `regress_333.txt` 20 / 0, `regress_334.txt` 23 / 1 - the FAIL is 334's S-RAW (image kept, the row wants deleted), the change feature 335 made on purpose and recorded with the same verdict in `specs/335-uniso-raw-track-lost/probe/regress_334.txt`; registry restored + identical each |
| final build | `.\build.cmd` after clang-format; saltests; encoding guard | BUILD SUCCEEDED; 28,597 / 0; TOTAL: 0 |

## Deviations

- The item's *Expected* names feature 335's synthetic rows C-VCD and C-VCDREAL as still deleted; no file
  covers their stream track, so under the item's rule they keep the image now (spec *Clarifications* Q2).
  The deletion controls are the real vcdimager images (R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG - PASS) and the new
  covered synthetic rows S-VCDCOV, C-VCDCOV, M-FORM2COV.
- Not driven: a multi-session image listed with "Session NN" folders off (spec analyze C1) - the check runs
  once after the listing whatever path built it. A physical-disc Video CD dump: still the person step of 335
  (`check-feature-335-with-real-nrg-and-clonecd-dumps-of-video`).

## Probes

The installed Tandem Commander the maintainer ran at the start (07:50) had exited by 08:01; every probe
ran after that (the probe refuses to start beside a running copy).

## speckit-analyze

One run: 0 CRITICAL, 0 HIGH. MEDIUM C1 accepted: the multi-session listing with "Session NN" folders off
has no probe row - the check runs once after the listing whatever path built it (`ListImage` =
`ListTracks` + `MarkUncoveredStreams`). LOW C2 folded into the saltests list; LOW I1 (the item names C-VCD /
C-VCDREAL as deletion controls, but no file covers their stream) resolved in spec *Clarifications* Q2.
