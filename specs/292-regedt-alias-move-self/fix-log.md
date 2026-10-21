# Fix log - 292 Registry Editor: Copy / Move of a key onto itself through another root name

Backlog item `registry-editor-move-of-a-key-onto-itself-through-hkey-users` (source review:287).

## Measured before (main at 9781daee, Debug x64)

1. `NtQueryKey(KeyNameInformation)` from PowerShell (P/Invoke, KEY_READ):
   - `HKCU\Software` and `HKU\<SID>\Software` -> `\REGISTRY\USER\S-1-5-21-...-1001\Software`
   - `HKCU\sOFTWARE` -> `...\Software` (the stored case)
   - `HKCR\.txt` -> `\REGISTRY\USER\<SID>_Classes\.txt`; `HKCR\CLSID` -> `...<SID>_Classes\CLSID`
   - `HKCU\Software\Classes` and `HKU\<SID>_Classes` -> `\REGISTRY\USER\<SID>_Classes`
   - `HKCC\Software` -> `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Hardware Profiles\0001\Software`
   - any root with an empty subkey (HKCU, HKCR, HKCC, HKLM, HKU) -> status `C0000008`
     (`RegOpenKeyExW` hands back the predefined handle itself); `sam` 0 -> open error 5.
2. New probe `probe/alias292_probe.ps1` (fixture under `HKCU\Software\TcProbe292` and
   `HKCU\Software\Classes\TcProbe292`; helpers of 098, structure of 287):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\292-regedt-alias-move-self\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\292-regedt-alias-move-self\probe\alias292_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile specs\292-regedt-alias-move-self\probe\alias292_before.txt"
   ```

   Result: **18 PASS / 9 FAIL**, registry restored identical (SHA-256 34FA77DB...125A).
   - ALIASMOVE: overwrite question "Overwrite HKEY_USERS\<SID>\...\<K>\v with HKEY_CURRENT_USER\...\<K>\v",
     All -> `Zdroj\<K>` and its subkey **gone** (TEXT FAIL, STATE FAIL)
   - ALIASCOPY: overwrite question instead of 1053 (TEXT FAIL); data unchanged (STATE PASS)
   - ALIASINTO: no 1067; the key copied into itself ~16 levels deep, then "Unable to open a
     registry key. (87)" (TEXT FAIL, STATE FAIL)
   - ALIASVALUE: overwrite question, All -> value `v` **gone** (FAIL, FAIL)
   - HKCRMOVE: overwrite question, All -> `Classes\TcProbe292\Zdroj\<K>` **gone** (FAIL, FAIL)
   - ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE: PASS (controls)
   - every END row PASS (exit 0, no report)

## Consumers (enumerated with Grep)

- `CopyOrMoveKey(` - called from `CopyOrMoveFromFS` (fs5.cpp) and from itself (subkeys).
- `CopyOrMoveValue(` - `CopyOrMoveFromFS` (fs5.cpp) and `QuickRename` (fs3.cpp).
- `SafeDeleteKey` - only `CopyOrMoveKey`.
- `CopyOrMoveFromFS` - the plug-in interface entry for F5 / F6 and drag and drop (mode 5) between
  Registry Editor panels.
- `QuickRename` (fs3.cpp): one root, one key (`CurrentKeyRoot` both sides), the target must not
  exist (`TestKey`) - cannot meet an alias; unchanged.

## Decisions

- Identity = the reported internal name (research R1); roots by a fixed rule (R2); HKCR = both
  halves + the opened key, any match refuses (R3, conservative, spec Clarifications).
- Both existing checks are kept and get an "or by identity" (R4); no message added.
- An identity that cannot be established fails closed through the existing boxes (R4).

## Analyze

Two passes: 0 CRITICAL, 0 HIGH. C1 (MEDIUM, root-inside-source edge case not tested) fixed in T003.
C2 (LOW, FR-008 has no own task) - covered by the incremental build (no `.slt` gap) and this log.
U1 (LOW, drag and drop not driven) - an assumption of the spec; the same function serves it.

## Implementation

- `src/common/salregkeyid.h` (new, header-only): `SalRegKeyIdSame`, `SalRegKeyIdWithin`,
  `CSalRegKeyIds` (6 identities of 1280 units), `SalRegKeyIdsAdd` (refuses, never cuts),
  `SalRegKeyIdsAnySame`, `SalRegKeyIdsAnyWithin`.
- `src/plugins/regedt/fs5.cpp`: `AddOpenedRegKeyId` (NtQueryKey KeyNameInformation via
  GetProcAddress; overflow -> ERROR_FILENAME_EXCED_RANGE; other status -> RtlNtStatusToDosError),
  `AddRegKeyIdOf`, `AddRegRootIds` (HKLM / HKU constants, HKCU = RegOpenCurrentUser, HKCC = the
  opened `Hardware Profiles\Current`, HKCR = both class keys, others fail), `GetRegKeyIds` (HKCR:
  both halves joined with the path + the opened key), `SafeGetRegKeyIds` (existing open-error box),
  `AddRegKeyIdsJoined`.
  `CopyOrMoveFromFS`: (1) after the target folder exists, the identity sets of the panel's key and
  of the target folder; an error -> `ErrorL(..., IDS_ACCESS, ...)` and back to the dialog; the
  "onto itself" block runs when the text test OR `SalRegKeyIdsAnySame`. (2) for each key: the text
  "prefix" test OR `SalRegKeyIdsAnyWithin(target, source)` (target = target folder ids + new name +
  the opened target key if it exists; source = the opened source key + panel folder ids + name);
  an identity error -> the `RegOperationError(IDS_OPEN)` box (Skip leaves the key, Cancel stops);
  too long -> `IDS_LONGNAME`, stop.
- `src/plugins/regedt/precomp.h` includes the header; `src/saltests/saltests.cpp`
  `TestRegKeyId292`.
- No UI string added or removed; no `spl_*.h` change.

## Checks after

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (and `.\build.cmd rebuild`) | `BUILD SUCCEEDED`; warnings only the pre-existing C4267 of `regedt\fs2.cpp` (untouched) and others outside the feature |
| saltests | `saltests.exe` | `saltests: 25322 checks, 0 failed` |
| saltests negative control | `SalRegKeyIdWithin` boundary replaced by `return TRUE`, rebuilt | `25322 checks, 1 failed` (the "Key2" not inside "Key" check); restored, rebuilt, 0 failed |
| probe after (English) | `alias292_probe.ps1` -> `result_after.txt` / `alias292_after.txt` | **27 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (34FA77DB...125A) |
| probe after (Czech) | `-Lang czech` -> `result_after_czech.txt` / `alias292_after_czech.txt` | **27 PASS / 0 FAIL**, registry restored identical |
| probe before (negative control) | `-Expect before` on main 9781daee | 18 PASS / 9 FAIL (above) |
| clang-format | VS LLVM `clang-format --lines` on the new code | clean (`saltests.cpp` as a whole is not clean on main either: 1731 lines) |

Not driven: drag and drop between two Registry Editor panels (mode 5) - it reaches the same
`CopyOrMoveFromFS` after the dialog; the root-inside-source case (`HKEY_USERS\<SID>` into
`HKEY_CURRENT_USER\`) - a build without the fix would copy the user's whole hive; it is modelled in
`TestRegKeyId292`, and the sources of the root rule were measured in PowerShell (P/Invoke,
KEY_READ): `RegOpenCurrentUser` -> `\REGISTRY\USER\S-1-5-21-...-1001`;
`HKLM\SYSTEM\CurrentControlSet\Hardware Profiles\Current` -> `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Hardware Profiles\0001`;
`HKLM\Software\Classes` -> `\REGISTRY\MACHINE\SOFTWARE\Classes`.
