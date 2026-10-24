# Fix log - 334-uniso-session-missing

Backlog item `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` - ISO plug-in: Unpack with
Delete archive deletes a multi-session image whose session track cannot be opened.

## Measurement at 21c3ce91 (main, before any change)

Build: `.\build.cmd` (Debug x64, up to date). Probe `probe/iso334_probe.ps1` (new; seeds
`probe/mkimg334.sh` - genisoimage in WSL Ubuntu, two sessions s1 `a.txt` "A1" and s2 `b.txt` "B2" with
`-C 0,176`; NRG images by `probe/img334.py`, ETNF + SINF chunks), run through
`tools\run_on_hidden_desktop.ps1`. Result `probe/result_before.txt`: PASS 7, FAIL 3.

| Row | Image | Result at 21c3ce91 |
|---|---|---|
| M-OK | two sessions | PASS - Session 01/a.txt + Session 02/b.txt, no window, image deleted |
| M-TERM | session 2's terminator "CD001" -> "XXXXX" | FAIL - multi-session box, Session 01/a.txt, **image deleted** |
| M-PAST | session 2's track starts past the image end | FAIL - no window (track became fsData / CRawFS, lists nothing), Session 01/a.txt, **image deleted** |
| S-OK | one session of both tracks | PASS - b.txt (last track only), image deleted |
| S-TERM | as S-OK, track 2's terminator destroyed | FAIL - no window, fallback lists track 1, a.txt, **image deleted** |

Traced (read at HEAD):
- `CISOImage::ListImage` (`src/plugins/uniso/isoimage.cpp`) - the only caller is
  `CPluginInterfaceForArchiver::ListArchive` (`uniso.cpp`), used by the panel and by
  `UnpackWholeArchive`; `UnpackWholeArchive` fails only on `pd->ListingLeftOut` (328).
- The multi-session branch ignores `ListDirectory`'s result and sets only `ret = FALSE` (the box) for a
  default-type track that does not open; `fsAudio` that does not open is skipped silently (it cannot
  fail: `OpenTrack` creates `CAudio` without an `Open`); `fsUnknown` skipped.
- The else branch: `OpenTrack(LastTrack)` failing -> every other track tried, TRUE when any lists.
  `LastTrack` = the last track whose sector 16 is ISO/UDF or HFS (`CheckForISO` / `CheckForHFS`);
  -1 for an audio CD (then the fallback is the normal path).
- `CISOImage::Open`: `DetectTrackFS` ERR_CONTINUE -> `fsData` (CRawFS: `Open` and `ListDirectory`
  return TRUE, list nothing) - also for a track none of whose sectors are in the file (M-PAST).
- Readers' `ListDirectory` FALSE returns: every one marks `ListingLeftOut` already (ISO 9660 / UDF /
  Xbox walk result 330, HFS 329/332, audio 329/331) except the trailing `return FALSE` of
  `CHFS::ListDirectory` (a record type after the class check - unreachable).
