# Fix log - 390 Registry Editor: Move from HKCR into the user's Classes key does nothing

Backlog item `registry-editor-move-from-hkcr-to-user-classes-does-nothing` (source review:292 NOTE 4).

## Measurement before (main at 129136b4)

Build: `.\build.cmd` (Debug x64, BUILD SUCCEEDED). Probe (new, `probe/hkcr390_probe.ps1`), hidden
desktop, not elevated:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\390-regedt-hkcr-move-user\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\390-regedt-hkcr-move-user\probe\hkcr390_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\390-regedt-hkcr-move-user\probe\hkcr390_before.txt"
```

Machine-only key picked: `HKEY_CLASSES_ROOT\.386` (`(default)` = vxdfile, `PerceivedType` = system,
subkey `PersistentHandler`), only read.

| Row | Result |
|---|---|
| MACHUSER (F6 into `\HKEY_CURRENT_USER\Software\Classes\`) | FAIL: boxes none; the user's half of `.386` missing afterwards; the machine's half unchanged - the silent no-op |
| MACHUSERU (F6 into `\HKEY_USERS\<SID>_Classes\`) | FAIL: the same |
| USERMOVE (control) | PASS |
| USERHKCR (control) | FAIL - the control was wrong: a new subkey created through `\HKEY_CLASSES_ROOT\TcProbe390\Cil\` (parent only in the user's half) goes to the machine's half: "Unable to create a registry key. (5)". Windows behaviour, not this item (research R6); replaced by USERCLS |

Rows: PASS 5, FAIL 5; registry restored identical; no user copy of `.386` left.

The defect is reachable from a user action (F6 / drag and drop) with the default configuration
(`regedt` is `on` in `plugins.cfg`): `CopyOrMoveFromFS` -> `CopyOrMoveKey` -> `CopyOrMoveKeyRec` ->
`SafeDeleteKey(sourceRoot = HKCR, ...)` = `RegDeleteKeyW(HKEY_CLASSES_ROOT, path)`.

Callers of `CopyOrMoveKey` (enumerated with Grep): `CopyOrMoveFromFS` (`fs5.cpp`; F5 / F6, drag and
drop) and Quick Rename of a key (`fs3.cpp`, a Move within the same root and parent). `SafeDeleteKey`:
only `CopyOrMoveKeyRec` (the Move's source). For Quick Rename inside HKCR the change keeps the result:
the renamed key is created at another name, so the source path never gains a half - the single half
deleted by its real path is exactly what the delete through HKCR reached.

## Analyze findings accepted (LOW)

- C2: the fail-closed open-error path of reading the halves cannot be provoked without also failing
  the copy's own open - NOT DRIVEN, by reading.
- C3: keys held by both halves keep the old delete; checked by the `saltests` rule only (a probe
  would need a key in the machine's half).
- I1: the delete box names the HKCR source when the real name would not fit `MAX_KEYNAME` (spec edge
  case) - consistent.

## The change

- `src/common/salregkeyid.h`: `SalRegHkcrDeleteHalf(machineHeld, userHeld)` (one half = that half,
  both / none = through HKCR as before) and `SalRegJoinClassesPath` (`Software\Classes\` + key,
  refused when it does not fit, never cut).
- `src/plugins/regedt/fs5.cpp` `CopyOrMoveKeyRec`: for a Move whose source root is HKCR, after 297's
  link check and before anything of the key is opened or written, `GetHkcrHalves` opens
  `HKLM` / `HKCU` `Software\Classes\<path>` (`KEY_ENUMERATE_SUB_KEYS`; not found = not held; any
  other error = the existing open-error box, nothing of the key copied - fails closed); at the end
  `SafeDeleteHkcrHalf` deletes the one half by its real path with the existing `IDS_REMOVESOURCE`
  box (Retry / Skip / Skip All / Cancel) naming `HKEY_LOCAL_MACHINE\Software\Classes\...` (the HKCR
  name when the real one would not fit `MAX_KEYNAME`). Two halves: the old `SafeDeleteKey` through HKCR.
- No new UI string, no dialog change: no `.slt` refresh needed. No plug-in ABI change.

## Checks after the change

| Check | Result |
|---|---|
| `.\build.cmd` | BUILD SUCCEEDED (warnings only the old C4267 of `fs2.cpp`) |
| `saltests.exe` | `saltests: 30755 checks, 0 failed` (14 new checks in `TestRegHkcrHalf390`) |
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| probe `hkcr390_probe.ps1` English (`hkcr390_after.txt`) | **10 PASS / 0 FAIL / 0 NOT DRIVEN**: MACHUSER / MACHUSERU - first box "Unable to remove the original registry key. (5) Access denied" naming `HKEY_LOCAL_MACHINE\Software\Classes\.386\PersistentHandler`; the user's copy equals the machine key; the machine key unchanged. USERMOVE / USERCLS moved whole |
| the same, Czech (`hkcr390_after_czech.txt`) | 10 / 0 |
| 292 `alias292_probe.ps1` (`alias292_probe_on390.txt`) | 33 / 0 |
| 294 `above294_probe.ps1` | 24 / 0 |
| 296 `link296_probe.ps1` | 47 / 0 |
| 297 `link297_probe.ps1` | 40 / 0 |

Registry restored identical (001410973F32...20B4) after every run; no user copy of `.386` left.

Negative control: the build of 129136b4 (the delete through HKCR, which the new code still uses for
VIEW) is the "before" run above - MACHUSER / MACHUSERU FAIL with "boxes: none" and the user's copy
deleted again. (USERCLS was added after the before run; it was not run on the old build.)

## NOT DRIVEN (owed / by reading)

- The elevated Move (spec US1 scenario 2: the key ends in the user's half and is gone from the
  machine's) - the probe never runs elevated (it would delete a real machine key); a person step.
- The fail-closed open-error path of `GetHkcrHalves` - cannot be provoked without failing the copy's
  own open; by reading.
- Keys held by both halves keep the old delete - `saltests` rule only.
