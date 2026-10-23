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
