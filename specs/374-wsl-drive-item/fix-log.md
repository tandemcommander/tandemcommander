# Fix log - 374-wsl-drive-item

Backlog item `change-drive-menu-and-drive-bar-have-no-wsl-item-for-the`; run started at
`30268b7c` (main), branch `374-wsl-drive-item`.

## Measurement at 30268b7c (before)

- Read `CDrivesList::BuildData` (`src/drivelst.cpp`): Documents, cloud storages (Google Drive,
  Dropbox, OneDrive), Network, plug-in items, hot paths, As Other Panel; no WSL entry.
  `src/` refers to WSL only in 372 (`salbkgndcheck.h`, `fileswn6.cpp`) and 373
  (`saluncserver.h`). Gap present - `BL verify` recorded.
- This computer: `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` holds
  `{46fb5931-...}` `docker-desktop` (v2, State 1, Flags 15) and `{78c7c8d9-...}` `Ubuntu`
  (v2, State 1, Flags 15, the DefaultDistribution); `wsl.exe -l --running` -> no running
  distribution. `Get-ChildItem` of the key: 8 ms in PowerShell.
- `%SystemRoot%\System32\wsl.exe` icon index 0 = Tux (extracted to PNG and looked at), so is
  `%ProgramFiles%\WSL\wsl.exe`.
- The probe seam `TC_PROBE_DRIVES_DUMP` (246, 289) dumps `ALL idx= type= text=` for every built
  item; `specs/289-drive-list-wide-texts/probe/run289.ps1` relies on the type numbers 7
  (Documents), 13 (Network), 14 (As Other Panel), 1..14 for its ALL rows -> the new item types are
  appended at the end of `CDriveTypeEnum`.
- Free string slot 14169 (bundle 885 = 14160-14175, beside IDS_ONEDRIVE*); no other define of
  14169 in `src/`.

## Decisions

See spec *Clarifications*: one item per distribution (`Linux - <name>`), OneDrive pattern on the
drive bar, every installed distribution (State 1 or absent), after the cloud storages and before
Network, icon from `System32\wsl.exe` (fallback: the Network icon).

- **Deviation (settings import)**: the item asks for the option to be "imported like
  `ChangeDriveShowNet`". That import (`cfgimport.cpp`, 245) reads Altap / Open Salamander settings,
  which have no such value, and rule 245 FR-016 keeps Tandem Commander's own settings off its
  allow-list (`saltests` counts 112 entries). Not added; the program's own export / import (a `.reg`
  of the whole key) carries the value unchanged. Spec *Assumptions*.
- `&` in a distribution name is doubled in the menu and in the drive bar's tooltip (both show `&`
  as the hot key mark - 289's rule for the bar's tooltips).
- T014's "a single button while several exist posts the drive-bar refresh" (the OneDrive
  special case) was not added: the set of distributions is folded into the cloud storages mask
  (`0x20 | fingerprint << 8`), so the next Alt+F1 rebuilds the bars when it changed; a single
  button of a distribution removed meanwhile ends in the ordinary "path not found" box.

## speckit-analyze

Round 1: 0 CRITICAL, 0 HIGH, 1 MEDIUM (E1: FR-010 had no probe row), 2 LOW (F1: FR-005 lacked `.` /
`..` / 255 characters; E2: no non-ASCII name check). All three fixed in spec / tasks. Round 2:
nothing left.

## Implementation

- `src/common/salwsl.h` (new): `SalWslDistroUsableW`, `SalWslDistroPathU8`, `SalWslPathOnDistroU8`,
  `SalWslItemTextAlloc`, `SalWslFingerprintAdd` / `Fold`; `saltests` `TestWslDistros374`.
- `src/drivelst.h/.cpp`: `drvtWSL` (19), `drvtWSLMenu` (20) appended; `GetWslDistributions` /
  `FreeWslDistributions` (HKCU `...\Lxss`, `State` absent or 1, `DistributionName` REG_SZ, usable,
  UTF-8, sorted by `SalNameOrderCompareCI`, case-insensitive duplicates dropped; Debug seam
  `TC_PROBE_WSL_LXSS`); `LoadWslIcon` (`SHDefExtractIconW` of `System32\wsl.exe`, else Network icon);
  `BuildData` items after the cloud storages, mask, focus, probe lines `WSL` / `FOCUS` / `TIME`;
  `ExecuteItem` (both types; the drop-down re-reads the list), `IncludeDriveInDriveBar`,
  `FillDriveBar`, `GetDriveBarToolTip`, `OnContextMenu`, `FindPanelPathIndex`.
- `src/fileswn3.cpp` `ChangeDrive` + new `CFilesWindow::ChangePathToWslDistro` (refuses with
  `IDS_TOOLONGPATH` when the path does not fit); `src/toolbar6.cpp` `CDriveBar::Execute`.
