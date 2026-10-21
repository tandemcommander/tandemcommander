# Research - 292 Registry Editor: Copy / Move onto itself through another root name

## R1 - What identifies a registry key

- **Decision**: the full internal name the registry reports for an opened key handle
  (`NtQueryKey(handle, KeyNameInformation)`), e.g. `\REGISTRY\USER\<SID>\Software\X`.
- **Rationale**: measured at 9781daee (PowerShell P/Invoke): `HKCU\Software` and
  `HKEY_USERS\<SID>\Software` give the same name; `HKEY_CURRENT_CONFIG\Software` gives
  `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Hardware Profiles\0001\Software` (registry links are
  followed, so `CurrentControlSet` / `ControlSet001` agree too); letter case follows the stored key,
  not the typed path (`sOFTWARE` gives `Software`). One rule covers every alias without a list.
- **Alternatives considered**: a textual alias table (`HKCU` = `HKU\<SID>`, `HKCC` = ...): misses
  registry links and any future alias, and needs the SID - rejected. Comparing last-write time /
  class / value lists: not an identity - rejected.
- `NtQueryKey` is reached with `GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryKey")`
  (no import library change; ntdll is always loaded). Its status is turned into a Win32 error with
  `RtlNtStatusToDosError` (same way) for the existing error box.

## R2 - The roots themselves

- **Finding**: `RegOpenKeyExW(root, L"", ...)` returns the predefined handle itself; `NtQueryKey`
  on it fails (`STATUS_INVALID_HANDLE`, measured for HKCU, HKCR, HKCC, HKLM, HKU).
- **Decision**: fixed rule per root: `HKEY_LOCAL_MACHINE` = `\REGISTRY\MACHINE`,
  `HKEY_USERS` = `\REGISTRY\USER` (constants of the registry's namespace); `HKEY_CURRENT_USER` =
  the name of `RegOpenCurrentUser(KEY_READ)`; `HKEY_CURRENT_CONFIG` = the name of
  `HKLM\SYSTEM\CurrentControlSet\Hardware Profiles\Current` opened; `HKEY_CLASSES_ROOT` = R3;
  any other root (`HKEY_DYN_DATA`, absent on NT) = unknown (fails closed).

## R3 - HKEY_CLASSES_ROOT (merged view)

- **Finding**: `HKCR\.txt` opened gives `\REGISTRY\USER\<SID>_Classes\.txt` (the user's half);
  `HKCU\Software\Classes` gives `\REGISTRY\USER\<SID>_Classes`. Which half a path under HKCR reaches
  depends on which half holds it; new keys may be created in either.
- **Decision**: a path `HKCR\<rest>` has the identities `<machine classes>\<rest>`,
  `<user classes>\<rest>` (the names of `HKLM\Software\Classes` and `HKCU\Software\Classes`
  opened) and, when it exists, the name of the opened key. The operation is refused when any of
  them matches. Conservative (spec Clarifications): a rare operation between the merged view and
  the half it does not reach may be refused.

## R4 - Where the checks sit (fs5.cpp `CPluginFSInterface::CopyOrMoveFromFS`)

Consumers enumerated (Grep `CopyOrMoveKey(`, `CopyOrMoveValue(`, `SafeDeleteKey`):

| Caller | Route | Concerned |
|---|---|---|
| `CopyOrMoveFromFS` (fs5.cpp) | F5 / F6, drag and drop between Registry Editor panels (mode 5) | yes - both checks |
| `CopyOrMoveKey` recursion (fs5.cpp) | subkeys of one operation | no - fed by the caller |
| `QuickRename` (fs3.cpp) | F2 inside one key, one root (`CurrentKeyRoot` both sides) and the target must not exist (`TestKey`) | no |

1. **Folder check** (today `root == CurrentKeyRoot && key == CurrentKeyName`): kept as is, and
   when it says "different" the identities of the panel's key and of the target folder (which
   exists at that point - it was opened or just created) are compared; equal = the same block runs
   (refusal 1053 / 1066, or a rename to another name).
2. **Key check** (today "sourceKey is a prefix of targetKey" under one root): kept, and in addition
   the identities of the target key (target folder identities + the new name; plus the opened
   target key when it exists) are tested to be equal to / inside the identities of the source key
   (the opened source key; plus source folder identities + its name). Inside = the existing
   1065 / 1067 box.
- **Fail closed**: an identity that cannot be established (open error other than "not found" for
  the target key, a query error, a name too long for the buffer) stops: folder level = the existing
  `ErrorL(..., IDS_ACCESS, ...)` and back to the dialog (as the target-path checks above it do); key
  level = the existing `RegOperationError(..., IDS_OPEN, ...)` box with Retry / Skip / Skip All /
  Cancel. No new string.

## R5 - The pure rule

- **Decision**: `src/common/salregkeyid.h`, header-only (the plug-in cannot compile a `.cpp`
  from `src/common`): `SalRegKeyIdSame`, `SalRegKeyIdWithin` (case ignored with
  `CompareStringOrdinal(..., TRUE)` - the registry compares names case-insensitively by upper-casing
  each unit; whole path element), a fixed-size identity set `CSalRegKeyIds` with `SalRegKeyIdsAdd`
  (parent + `\` + name, refused when it does not fit - never cut) and the "any pair" tests.
  Checked by `saltests` (`TestRegKeyId292`).
- Buffer: `SAL_REGKEYID_MAX` = 1280 units: a Registry Editor key path is at most `MAX_KEYNAME`
  (512) units, a new name at most 512 more, the internal prefix under 100.
