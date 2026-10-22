# Fix log - 297-regedt-delete-link

Backlog item `registry-editor-delete-or-move-deletes-a-linked-key` (source measure:296).

## Measured at 49147f36 (main, before the feature)

1. Sites (searched by name): `CPluginFSInterface::DeleteKey` (`src/plugins/regedt/fs3.cpp`) opens the
   key by name (`RegOpenKeyExW`, follows a link), enumerates and recursively deletes its subkeys
   (those of the link's target), then `RegDeleteKeyW(root, keyName)` - deletes the link's target;
   `CopyOrMoveKeyRec` (`fs5.cpp`) opens each source key by name, copies, and a Move ends with
   `SafeDeleteKey` (`RegDeleteKeyW`) on the source name.
2. Reachable: F8 (`CPluginFSInterface::Delete` -> `DeleteKey`), F6 / drag and drop
   (`CopyOrMoveFromFS` -> `CopyOrMoveKey`), Quick Rename (`QuickRename`, `fs3.cpp` ->
   `CopyOrMoveKey` with `move` TRUE) in a Registry Editor panel; plug-in on in `plugins.cfg`, default
   configuration. A link can be created unelevated under HKCU (`REG_OPTION_CREATE_LINK`). Callers of
   `DeleteKey`: only `Delete` and itself; of `SafeDeleteKey`: only `CopyOrMoveKeyRec`; of
   `CopyOrMoveKey`: `CopyOrMoveFromFS`, `QuickRename`.
3. New probe `probe/link297_probe.ps1` (style of 296's; links made / removed with
   `REG_OPTION_CREATE_LINK` / `REG_OPTION_OPEN_LINK` + `NtDeleteKey`; the snapshot never follows a
   link), first written in `%TEMP%\tc297scratch` (with `-Repo`) and copied here unchanged. Debug x64
   build of 49147f36 (`build.cmd`, BUILD SUCCEEDED):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tc297scratch\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File %TEMP%\tc297scratch\link297_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -Repo E:\Projects\tandemcommander -OutFile %TEMP%\tc297scratch\link297_before.txt"
   ```

   First run: 15 / 15 with two probe bugs - `Jinde-Ok` expected the unsorted order (`'\'` sorts
   before `'|'`; the COPYTREE control failed on it - a negative finding about the probe, fixed), and
   the name in the error box is read through the code page (287's trap; `U8-Back` reverses it). A
   Bash here-doc collapsed `'\Top\'` to `'\Top'` in one edit (the known trap) - redone with the editor.
   Second run (`probe/link297_before.txt`): **16 PASS / 14 FAIL**, registry restored identical
   (SHA-256 34FA77DB...125A).
   - DELTREE / DELHKCR: `Jinde` and `Jinde\Sub` deleted, the link left, then "Unable to delete a
     registry key. (5) Access denied" for `Del\<K>`.
   - DELTOP: `Jinde` deleted, no box, the link left dangling.
   - DELDANGLE: the open-error box for the link, nothing deleted.
   - MOVETREE / MOVESKIP: `Jinde` copied into `Cil\<K>\L` and deleted, then "Unable to remove the
     original registry key. (5)" naming `Mov\<K>` (the TEXT row of MOVESKIP passes already before -
     STATE discriminates).
   - MOVETOP / RENAMETOP: `Jinde` copied and deleted, no box.
   - Controls COPYTREE, DEL, MOVE: PASS.

## Decisions

- Spec *Clarifications* (autonomous run): Delete removes the link itself (opened as a link,
  `NtDeleteKey`), a dangling one too; Move / drag and drop / Quick Rename refuse a link source key with
  the existing box `IDS_REMOVESOURCE` + `ERROR_NOT_SUPPORTED` (Retry / Skip / Skip All / Cancel) before
  anything of it is written; Copy unchanged; only the key of each level is looked at as a link (as
  296); other errors fail closed. No new string.
