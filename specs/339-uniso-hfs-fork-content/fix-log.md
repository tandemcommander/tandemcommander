# Fix log - 339-uniso-hfs-fork-content

Backlog item `iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in` - ISO plug-in: an HFS+ file whose
data is compressed or only in its resource fork extracts empty.

## Measurement before (main 75fc0f43, Debug x64, `build.cmd` up to date)

- Sites: `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` (`fd.Size = dataFork.logicalSize`) and
  `CHFS::UnpackFile` (`fork = &rec.file->dataFork` only, `bFileComplete` stays TRUE for an empty data fork).
  Reached from Unpack (Alt+F9) -> `UnpackWholeArchive` -> `ExtractAllItems` -> `CUDFISO`/`CHFS::UnpackFile`,
  and from Copy (F5) / view of a single file -> `UnpackFile`.
- Seed: feature 332's `mkimg332.sh` (WSL Ubuntu, xorriso -hfsplus, `a/side.txt` hidden from ISO 9660 - only
  in the HFS+ part). Copies by `probe/img339.py` (side.txt's HFS+ file record): rsrc (content only in the
  resource fork), comp (UF_COMPRESSED 0x20 in the BSD owner flags + data in the resource fork), compin
  (UF_COMPRESSED, both forks empty), flag (UF_COMPRESSED, data fork kept), nomode (UF_COMPRESSED, file mode 0),
  both (resource fork beside the data fork), comp2 (side.txt and HFS+ top.txt compressed).
- Command (PowerShell, from the repository root; the draft lived in `%TEMP%\tc339work` then):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\339-uniso-hfs-fork-content\probe\result_before.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\339-uniso-hfs-fork-content\probe\iso339_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
- Result `probe/result_before.txt`: PASS 12, FAIL 6 (9 RUN rows). H-RSRC / H-COMP / H-COMPIN: side.txt
  written EMPTY, no box, image DELETED (the content lost); H-FLAG: the data fork written, image deleted;
  H-SKIPALL: side.txt and top.txt written empty, image deleted; H-CANCEL: no box to cancel, image deleted.
  Controls H-OK / H-NOMODE / H-BOTH pass (every file, image deleted). Registry restored, identical hash.
- `BL verify` recorded.

## Decisions

See spec *Clarifications*: refuse (count as not extracted) instead of decompressing; a Skip / Skip all /
Cancel box per refused file (silent after Skip all); the decision as a pure rule; both-forks files unchanged
(Inbox); TN1150's uninitialised BSD information (file mode type bits 0) -> the flag is not read.

## Analyze

- Run 1: no CRITICAL / HIGH. MEDIUM C1 (FR-003's untouched existing target had no row) -> row H-EXIST added
  to T007; LOW U1 (symbolic link) -> a unit check in T003. MEDIUM C2 accepted: Copy (F5) and view of a
  single file reach the same `CHFS::UnpackFile`; the probe drives the whole unpack only (as 338).
