# Quickstart — validating 077 fix-antivirus-findings

Every scenario is run **at least twice** (the maintainer's instruction);
"twice" means two independent runs whose outputs are both recorded in
`fix-log.md`, not one run read twice. Commands are for the repository root
unless stated. Paths use this machine's layout
(`OPENSAL_BUILD_DIR` unset → `build\`).

Prerequisites: VS 2022 Community with the C++ workload and the "C++ 2022
Redistributable Update" component (`VC\Redist\MSVC\14.40.33807` present),
Windows SDK (`signtool.exe`, `cdb.exe` in `Debuggers\x64`), Python 3.x on
PATH, Inno Setup 7, SimplySign Desktop running for signing scenarios.
Run `build_setup.cmd sign` and the sweep **from cmd/Git Bash with the default
`PSModulePath`** (a pwsh 7 module path breaks Windows PowerShell 5.1's
`Get-AuthenticodeSignature`).

---

## S1 — Release build ships the runtime (User Story 1, FR-001…FR-004)

```
build.cmd full release
dir build\tandemcommander\Release_x64\*.dll
python tools\check_runtime_deps.py build\tandemcommander\Release_x64 --list
```

Expected: `BUILD SUCCEEDED`; build log contains
`Visual C++ runtime 14.40.33807: 4 file(s) copied from …Microsoft.VC143.CRT`
and `runtime closure OK: 25 module(s) scanned …`; the tree root holds
`vcruntime140.dll vcruntime140_1.dll msvcp140.dll concrt140.dll`, each with
`Get-AuthenticodeSignature` = Valid, signer `O=Microsoft Corporation`;
`--list` shows `CONCRT140.dll` only for `tandemcommander.exe`, `MSVCP140.dll`
for `7zip.spl codeview.spl filecomp.spl mdview.spl`.
Second run: an incremental `build.cmd release` (no `full`) must re-copy the
files after they were deleted from the tree by hand.

## S2 — Build fails loudly without the runtime (FR-003, SC-005)

```
python tools\check_runtime_deps.py <scratch copy of the tree with msvcp140.dll deleted>
```

Expected: exit 1, lines `plugins\7zip\7zip.spl needs MSVCP140.dll (not shipped)`
(and codeview, filecomp, mdview), final `runtime closure FAILED: 4 …`.
Second run: delete `vcruntime140.dll` instead → 25 violations. Also once:
simulate a missing redistributable directory by running the copy step with
`VS_INSTALL` pointed at an empty scratch folder (or by temporarily renaming
the version file in a **copy** — never the real VS installation) → the build
stops with `ERROR: Visual C++ runtime not found: …`.

## S3 — The running program loads the runtime from its own folder (R7 evidence 2)

```
powershell -NoProfile -ExecutionPolicy Bypass -File specs\077-fix-antivirus-findings\probe\check_loaded_crt.ps1 -Exe build\tandemcommander\Release_x64\tandemcommander.exe
```

Expected: the probe starts the program, waits for the main window, lists
the process modules and prints for each of the four runtime names the path
it was loaded from — all four under `build\tandemcommander\Release_x64\`,
none under `C:\Windows\System32\`; then closes the program (WM_CLOSE) and
exits 0. Run twice.

## S4 — Import table no longer advertises the patch (FR-010, SC-002)

```
"<VS>\VC\Tools\MSVC\14.40.33807\bin\Hostx64\x64\dumpbin.exe" /imports build\tandemcommander\Release_x64\tandemcommander.exe | findstr /i "WriteProcessMemory VirtualProtect"
```

Expected: no output (before the change: two lines). Run once on the first
build and once on a `build.cmd rebuild release` (full clean) — two
independent binaries.

## S5 — Crash reporting parity (FR-011, SC-003)

```
powershell -NoProfile -ExecutionPolicy Bypass -File specs\077-fix-antivirus-findings\probe\crash_inject.ps1 -Exe build\tandemcommander\Release_x64\tandemcommander.exe -Target app
powershell -NoProfile -ExecutionPolicy Bypass -File specs\077-fix-antivirus-findings\probe\crash_inject.ps1 -Exe build\tandemcommander\Release_x64\tandemcommander.exe -Target plugin
```

The probe starts the program, attaches `cdb`, sets the main thread's
instruction pointer to `0` (`-Target app`) or to the image base of a loaded
plugin module (`-Target plugin`, header page → access violation inside the
plugin's range), detaches, and then waits up to 60 s for a new
`NC0.1.7*.txt` + `.dmp` pair under `%LOCALAPPDATA%\Tandem Commander\`; it
closes the Bug Reporter dialog and reports the report file names, the
faulting address recorded in the text report and whether it lies inside the
plugin module.

Expected: **baseline** (build from `main`, before the change): one run per
target succeeds — proves the harness. **After the change**: two runs per
target succeed; the `plugin` variant's report names the plugin module.

## S6 — Signing sweep keeps Microsoft's signature (User Story 3, FR-007/008)

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\codesign\sign_release.ps1 -Root build\tandemcommander\Release_x64
powershell -NoProfile -ExecutionPolicy Bypass -File tools\codesign\sign_release.ps1 -Root build\tandemcommander\Release_x64 -VerifyOnly
```

Expected, first run: `Signed: 216  Skipped: 0  Exempt (Microsoft): 4  Failed: 0  (of 220)`,
`Verified : 220 of 220`, exit 0; the four runtime files still report signer
`O=Microsoft Corporation`. Second run (idempotence): `Signed: 0  Skipped: 216
Exempt (Microsoft): 4`, exit 0; `-VerifyOnly` exit 0 both times.

## S7 — Tampered runtime file is refused (FR-007 negative)

```
powershell -NoProfile -ExecutionPolicy Bypass -File specs\077-fix-antivirus-findings\probe\sign_exempt_negative.ps1 -Tree build\tandemcommander\Release_x64
```

The probe copies the tree to the scratchpad, strips the certificate table
of `concrt140.dll` in the copy, runs the sweep (and `-VerifyOnly`) on the
copy. Expected: exit 1, `ERROR: runtime file is not validly signed by
Microsoft: …\concrt140.dll`, and **no** file in the copy was signed
(timestamps unchanged). Run twice (second time tampering `vcruntime140.dll`).

## S8 — Packaging: the installer carries and removes the runtime (FR-005)

Before the first packaging build: move
`setup\output\tandemcommander-0.1.7-x64-setup.exe` (the archived published
file, SHA-256 `6731E146…F64DD`) to the scratchpad; restore it at the end.

```
setup\build_setup.cmd sign
setup\output\tandemcommander-0.1.7-x64-setup.exe /VERYSILENT /CURRENTUSER /DIR=<scratch>\tc-inst /NOICONS /SUPPRESSMSGBOXES /NORESTART /LOG=<scratch>\inst.log
dir <scratch>\tc-inst\*.dll
<scratch>\tc-inst\unins000.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

Expected: install exit 0; the four runtime files present in `<scratch>\tc-inst`
with Microsoft signatures; `tandemcommander.exe` there signed by the project
certificate; uninstall exit 0 and the folder gone (including the DLLs); the
`HKCU\…\Uninstall\{35C0B0DC-…}_is1` key created and removed. Run the
install/uninstall pair twice. If a machine-wide Tandem Commander installation
exists on this PC, the per-user scratch install must leave it untouched (check
its folder timestamps before/after).

## S9 — Nothing else changed (FR-013, SC-006)

```
build.cmd
build\tandemcommander\Debug_x64\saltests\saltests.exe
```

Expected: Debug build succeeds (no runtime copy step for Debug); saltests
prints the same totals as at baseline (1353 checks, 0 failures). Run twice.
Also compare the Release tree file list before/after: the only additions are
the four runtime files.

## S10 — Sanity: local antivirus verdict

```
"C:\ProgramData\Microsoft\Windows Defender\Platform\<latest>\MpCmdRun.exe" -Scan -ScanType 3 -File build\tandemcommander\Release_x64 -DisableRemediation
```

Expected: `found no threats` on the tree and on the signed installer. Once
per built artefact.

---

## Owed human step (cannot be done from this session — R7)

**Clean-machine start** (User Story 1, acceptance scenario 1): on a Windows
10/11 VM or Windows Sandbox that has **no** "Microsoft Visual C++ 2015-2022
Redistributable (x64)" entry in *Installed apps*, run the signed installer,
launch Tandem Commander from the final page, confirm the main window opens
and *Plugins → Plugins Manager* lists all 20 plugins. Record the Windows
build, the absence of the redistributable entry and the result in
`fix-log.md`. Windows Sandbox needs the optional feature
`Containers-DisposableClientVM` (admin + reboot on this PC).
