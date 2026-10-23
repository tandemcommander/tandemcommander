# Fix log - 316-unpack-subdir-space

Backlog item `unpack-into-a-subfolder-named-after-an-archive-whose-name` (source review:315).

## Measurement at b125acf7 (main, before the feature)

Debug x64 build of b125acf7 (incremental `build.cmd`, up to date). Probe written for the
measurement (`probe/unpack316_probe.ps1`, 315's driver + 098's library), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\unpack316_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib ...\fix_probe_lib.ps1"
```

Result (`probe/result_before.txt`, first version of the probe, 5 FAIL / 9 PASS, registry restored
and identical):

- space-sd (UA=0 SD=1, ` ssss.zip`, `ssss` with keep.k next to it, item ` ssss`): files in
  `ssss` (merged next to keep.k) - FAIL
- space-sd-long (UA=1 SD=1, other panel 245 bytes, ` ` + 19 letters, the name alone offered):
  files in the 19-letter folder - FAIL
- space2-sd (`  ss.zip`): files in `ss` - FAIL
- typed-space (WM_SETTEXT ` typed`): files in `typed` - FAIL
- ctl-abs-space (UA=1 SD=1, short L, item `L\ ssss`): "Error Creating Directory" (123, invalid
  name), the dialog again, nothing unpacked - counted FAIL by the first probe (it expected files in
  `L\ ssss`); this is the existing create rule, see Decisions
- ctl-typed, ctl-blank: PASS

Reachability: Alt+F9 on an archive in a disk panel -> `CFilesWindow::Unpack` -> `CUnpackDialog`
-> OK -> `SalGetFullName(path, &errTextID, GetPath(), nextFocus)` (default
`allowRelPathWithSpaces = FALSE`) -> the relative branch joins `curDir` with the name from after
its leading spaces -> `CheckAndCreateDirectory` creates `ssss` -> `ExecuteUnpacker`.

## Decisions

- R1: pass `allowRelPathWithSpaces = TRUE` at the Unpack call (as `SalParsePath` does for Copy /
  Move targets); `SalGetFullName` itself unchanged (25+ callers, the plug-in service).
- R2: a folder starting with a space that does not exist is refused by the existing rule
  (`CheckAndCreateDirectory(..., manualCrDir = TRUE)` -> ERROR_INVALID_NAME, "Error Creating
  Directory", the dialog again) - the same as the absolute entry already gets; an existing folder
  is used. The item allows "or the program refuses with a message". No new string.
- Consumers after the call enumerated (research R3): `nextFocus` (already held the name with its
  spaces), `SalUnpackEmptyTarget` (spaces only still empty), drive / root-relative branches
  (unchanged), `CheckAndCreateDirectory`, `ExecuteUnpacker`, `PostChangeOnPathNotification`.

## speckit-analyze

No CRITICAL / HIGH. Accepted: U1 (the next focus not checked by the probe - read: `nextFocus` is
copied from `name` with its spaces before the join), U2 (`  \x`, `  C:\x` not driven - other
branches, untouched; a typed root path would leave the fixture), C1 (CHANGELOG / FEATURE-HISTORY
are written at closing).

## Probe updated to the spec (T002) and the negative control (T003)

The leading-space rows now expect the refusal (decision R2); rows space-sd-exists (an existing
folder ` ssss` receives the files) and space-file (a file ` ssss`: refused, untouched) added;
ctl-abs-space expects the refusal (before and after). The first run is kept as
`probe/result_before_v1.txt`.

Negative control - the updated probe on the unchanged build of b125acf7
(`probe/result_before.txt`): **6 FAIL / 12 PASS** (rows RUN + END). Every leading-space row
unpacked into the folder without the space - also space-sd-exists (` ssss` existed; the files
went into a new `ssss`) and space-file (a file ` ssss`; the files went into a new `ssss`). The 3
controls PASS.

## Change (T004)

`src/fileswn7.cpp` `CFilesWindow::Unpack`: `SalGetFullName(path, &errTextID, curDir, nextFocus,
NULL, MAX_PATH, TRUE)` - `allowRelPathWithSpaces = TRUE`; `nameBufSize` stays `MAX_PATH`, the size
of `path` (the former default).

## Checks after the change

- `.\build.cmd` (Debug x64): BUILD SUCCEEDED, exit 0.
- Probe (`probe/result_after.txt`): **18 PASS / 0 FAIL**; registry restored, SHA-256 identical.
  space-sd / space-sd-long / space2-sd / typed-space: "Error Creating Directory (123)", the dialog
  again, nothing unpacked, `ssss` with keep.k untouched; space-sd-exists: a.k / a.kp in ` ssss`
  next to keep.k; space-file: "Error Creating Directory (183)", the file untouched; controls PASS.
- 315's probe on the new build (`probe/regress_315.txt`): 22 PASS / 0 FAIL (11 rows RUN + END).
- `saltests.exe`: `saltests: 27440 checks, 0 failed` (no new pure rule - the change is one
  argument at a GUI call site).
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.

Not driven: the cursor's next focus after unpacking into ` ssss` (read: `nextFocus` is copied from
`name` with its spaces); typing with a real keyboard (the probe sets the entry with WM_SETTEXT -
the dialog reads the same text either way). No person step is owed: the change is verified on the
build.

## Out of scope (Inbox)

- `pack-with-a-relative-archive-name-that-starts-with-a-space` (measure:316): `CFilesWindow::Pack`
  calls `SalGetFullName` the same way - by code reading, not driven.
- `ChangePathToArchive` / `ChangePathToDisk` and other callers also trim a relative name; typed
  paths there are navigation, not a target written to - not recorded.

## Review

One independent refute-first review (general-purpose agent): **no MUST, no SHOULD**.

- Re-ran the probe on the branch build: 18 / 0, registry identical (matches `result_after.txt`).
- Own scratch probe outside the repository (fixture `%TEMP%\tc316r_unp`, registry restored and
  identical), listing every file of each row folder: typed `' ..'`, `' .'`, `' ..\x'`, a tab +
  `typed`, archives `' ...zip'` (offers `' ..'`) and `' ..zip'` (offers `' .'`) - all refused,
  nothing written anywhere (before the fix `' ..'` would have meant the archive's parent folder:
  `GetFullPathNameW` drops trailing dots); `' ssss\new'` with an existing `' ssss'` - unpacked
  into `' ssss\new'`.
- Read: only this caller changed; `nameBufSize` stays MAX_PATH = `path`; an entry that no longer
  fits with its spaces gets IDS_TOOLONGPATH (no cut); external unpackers get `$(TargetPath)` quoted.
- NOTEs, accepted: (1) the dialog's own offer ` ssss` is refused - the item's allowed outcome, the
  setting is off by default, the same as the absolute entry; (2) the probe checks only `src` / `tgt`
  - the reviewer's whole-row check found nothing outside; (3) next focus and real typing not driven
  (recorded above); (4) CHANGELOG / FEATURE-HISTORY - written at closing; (5) the Pack twin is in
  the Inbox, not measured.
