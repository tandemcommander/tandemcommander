# Research - feature 380

All measured at 823f2873.

## R1 - GetFullFSPath

- Decision: test the conversion's result (`== 0` → `Error(IDS_LONGNAME)`, `success = FALSE`); a failed
  `U8ToWStr` of the typed path → the same message and `success = FALSE`.
- Rationale: the only caller (`src/fileswn3.cpp`, Change Directory / command line, relative path on a
  plug-in FS) passes `char absFSPath[MAX_PATH]` and starts with `success = TRUE`; returning TRUE with
  `success` unchanged makes it use the buffer as the full path. `WideCharToMultiByte(CP_UTF8)` fills
  the buffer before failing with error 122 (measured with Python ctypes: 260 of 260 bytes written,
  the helper's terminator leaves 259 bytes ending in a lone lead byte). Probe: LONG and CJK rows FAIL
  at HEAD.
- Alternatives: a heap buffer - impossible, the buffer is the caller's (`pathSize`); enlarging the
  core's buffer is a core change affecting every file-system plug-in → a separate backlog item.

## R2 - QuickRename focus name

- Decision: `if (WStrToU8(newName, MAX_PATH, keyName) == 0) newName[0] = 0;`
- Rationale: the core (`fileswn5.cpp`, `char newName[MAX_PATH]`) only copies it into
  `NextFocusName`; the rename is already done. `CreateDir` of the same file already empties the name on
  failure. A key name may hold 255 characters, a value name `MAX_KEYNAME` - 1 = 511 (the plug-in's
  limit): up to ~1,500 bytes of UTF-8.
- Alternatives: refuse the rename before doing it - takes a working rename away; rejected (spec,
  Clarifications).

## R3 - Rename by Move (`fs5.cpp`, `nextFocus`)

- Decision: as R2 (`char nextFocus[2 * MAX_PATH]`, copied into `targetPath` at success; empty → the
  core focuses nothing new).

## R4 - Find window Focus (`finddlg2.cpp`)

- Decision: both conversions checked; failure → `Error(IDS_LONGNAME)` and no `PostFocusCommand`.
- Rationale: buffers are `3 * MAX_FULL_KEYNAME + 1` and `3 * MAX_KEYNAME` bytes for wide texts of at
  most `MAX_FULL_KEYNAME` / `MAX_KEYNAME` - cannot fail today; the check keeps it so if a limit changes.

## R5 - The other `WStrToU8` calls (inventory by grep, 30 calls)

Checked already (`<= 0` / `> 0` / `!`): `fs.cpp` 114, 437; `fs2.cpp` 72, 91, 97, 357; `fs3.cpp` 310,
1173; `utils.cpp` 82; `dialogs.cpp` 787 (uses the count). Unchecked but cannot fail (destination three
times the wide maximum, or ASCII predefined key names): `fs3.cpp` 223-224, `fs5.cpp` 169-180, 509,
1479, `finddlg.cpp` 1411, `utils.cpp` 147-149, `fs4.cpp` 42/129 (date/time, checked via `- 1`).
Unchecked and reaching the panel: R1-R4 (`fs2.cpp` 216, `fs3.cpp` 195, `fs5.cpp` 1435,
`finddlg2.cpp` 952-953). The helper itself stays as it is: changing its failure output for 30 callers
is wider than the item and the display callers cannot fail.
