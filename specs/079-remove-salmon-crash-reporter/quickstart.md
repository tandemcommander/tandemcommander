# Quickstart: Validating feature 079

All commands run from the repository root unless stated. `OPENSAL_BUILD_DIR`
is `D:\Build\OpenSal\` on the reference machine; `<out>` below means
`%OPENSAL_BUILD_DIR%tandemcommander`.

## Prerequisites

- VS 2022 with the C++ workload, Windows SDK with the Debugging Tools
  (`C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe`).
- Python 3.13+; DeepL key in `temp\deepl_key.txt` (only for the translation
  refresh, §2).
- No other `tandemcommander.exe` running during §4–§5 (the probes refuse to
  start otherwise; §5 rewrites the user's registry key and restores it).

## 1. Build and unit tests (SC-005)

```bat
set OPENSAL_BUILD_DIR=D:\Build\OpenSal\
build.cmd full
<out>\Debug_x64\saltests\saltests.exe
build.cmd full release
```

Expected: both builds exit 0 (the Debug build runs `tools\check_encoding.py`
and imports all 8 `.slt`); `saltests: N checks, 0 failed` with N ≥ 1405 plus
the new `TestBugReport079` checks.

## 2. Translation refresh (FR-010, SC-006) — done once during implementation

```bat
build.cmd                                   :: the export reads the BUILT English module
src\vcxproj\build_langs.cmd --export-templates --module salamand
cd tools
python -m translate.merge --module salamand --templates D:\Build\OpenSal\tandemcommander\translator\templates
cd ..
build.cmd full
```

`translate.merge` ignores `OPENSAL_BUILD_DIR` (it defaults to the repo's
`build\` folder), hence `--templates`. Expected: the merge reports the two
new strings translated for 8 languages and 0 validation failures; the full
build imports every `salamand.slt`; the grep below returns nothing. Caveat
found in implementation: the matcher keys string-table rows by bundle
number, so a refresh that removes whole 16-id bundles re-translates every
later row — check the "unique gaps" count against the number of strings
actually added before accepting a merge:

```powershell
Select-String -Path translations\*\salamand.slt -Pattern 'salmon|Bug Reporter' -CaseSensitive:$false |
  Where-Object { $_.Path -notmatch 'chinesesimplified|russian|ukrainian' }
```

## 3. Shipped-tree checks (SC-001, FR-001, FR-013)

```powershell
Get-ChildItem <out>\Debug_x64, <out>\Release_x64 -Recurse -Filter 'salmon*'          # expected: nothing
Get-ChildItem <out>\Release_x64\utils                                               # sqlite.dll, salopen.exe, salextx64.dll … still there
python tools\check_runtime_deps.py <out>\Release_x64                                # expected: OK
powershell -File tools\codesign\sign_release.ps1 -Tree <out>\Release_x64 -WhatIf   # or: build.cmd full release sign
Select-String -Path src\vcxproj\salamand.sln, setup\tandemcommander.iss -Pattern salmon   # expected: nothing
```

(Check the exact `sign_release.ps1` parameters in its header before running;
the expectation is a file inventory without `utils\salmon.exe`.)

## 4. Crash probe (US2, SC-004)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File specs\079-remove-salmon-crash-reporter\probe\crash_inject.ps1 `
  -Exe <out>\Debug_x64\tandemcommander.exe -Target app    -Tag app1
powershell -NoProfile -ExecutionPolicy Bypass -File specs\079-remove-salmon-crash-reporter\probe\crash_inject.ps1 `
  -Exe <out>\Debug_x64\tandemcommander.exe -Target plugin -Tag plugin1
```

Repeat each three times (`-Tag app2`, … ). Expected per run:
`RESULT: OK`, with lines showing the report name, `execution address =
0x…` (0 for `app`, inside `zip.spl` for `plugin`), the message-box caption
`Tandem Commander 0.1.8 (x64)`, the message text containing the report path,
`exit code = 1`, and `salmon.exe processes: 0`. Also run once against the
Release build.

Manual variant of scenario 5 (report not writable): make
`%LOCALAPPDATA%\Tandem Commander` a read-only file instead of a folder,
inject a crash, expect the "could not be saved" message and exit code 1;
remove the file afterwards.

## 5. Start-up probe (US1, US3, SC-002, SC-003)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File specs\079-remove-salmon-crash-reporter\probe\startup_probe.ps1 `
  -Exe <out>\Debug_x64\tandemcommander.exe -StaleReports
powershell -NoProfile -ExecutionPolicy Bypass -File specs\079-remove-salmon-crash-reporter\probe\startup_probe.ps1 `
  -Exe <out>\Debug_x64\tandemcommander.exe -FreshRegistry
```

Expected: `RESULT: OK`; the log shows one product process, no dialog owned
by it (a first-run language chooser, if any, is logged and answered), main
window responding within 5 s, and for `-StaleReports` the three planted
files (`.TXT`, `.DMP`, `.7Z`) unchanged. `-FreshRegistry` prints the backup
`.reg` path and `registry restored: OK` at the end.

## 6. Task List Break (US2 scenario 6)

Manual: start two instances (Debug build), in the second open *Help > Task
List*, select the first, *Break*. Expected in the first instance: the closing
message with a report path; after OK it exits; the second instance keeps
running.

## 7. Repository grep (SC-007)

```powershell
git grep -i -l salmon -- . ':!specs' ':!CHANGELOG.md' ':!src/common/dep' ':!src/plugins/codeview/web' ':!temp' ':!.specify'
```

Expected: exactly three kinds of hit and nothing else — `CLAUDE.md` (the
feature-079 paragraph in *Recent Changes* records what was removed, like the
change log), `build.cmd` (its feature-079 cleanup stage must name the stale
file it deletes) and the three **disabled** languages'
`translations/<lang>/salamand.slt` (chinesesimplified, russian, ukrainian:
retained, not refreshed by policy since 046; they carry the removed strings
until they are re-enabled and refreshed). `git grep -n "Bug Reporter" -- src
tools help` prints nothing.
