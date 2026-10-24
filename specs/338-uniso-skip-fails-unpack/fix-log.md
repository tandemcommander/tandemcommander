# Fix log - 338-uniso-skip-fails-unpack

Backlog item `iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success`.

## Measurement before (main at 0cec8e25)

- `.\build.cmd` (Debug x64, up to date). Probe `probe/iso338_probe.ps1` (new; seeds by `mkimg338.sh` in WSL
  Ubuntu genisoimage, damaged copies by `img338.py`) through `tools\run_on_hidden_desktop.ps1` with
  `-NonInteractive -Lib <098 lib>` -> `probe/result_before.txt`: **PASS 10, FAIL 6** - every RUN row but the
  controls OK / O-YES deleted the image: R-SKIP (read error, Skip), R-SKIPALL (Skip all; the second read
  error showed no box), C-SKIP (folder top.txt in the target, Skip), O-SKIP (user's top.txt, overwrite Skip),
  TWINS (two records TOP.TXT, overwrite Yes - top.txt = TOU, TOP lost), D-SKIP (a file zlast in the target:
  "Error Creating Directory" with Retry / Cancel only - closed, then z.txt's box Skip). Registry restored +
  identical.
- Reachability: Alt+F9 on an image in the panel -> core Unpack dialog -> `UnpackWholeArchive` ->
  `ExtractAllItems` -> `CISOImage::UnpackFile` -> reader's `UnpackFile` (default configuration).
- Code read: `ExtractAllItems` keeps only `UNPACK_CANCEL`; `UnpackDir`'s result ignored; the readers'
  silent read errors return `UNPACK_OK` (research R2); HFS+ cases R3; the core's `AddFile` keeps
  same-name files (R4).

## Decisions

See spec *Clarifications* and research R1-R5.
