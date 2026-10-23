# Fix log - 325-tar-listed-hard-links

Backlog item `tar-copy-of-listed-files-leaves-hard-links-out` - Copying the files of a tar folder
leaves hard-linked names out silently. Source: review 1 of feature 309.

## Measurement before (main at 0991f43c)

- `.\build.cmd` (Debug x64, incremental) -> BUILD SUCCEEDED.
- New probe `probe/link325_probe.ps1` + fixture writer `probe/mklink325.py` (Python `tarfile`), run on
  the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."`
  -> `probe/result_before.txt`: PASS 11, FAIL 7 (registry restored, identical hash).
  - COPY-INSIDE (open `t.tar\sub`, Select All, Copy): 1 of 3 files (`c.txt`), no box - the defect.
  - COPY-INSIDE-GZ, COPY-CHAIN: the same.
  - COPY-MISSING: `c.txt`, no box (the link to a missing member is not even listed).
  - COPY-FOCUSED (End, Copy): `c.txt` copied - the link is not in the panel.
  - COPY-EXIST: no overwrite question for `e.txt` (not listed).
  - VIEW-LINK (End, F3): the viewer shows `c.txt`.
  - COPY-SYM (symbolic link left unlisted) and COPY-ROOT (feature 309's Copy of the root) PASS.
- Caller chain: panel Copy inside an archive folder -> core `UnpackArchive` with the selected names
  -> `CPluginInterfaceForArchiver::UnpackArchive` -> `CArchive::UnpackArchive` -> `DoUnpackArchive`;
  the names come from the panel listing built by `CArchive::ListArchive`, which skips every
  `Ignored` member - `ReadTarHeader` sets `Ignored` for LNKTYPE / SYMTYPE.

## Decisions

- The item's first alternative: list hard links as files (size of the data member they name) and
  extract them from that data; the target's data, when the single pass already passed it unasked,
  is read in a second pass over the archive (reopened stream) - only when such a link exists.
- Symbolic links stay unlisted (never created by the plug-in - a listed one could only fail).
- Feature 309's cases unchanged: target written -> copy; target asked but not written -> report.

## speckit-analyze

No CRITICAL / HIGH. C1 (MEDIUM, accepted): Cancel during the second pass has no probe row - the
second pass uses `WriteOutData(..., doProgress TRUE)` and `ProgressAddSize` like pass 1, checked in
review; a tiny fixture cannot be cancelled at a chosen moment. I1, U1 LOW - no change.

## Implementation

- `src/common/saltarlink.h`: `SAL_TAR_LINK_DEFER`, `SalTarLinkDecideAsked` (309's decision plus
  "target neither written nor asked / itself deferred -> DEFER"; a `..` or empty link name -> report),
  `SalTarResolveHardLink` (chain, bounded by the map size: a cycle is unresolved),
  `SalTarListedLinkSize`. saltests `TestTarLink325`.
- `src/plugins/tar/tar.h` / `untar.cpp`:
  - `CArchive` keeps the archive name (the stream keeps a pointer to this copy), offset and size;
    `ReopenStream()` opens the same (sub)stream again (gzip etc. included).
  - `ListArchive`: hard links (not refused, not a folder) are listed as files with the size of the data
    member their chain ends in (0 if none); the header keeps its own size 0 for the data skip.
  - `DoUnpackArchive`: every hard link recorded; an asked one -> `SalTarLinkDecideAsked`; DEFER stores
    `SDeferredLink`; at the end (both exits, after the cpio empty names) `ExtractDeferredLinks`: groups
    by data name, reopens, second pass with the progress bar reset (Cancel = `ProgressAddSize`), the
    first data member of each name written under the first link's name (the header's name swapped:
    overwrite question and progress name the link), the other links copied from it by 309's
    `WriteOutLinkCopy`, stops once nothing is wanted; unresolved / skipped-first -> 309's report once.
  - `UnpackOneFile` -> `UnpackOneFilePass`: a found hard link whose chain ends in a data member seen
    earlier returns `UNPACK_ONE_LINK`; the caller reopens and extracts that member as `newFileName` or the
    link's file name.
  - `precomp.h`: `<unordered_map>` before the Debug `new` macro (as `<unordered_set>`).
- Trap 123 again: a Python here-document turned `'\0'` into NUL bytes in `untar.cpp` - found by a
  byte count, fixed with a script written by the editor. `sed -i` turned the CRLF file into LF - restored.

## Checks after

- `.\build.cmd` -> BUILD SUCCEEDED; saltests -> `saltests: 27877 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe first run after: 17 PASS / 1 FAIL - COPY-EXIST got the COPY-INSIDE fixture (probe bug in
  `mklink325.py`: no `e.txt` in it); fixed the fixture selection. COPY-INSIDE, -GZ, -CHAIN, -MISSING
  (one box "(2) ... sub\b.txt -> missing.txt"), -FOCUSED, VIEW-LINK (viewer shows the disk-cache copy
  `d.txt` holding "A") PASS.
- The re-run was refused (exit 99): the maintainer started the installed Tandem Commander at 12:45 -
  probes share the registry key; waited for it to close (never touched).
- After the maintainer's instance closed: `probe/result_after.txt` first run 17 / 1 - COPY-EXIST
  wrote e.txt correctly and showed the overwrite question with the new size 131 072, but the probe
  looked for "e.txt" in the box text; the Confirm File Overwrite dialog shows the names in controls the
  driver does not read (not Static). Check changed to: exactly one box, titled Confirm File Overwrite,
  showing 131 072. Then `probe/result_after.txt` PASS 18 / FAIL 0 (registry restored, identical).
  (`result_before.txt` was taken with the earlier check texts; both checks only became stricter.)
- Regression (`probe/run_regress.ps1`, hidden desktop, `probe/regress_*.txt`): pax306 30 / 0, unp308
  12 / 0, link309 16 / 0, cpio310 52 / 0, tar321 20 / 0, unp321 12 / 0 - no row needed a change (none
  of them copies a folder's files without the link target).
- Negative control (DEFER reported instead of deferred, and UnpackOneFile's link re-read off; build of
  the working tree, then `git checkout HEAD -- src/plugins/tar/untar.cpp` and a rebuild):
  `probe/result_negctl.txt` PASS 12 / FAIL 6 - COPY-INSIDE / -GZ / -CHAIN 1 of 3 files plus a box,
  COPY-FOCUSED 0 files + box, COPY-EXIST e.txt not replaced, VIEW-LINK the "(2) sub\d.txt -> a.txt"
  box; COPY-MISSING / -SYM / -ROOT pass in both (they do not depend on the second pass). Restored
  build: `probe/result_after_restored.txt` PASS 18 / FAIL 0.
- Build warnings C4267 in untar.cpp (lines `NameLen = strlen(...)`) are pre-existing (0991f43c).
