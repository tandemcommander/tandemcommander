# Fix log - 383-arc-typed-target-case

Backlog item `copying-into-an-archive-folder-typed-in-another-case-packs`: Copy (F5) / Move (F6) from
disk into an archive folder typed in another case packs into a new folder beside it.

## Measurement before (at e3dfe127, main)

- Site: `src/fileswn8.cpp`, `CFilesWindow::FilesAction`, the `PATH_TYPE_ARCHIVE` branch:
  `PackCompress(HWindow, this, path, hasPath ? secondPart + 1 : "", ...)` - the typed text after
  the archive name, unchanged. Reached from F5 / F6 in a disk panel with a typed target
  `<archive>\<path>\` (a trailing backslash; without it the dialog answers "operation masks not
  supported", unchanged).
- Other `PackCompress` callers (enumerated): `src/fileswna.cpp` drag & drop / paste into an archive
  panel - the root is the panel's `ZIPPath` (spelled as listed since 273) or a folder name of its
  listing; `src/salamdr3.cpp` the archive update of edited members - the root recorded from the
  listing. Neither is this defect.
- Probe `probe/arctarget383_probe.ps1` (written for this run, built on 382's and 099's probes), run
  on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\arctarget_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before"`
  (scratch copy named `arctarget_probe.ps1`, fixture `tcarctgt`; renamed to `arctarget383_probe.ps1` /
  `tc383` when committed - same rows and checks).
  Result **22 PASS / 10 FAIL** (`probe/result_before.txt`), the same for 7z and ZIP:
  TYPED `\DOCS\` -> `DOCS\n.txt` beside `Docs`; DEEP `\dOCS\sUB\` -> `dOCS\sUB\n.txt`; NEWTAIL
  `\DOCS\New\` -> `DOCS\New\n.txt`; MOVE -> `DOCS\n.txt`; TWINS (twins `X\a.txt` / `X\A.txt`) ->
  `DOCS\n.txt`. Controls PASS: EXACT, TWINEX (`DOCS\n.txt`), AMBIG (`docs\n.txt`). Registry restored,
  identical hash.
- ZIP behaves like 7z (the item suspected ZIP's own case rules might differ - they do not).

## Decisions

- The rule is 382's `CSalamanderDirectory::ResolvePathCase` (`SalArcPathResolveCase`): exact first,
  else the listing's comparison (fold in a case-insensitive listing), in a case-sensitive listing the
  ONE folder equal ignoring case and no file of that name; the unresolved tail kept as typed. This is
  what the panel does for the same typed path (273 / 382), so the packing root equals the folder the
  panel would open. `SalArcPathRespell` (273) alone would refuse the whole path when the tail is
  missing (NEWTAIL) - not used.
- Listing: a panel showing the same archive whose recorded date and size equal the file's now (the
  stored-listing check of `salshlib.cpp`), else `PackList` (as `salshlib.cpp` paste and the 153
  edited-member check in `salamdr3.cpp`), plug-in data released as there.

## Analyze

- Round 1: HIGH C1 (the panel-listing branch had no probe row) -> row PANEL added to T008 / SC-002;
  MEDIUM I1 (the "can the format list" check missing from plan / T004) -> added; MEDIUM I2 (row
  counts) -> SC-002 / quickstart count RUN and END rows (PASS 36).
- Round 2: no CRITICAL / HIGH. Accepted LOW: U1 the Copy dialog history keeps the typed text - by
  reading (the dialog stores the history before FilesAction acts; the re-spelled root is a copy);
  U2 a stale panel listing (archive changed since listed) is re-listed - by reading, not probed.
