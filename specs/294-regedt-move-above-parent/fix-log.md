# Fix log - 294-regedt-move-above-parent

Backlog item `registry-editor-move-of-a-key-into-the-key-above-its-parent` (source review:292).

## Measured at e752f9b9 (main, before the feature)

1. Sites (searched by name): `CPluginFSInterface::CopyOrMoveFromFS` and `CopyOrMoveKey` in
   `src/plugins/regedt/fs5.cpp`. The key check refuses `into` = target inside the source (text, and
   292's `SalRegKeyIdsAnyWithin(targetIds, sourceIds)`); nothing checks a target that holds the
   source. `CopyOrMoveKey(source -> target)` copies the values of the source into the target, then
   for each subkey name `N` recurses `source\N -> target\N`, and deletes the source at the end of a
   Move (`SafeDeleteKey`).
2. Reachable from F5 / F6 in a Registry Editor panel (default configuration; the plug-in is on in
   `plugins.cfg`), the target typed in the Copy / Move dialog; also drag and drop (same function).
3. New probe `probe/above294_probe.ps1` (style of 292's), Debug x64 build of e752f9b9
   (`build.cmd`, BUILD SUCCEEDED):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\294-regedt-move-above-parent\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\294-regedt-move-above-parent\probe\above294_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile specs\294-regedt-move-above-parent\probe\above294_before.txt"
   ```

   Result: **14 PASS / 10 FAIL**, registry restored identical (SHA-256 34FA77DB...125A).
   - ABOVEMOVE (F6 of `Zdroj\K\K` into `HKCU\...\Zdroj\`): no box; `Zdroj\K` = a=1;b=2; x=3 gone.
   - ABOVEALIAS (target `\HKEY_USERS\<SID>\...\Zdroj\`): the same loss.
   - ABOVEDEEP / ABOVEOK (F6 of `Hloub\K\M\K` holding `M\K` x=3 into `...\Hloub\`): x=3 gone.
   - ABOVECOPY (F5): no box; the source `Zdroj\K\K` now holds b=2;x=3 (written while read).
   - FLATTEN, FLATCOPY, MOVE, MOVESELF (controls): PASS.

## Decisions

- Refuse only when the copy would reach the source: source strictly inside the target (identity)
  and `source\R` exists, `R` = the source's path below the target (research R1). Refusing every
  target that holds the source would break the lossless merge FLATTEN (conservative answer).
- Check before anything is written (not a guard inside `CopyOrMoveKey`, which would stop half-way).
- Existing messages `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2`; no new string.
- Analyze: no CRITICAL / HIGH. Accepted: MEDIUM C1 - the fail-closed open-error path (FR-003) is
  not driven by the probe (an access-denied subkey would need an ACL change in the user's hive);
  LOW C2 - several selected keys not driven (the refusal uses the existing per-key box); LOW U1 -
  a registry link inside the source tree not driven (assumption in the spec).

## Implementation

1. `src/common/salregkeyid.h`: `SalRegKeyIdBelow(key, outer)` - the remainder of `key` after
   `outer` and its backslash when `key` lies strictly inside `outer` (case ignored, whole elements),
   else NULL.
2. `src/plugins/regedt/fs5.cpp`: `SafeRegKeyHoldsPath` opens `<source>\<remainder>` (heap-joined
   at full length, KEY_READ): found = refuse, not found = go on, other error = the existing
   `IDS_OPEN` box (Retry / Skip / Skip All / Cancel; the box names the joined path when it is
   shorter than `MAX_KEYNAME`, else the source key). In `CopyOrMoveFromFS`, after 292's identity
   test, for every pair of source / target identities with a remainder; a found chain sets `into`,
   so the existing "Name: <key> Error: Can't move/copy a key to itself." box (OK = skip, Cancel =
   stop) follows before `CopyOrMoveKey` writes anything.
3. `src/saltests/saltests.cpp`: `TestRegKeyIdBelow294` (18 checks).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `build.cmd` (Debug x64) | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 25458 checks, 0 failed` (25,440 before) |
| saltests negative control | `SalRegKeyIdBelow` without the whole-element test (`key[lo] != '\'`), rebuilt | `25458 checks, 1 failed` (the `Key2` vs `Key` check); header restored, rebuilt, 0 failed |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| probe after (English) | `above294_probe.ps1` -> `probe/result_after.txt`, `probe/above294_after.txt` | **24 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (34FA77DB...125A) |
| probe before (negative control) | `-Expect before` on main e752f9b9 | 14 PASS / 10 FAIL (above) |
| probe after (Czech) | `-Lang czech` -> `probe/result_after_czech.txt`, `probe/above294_after_czech.txt` | **24 PASS / 0 FAIL**, registry restored identical |
| 292's probe (regression) | `specs/292-.../probe/alias292_probe.ps1` on this build -> `probe/alias292_on294.txt` | first run 31 / 1: ALIASOTHER ERROR "Copy / Move opened no dialog" (the probe gave up waiting for the Copy / Move dialog - before any code of this feature runs; a timing flake); re-run `probe/alias292_on294_rerun.txt` **33 PASS / 0 FAIL**, registry restored identical |
