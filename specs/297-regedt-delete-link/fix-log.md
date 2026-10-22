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

1. `src/plugins/regedt/fs5.cpp`: `RegKeyIsLink` (file-static; first version: open as a link,
   `SymbolicLinkValue` of type `REG_LINK` - replaced after the review by the identity test
   `OpenedRegKeyIsLink`, see *Review*) - 296's `SafeCheckTargetLink` now uses it instead of its
   inline test (no key -> TRUE, no link -> TRUE, a link -> 296's decision, other error -> the box).
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

## Review

Review 1, an independent refute-first review (general-purpose agent) of the branch at ecd36726.
**No MUST.** It rebuilt the branch and re-ran the feature probe (30 / 0, registry identical) and 296's
probe (47 / 0). It also ran its own scratch rows (`%TEMP%\tcrev297`, fixture `HKCU\Software\TcReview297`, removed):

- A link to its own ancestor: F8 removes only the link; F6 refuses.
- The UTF-8 names in the boxes are whole.
- Callers enumerated: `DeleteKey` <- `Delete`, itself; `SafeDeleteKey` <- `CopyOrMoveKeyRec`;
  `CopyOrMoveKey` <- `CopyOrMoveFromFS`, `QuickRename`.
- The 296 refactor is equivalent.

| Finding | Done |
|---|---|
| SHOULD 1: a link was told by its value - a PLAIN key can hold `SymbolicLinkValue` of type `REG_LINK` (set unelevated): F8 then gave `NtDeleteKey` a key with subkeys ("Unable to delete (5)", undeletable), F6 refused it; a link without its value was taken for a plain key | measured (scratch `linktest.ps1`, `HKCU\Software\TcScratch297`, removed): opened as a link with `KEY_ENUMERATE_SUB_KEYS` the key reports its own internal name (`NtQueryKey` KeyNameInformation); opened by name a link reports its target or fails with 2 (dangling, no value); a fake-value key reports the same name both ways; `KeyFlagsInformation` (flag 2 = link) needs `KEY_QUERY_VALUE` (0xC0000022 with enumerate only). Fix: `OpenedRegKeyIsLink` - a link = the key opened by name is another key (292's `AddOpenedRegKeyId` + `SalRegKeyIdsAnySame`) or none; `RegKeyIsLink` / `SafeDeleteRegLink` use it (the delete handle is re-checked the same way). Probe rows FAKEDEL, FAKEMOVE, NOVALDEL |
| SHOULD 2: the link test asked `KEY_QUERY_VALUE` of every key Delete walks - a child that denies reading values (delete allowed) stopped F8 with "Unable to open (5)" | the new test asks only `KEY_ENUMERATE_SUB_KEYS`, which the old delete walk already needed. Probe row ACLDEL (Deny QueryValues on `AclT\<K>\Child`) |
| NOTE 3: a selected dangling link itself still cannot be deleted (Delete's pre-check) | intended (spec Clarification on the pre-check; Q1 now says "inside the selected tree"); limit recorded |
| NOTE 4: the per-level refusal splits a Move / Quick Rename (keys before the link stay moved) | intended (spec Clarification); limit recorded in FEATURE-HISTORY |
| NOTE 5: `result_*.txt` duplicate the probe outputs; the reworded MOVETREE row was never run on the old build | `result_*.txt` are the hidden-desktop runner's logs, kept as 296 does; the negative control (no link test) fails that row |

The new rows on the reviewed build (value test), `-Only FAKE,ACL,NOVAL,DELHKCRPLAIN` ->
`probe/link297_review_before.txt`: **4 FAIL** (FAKEDEL, FAKEMOVE, ACLDEL, NOVALDEL), DELHKCRPLAIN and
END rows PASS, registry restored identical. After the fix (`probe/result_after_review.txt`,
`probe/link297_after.txt`): **40 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical.

After the review (identity test), on its build:

| Check | Result |
|---|---|
| probe (English, 40 rows) `probe/link297_after.txt`; re-run after the negative control `probe/result_after_final.txt` | **40 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical |
| probe (Czech) `probe/link297_after_czech.txt` | **40 PASS / 0 FAIL**, registry restored identical |
| 296's probe `probe/link296_on297.txt` (its target check now uses the identity test) | **47 PASS / 0 FAIL**, registry restored identical |
| 294's probe `probe/above294_on297.txt` | **24 PASS / 0 FAIL**, registry restored identical |
| 292's probe `probe/alias292_on297.txt` | **33 PASS / 0 FAIL**, registry restored identical |
| negative control: `OpenedRegKeyIsLink` always "no link" (both branches), rebuilt, `-Only DEL,MOVE,RENAME,NOVAL` -> `probe/link297_negctl_ident.txt` | **15 FAIL** (every link row incl. NOVALDEL, DELHKCR); DEL / MOVE controls PASS; reverted (no mutation left), rebuilt |
| saltests / encoding guard | `saltests: 26304 checks, 0 failed`; `TOTAL: 0 finding(s)` |

No second review: review 1 had no MUST (SKILL step 7 asks a fresh review only after MUST fixes).

## Out of scope (found while measuring)

- Copy (F5) and Find walk through a link to an ancestor of the walked key until the key-name length
  limit (research R4, reasoned from the code). Inbox
  `registry-editor-copy-or-find-through-a-link-to-an-ancestor` (`measure:297`).