- Analyze (one run): no CRITICAL / HIGH. Accepted: MEDIUM C1 - the fail-closed path (a key that
  cannot be inspected) is not driven (needs an ACL change on a link key; as 296's C1); LOW C2 - Retry /
  Skip All of the refusal box not driven (the existing `RegOperationError` loop); LOW C3 - drag and
  drop not driven (same `CopyOrMoveFromFS` path as F6); LOW F1 - the Copy / Find loop through a link
  to an ancestor is reasoned from the code (Inbox item marked not driven).

## Implementation

1. `src/plugins/regedt/fs5.cpp`: `RegKeyIsLink` (file-static; open as a link, `SymbolicLinkValue` of
   type `REG_LINK`) - 296's `SafeCheckTargetLink` now uses it instead of its inline test (same
   results: no key -> TRUE, no link -> TRUE, a link -> 296's decision, other error -> the box).
   `SafeRegKeyIsLink` (the open-error box; "not found" = no link) and `SafeDeleteRegLink`
   (`REG_OPTION_OPEN_LINK` + `DELETE | KEY_QUERY_VALUE`, the link value re-read on that handle - no
   longer a link = `ERROR_NOT_SUPPORTED`, never deleted -, `NtDeleteKey` / `RtlNtStatusToDosError` by
   `GetProcAddress`; errors in the `IDS_DELETE` box, Retry repeats). Declared in `regedt.h`.
2. `CopyOrMoveKeyRec`, a Move: first thing of every level - a link source key gives
   `RegOperationError(ERROR_NOT_SUPPORTED, IDS_REMOVESOURCE, ...)` ("Unable to remove the original
   registry key. (50) The request is not supported."), Retry checks again, Skip / Cancel return before
   the source is opened for copying, 296's target check or any write. Callers: `CopyOrMoveFromFS` (F6,
   drag and drop) and `QuickRename` (`fs3.cpp`), both through `CopyOrMoveKey`.
3. `src/plugins/regedt/fs3.cpp` `DeleteKey` (callers: `Delete` and itself): first thing of every
   level - a link is removed with `SafeDeleteRegLink` and the level returns; nothing is enumerated or
   deleted through it. `Delete`'s check before it starts (the "not empty" question) is unchanged
   (spec Clarification).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `build.cmd` (Debug x64) | BUILD SUCCEEDED (the C4267 warnings of `fs2.cpp` are old - `regedt.h` rebuilt the plug-in) |
| probe after, first run | `link297_probe.ps1` -> `probe/link297_after.txt` | 29 PASS / 1 FAIL: MOVETREE STATE expected `Mov` unchanged, but `Z` (processed before `L`: the subkeys go last-first) was already moved into `Cil\<K>` when Cancel came at `L` - nothing lost (z=9 in the target, `Mov\<K>` with a=1 and the link). The expectation was wrong, not the fix (decided per level, spec Clarification): the row now checks `Mov\<K>` kept with a=1 and its link, z=9 exactly once, `Jinde` unchanged, nothing below `Cil\<K>\L`; the spec scenario US2.1 says so |
| probe after (English) | -> `probe/result_after.txt`, re-run after the negative control `probe/result_after_final.txt`, `probe/link297_after.txt` | **30 PASS / 0 FAIL / 0 NOT DRIVEN** (both runs), registry restored identical (34FA77DB...125A) |
| probe after (Czech) | `-Lang czech` -> `probe/result_after_czech.txt`, `probe/link297_after_czech.txt` | **30 PASS / 0 FAIL**, registry restored identical (Czech box texts checked) |
| probe before | `-Expect before` on 49147f36 | 16 PASS / 14 FAIL (`probe/link297_before.txt`; the MOVETREE STATE row reworded after it - on the old build `Jinde` was gone and `Cil\<K>\L` existed, so it fails there too; the negative control below shows it) |
| negative control | `if (FALSE && isLink)` in `DeleteKey`, `if (TRUE \|\| !isLink) break;` in `CopyOrMoveKeyRec`, rebuilt, `-Only DEL,MOVE,RENAME` -> `probe/link297_negctl.txt` | **14 FAIL** (every link row: DELTREE, DELDANGLE, DELTOP, MOVETREE TEXT + STATE, MOVESKIP STATE, MOVETOP, RENAMETOP, DELHKCR); DEL / MOVE controls PASS; reverted (no mutation left in `fs3.cpp` / `fs5.cpp`), rebuilt, full probe 30 / 0 |
| 296's probe | `link296_probe.ps1` on this build -> `probe/link296_on297.txt` | **47 PASS / 0 FAIL**, registry restored identical (`RegKeyIsLink` refactor) |
| 294's probe | `above294_probe.ps1` -> `probe/above294_on297.txt` | **24 PASS / 0 FAIL**, registry restored identical |
| 292's probe | `alias292_probe.ps1` -> `probe/alias292_on297.txt` | **33 PASS / 0 FAIL**, registry restored identical |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 26304 checks, 0 failed` (no rule changed) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |

Not driven: the fail-closed path (analyze C1), Retry / Skip All of the refusal box (C2), drag and
drop (C3) - read by the review.

## Out of scope (found while measuring)

- Copy (F5) and Find walk through a link to an ancestor of the walked key until the key-name length
  limit (research R4, reasoned from the code). Inbox
  `registry-editor-copy-or-find-through-a-link-to-an-ancestor` (`measure:297`).
