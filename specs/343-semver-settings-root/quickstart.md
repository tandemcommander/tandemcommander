# Quickstart: validating 343

Build dir `<build>` = `$env:OPENSAL_BUILD_DIR` if set, otherwise `build`.

## 1. Automated checks

```powershell
build.cmd                                   # Debug x64
<build>\tandemcommander\Debug_x64\saltests.exe   # 0 failed; new groups: cfg-migrate decision, legacy root map, bug report name with dots
python -m pytest tools\release\test_release.py   # version-step, patch-kind, 0.2.0 accepted
python tools\check_encoding.py --strict     # TOTAL: 0
python tools\test_bin_help.py
```

## 2. Migration probe (hidden desktop)

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\343-semver-settings-root\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\343-semver-settings-root\probe\cfgroot343_probe.ps1 -Exe <build>\tandemcommander\Debug_x64\tandemcommander.exe"
```

The probe backs up `Settings`, `Settings.*`, `0.1`, `0.1.*` (export + hash), seeds `0.1` from a
fixture written by the pre-change build plus values of every registry type and non-ASCII names,
and checks the rows:

| Row | Expect |
|---|---|
| MIG-BASIC | after one start `Settings` equals `0.1` value by value; `0.1` unchanged (hash); no dialog window |
| MIG-AGAIN | a second start changes nothing in `0.1`; a setting changed in the program lands only in `Settings` |
| MIG-BOTH | `Settings` and `0.1` both present → `Settings` untouched by the start (no copy) |
| MIG-FRESH | neither present → only `Settings` created, `0.1` not created |
| MIG-KILL | `TC_CFGMIGRATE_FAIL_AT=kill-after-copy` → process ends, side key left, no `Settings`; next start completes; `0.1` unchanged |
| MIG-FAIL-COPY / -COMPARE / -RENAME | the seam → message window shown, no `Settings`, no side key, `0.1` unchanged; a change made in that session is saved into `0.1`; the next start (no seam) migrates |
| MIG-CORRUPT-BACKUP | `0.1` with `Save In Progress` + valid `0.1.backup.63A7CD13` → the program starts with the backup's settings, `Settings.corrupted.63A7CD13` holds the damaged copy |
| MIG-PWD | `Password Manager` subkey identical; the Master Password verifier unchanged |
| IMP-LEGACY | importing a 0.1.x export (menu command driven through `-C` start-up import) → its values under `Settings` |
| IMP-FOREIGN | a file with `HKEY_CURRENT_USER\Software\Other` → refused, nothing written |

Restore: every backed-up key back, hashes compared; the probe fails if a hash differs.

## 3. Release tool dry runs (on the feature branch, nothing written)

```powershell
python tools\release\release.py status 0.2.0     # accepted (no line-change)
python tools\release\release.py status 0.1.11    # accepted
python tools\release\release.py status 0.3.0     # version-step warning
```

## 4. Search

```powershell
git grep -n -e "Tandem Commander\\0.1" -e "Tandem Commander\\\\0.1" -- . ":!specs/0*" ":!specs/1*" ":!specs/2*" ":!specs/30*" ":!specs/31*" ":!specs/32*" ":!specs/33*" ":!specs/34[0-2]*" ":!release_notes" ":!temp"
```

Every remaining hit is a deliberate reference to the old key (migration code and its tests,
`PRIVACY.md`, changelog history, this feature's documents).