- Option `ChangeDriveShowWSL` (cfgdlg.h, default TRUE in dialogs4.cpp, transfer dialogs5.cpp,
  `Change Drive Show WSL` in mainwnd2.cpp); checkbox `IDC_CHD_SHOWWSL` (6290) "&Linux Distributions
  (WSL)" on IDD_CFGPAGE_CHANGEDRIVE (group box 73 -> 86, controls below +13); `IDS_WSLLINUX` 14169.
- Manual: `help/src/hh/salamand/configuration_chdrv.htm`, `navigating_chdrvmenu.htm`,
  `windows_drivebar.htm`.
- Traps met: the shell collapses doubled backslashes in here-documents (also inside Python) -
  comments and the saltests strings were rewritten through editor-written scripts (CLAUDE.md rule
  123); `small` is a macro (125's trap) - `iconSmall`.

## Checks

- `.\build.cmd` -> BUILD SUCCEEDED (warnings in salamdr2.cpp / zip.cpp are older);
  `.\build.cmd full` -> BUILD SUCCEEDED, 189 language modules.
- `saltests.exe` -> `saltests: 30221 checks, 0 failed` (30155 before, +66).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.

## Probe `probe/wsl374_probe.ps1` (hidden desktop)

Command (PowerShell, repository root):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\374-wsl-drive-item\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\374-wsl-drive-item\probe\wsl374_probe.ps1 -Exe <exe> -Label <label>"
```

- First run (after): 9 PASS / 4 FAIL - all probe faults, the program was right (the kept dumps
  showed `Linux - alpha | Linux - R&&D | Linux - Zeta`): a one-element array returned from a
  PowerShell function unrolls (`@(...)` added); the configuration shows the drive bar already, so
  `CM_TOGGLEDRIVEBAR` hid it (now toggled only when no bar build was dumped).
- Negative control: `main` at `30268b7c` built in a worktree with its own build folder
  (`%TEMP%\tc374negbuild`). First before run: 9 FAIL / 4 PASS, but TIME and OPT-OFF passed
  vacuously (no `WSL` lines at all) - a negative control that does not fail is a finding: both rows
  now require the `WSL` line in every build.
- **Before** (`result_before.txt`, `30268b7c`): PASS 2, FAIL 11 - REAL-MENU, REAL-BAR, SAVED,
  OPT-OFF, TIME, FAKE-MIX, FAKE-ONE, FAKE-NONE, OPEN-MENU, FOCUS, OPEN-BAR fail; REGRESS and NO-VM
  pass (regression controls, they must pass on both builds).
- **After** (`result_after.txt`): PASS 13, FAIL 0, NOT DRIVEN 0; registry restored, SHA-256
  identical; the fake key removed; Ubuntu (not running before) terminated again.
- Timing (SC-004): the WSL part of the Alt+F1 list build 732-1038 us (median 921 us); the whole build
  with the option on vs off: medians 11318 / 10672 us (+0.6 ms). No distribution was started by the
  builds (NO-VM).
- Not driven on the hidden desktop: the look of the penguin icon in the menu and on the bar, a real
  mouse click on the drop-down button, and ticking the new check box on the configuration page
  (a real mouse / keyboard) - owed to a person.

## Translations (stop-rules 2.13, module `salamand`)

- Entries (step 0): new STRINGTABLE 14169 `IDS_WSLLINUX` "Linux"; new DIALOG control 6290
  `IDC_CHD_SHOWWSL` "&Linux Distributions (WSL)" on IDD_CFGPAGE_CHANGEDRIVE (1085); the group box
  1154 and the controls 619, 610, 1155-1157, 1088, 1089 moved (geometry only). No English text of an
  existing id changed -> no `english_fallback` (step 2).
- `src\vcxproj\build_langs.cmd --export-templates --module salamand` -> 1/1.
- Dry run: 2 unique gaps, ~31 chars in each of the 8 languages. Real merge `--budget 2496`
  (2 x 248 + 2000): DeepL characters sent 240; validation failures 0.
- Read back (all 8): "Linux" unchanged; the check box: cs "&Linuxové distribuce (WSL)", de
  "&Linux-Distributionen (WSL)", fr "Distributions &Linux (WSL)", nl "&Linux-distributies (WSL)", hu
  "&Linux-disztribúciók (WSL)", ro "Distribuții &Linux (WSL)", sk "Distribúcie &Linuxu (WSL)", es
  "Distribuciones de &Linux (WSL)" - no register issue (no pronoun), accelerator L unique on the
  page in every language (checked per DIALOG 1085). No pins.
- Layout drift: none outside DIALOG 1085 (`git diff`: 10 + / 8 - lines per `.slt`, only that dialog
  and the new string).
- `python -m translate.slt --verify` -> `round-trip byte-exact for every file` (298 files).
- `.\build.cmd full` -> BUILD SUCCEEDED.
