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
