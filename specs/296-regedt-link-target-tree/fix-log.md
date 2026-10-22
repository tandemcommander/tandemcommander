# Fix log - 296-regedt-link-target-tree

Backlog item `registry-editor-move-through-a-link-in-the-target-tree` (source review:294, NOTE 1).

## Measured at 4420aae1 (main, before the feature)

1. Sites (searched by name): `CopyOrMoveKey` in `src/plugins/regedt/fs5.cpp` creates / opens each
   target key with `SafeCreateKey` (`RegCreateKeyExW`, follows links), for the top key and for
   every `target\<subkey>` of the recursion; the checks of 292 (identity) and 294
   (`SafeRegKeyHoldsPath`) in `CPluginFSInterface::CopyOrMoveFromFS` look at the top target key only.
2. Reachable from F5 / F6 in a Registry Editor panel (plug-in on in `plugins.cfg`, default
   configuration), target typed in the Copy / Move dialog; also drag and drop (same function) and
   Quick Rename (`fs3.cpp`, `CopyOrMoveKey` with a sibling name). A registry link can be created by
   an unelevated user under HKCU (`REG_OPTION_CREATE_LINK`).
3. Win32 behaviour, scratch script `%TEMP%\tc296scratch\linkexp.ps1` (outside the repository; keys
   under `HKCU\Software\TcLinkExp296`, removed at its end - `removed : True`):

   ```text
   open Dst\Src\P (follow)           : \REGISTRY\USER\<SID>\Software\TcLinkExp296\Src\P
   open Dst\Src\P (open_link)        : \REGISTRY\USER\<SID>\Software\TcLinkExp296\Dst\Src\P
   islink Dst\Src\P                  : query 0 type 6 size 178
   islink Dst\Src (real)             : query 2 type 0 size 0
   islink Dst\Src\none               : open err 2
   open Dst\Src\D (follow, dangling) : err 2
   create Dst\Src\P (through link)   : disp 2 name ...\Src\P
   create Dst\Src\D (dangling link)  : disp 1 name ...\Src\New       (Src\New exists now : True)
   create Dst\Src\P\Sub (below link) : disp 1 name ...\Src\P\Sub
   DeleteLink (OPEN_LINK + NtDeleteKey) : 0, Src\P still exists : True
   ```

4. New probe `probe/link296_probe.ps1` (style of 294's; links made with `REG_OPTION_CREATE_LINK`,
   removed with `REG_OPTION_OPEN_LINK` + `NtDeleteKey` before the fixture tree; the snapshot never
   follows a link), Debug x64 build of 4420aae1 (`build.cmd`, BUILD SUCCEEDED):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\296-regedt-link-target-tree\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\296-regedt-link-target-tree\probe\link296_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile specs\296-regedt-link-target-tree\probe\link296_before.txt"
   ```

   Result: **14 PASS / 15 FAIL**, registry restored identical (SHA-256 34FA77DB...125A).
   - LINKMOVE / LINKALIAS (F6 of `Zdroj\<K>` {a=1, Z {z=9}} into `Cil\`, `Cil\<K>\Z` -> `Zdroj\<K>`):
     no box; `Zdroj\<K>` gone entirely, z=9 nowhere (written into the moved key after its values
     were copied, deleted with it).
   - LINKCOPY (F5): no box; `Zdroj\<K>` = a=1;z=9.
   - LINKOK: no box (the same loss).
   - LINKUP (F6 of `Hore\<K>` {U {u=2, <K> {w=7}}} into `Cil2\`, `Cil2\<K>\U` -> `Hore`): no box;
     `Hore\<K>` gone, w=7 nowhere, `Hore` = u=2.
   - LINKDANGLE (`Cil5\<K>\Z` -> missing `Zdroj\<K>\Nove`): `Zdroj\<K>\Nove` = z=9 created inside the
     source, then "Unable to remove the original registry key. (5) Access denied".
   - LINKTOP (`Cil6\<K>` itself -> missing `Zdroj\<K>\Nove`): `Zdroj\<K>\Nove\Nove\...` dozens deep,
     each a=1, then an open-error box (the row's TEXT check passed already before - the STATE / ALL
     rows are the discriminating ones).
   - LINKUPOK, LINKOTHER, MOVE (controls): PASS.

## Decisions

- Spec *Clarifications* (autonomous run): refuse only links that reach the source (inside / equal,
  or holding it with the 294 chain); other links followed as before; a dangling link refused with
  the open-error box (`ERROR_CANT_RESOLVE_FILENAME`); the existing "into itself" box naming the full
  source key; decided per level before anything of that key is written (what was copied above stays,
  a Move then keeps its source); other errors fail closed. No new string.
- `CopyOrMoveKey` keeps its signature (wrapper + static recursion), so Quick Rename and drag and
  drop get the check too.
- No new pure rule: the decision reuses `SalRegKeyIdsAnyWithin` / `SalRegKeyIdBelow` (checked by
  saltests in 292 / 294); 294's pair loop becomes a shared helper instead of a copy.
- Analyze (one run): no CRITICAL / HIGH. Accepted: MEDIUM C1 - the fail-closed "other error" path
  is not driven by the probe (it needs an ACL change on a link key); LOW C2 - Quick Rename onto a
  dangling-link sibling not driven (same wrapper); LOW U1 - a link inside the source tree is outside
  the item (checked at closing whether an Inbox item is needed).

## Implementation

All in `src/plugins/regedt/fs5.cpp`:

1. `SafeRegKeyIdsReachSource` - 294's identity-pair loop of `CopyOrMoveFromFS` moved into a helper
   (same results: Skip leaves the key alone, Cancel / low memory stops); `CopyOrMoveFromFS` calls it.
2. `CopyOrMoveKey` keeps its signature (`regedt.h`; callers `CopyOrMoveFromFS` - F5 / F6 / drag and
   drop - and `QuickRename`, `fs3.cpp`) and becomes a wrapper: a heap `CRegCopyTop` (the source root,
   a heap copy of the selected key's path, its identities read lazily) passed to the static recursion
   `CopyOrMoveKeyRec` (the former body; the parameter is named `operation` - `top` is the recursion's
   stack index, first build: C2082).
3. `SafeCheckTargetLink`, called in the recursion before `SafeCreateKey` of every level (the top key
   included): opens the target as a link (`REG_OPTION_OPEN_LINK`, `KEY_QUERY_VALUE`); no key or no
   `SymbolicLinkValue` of type `REG_LINK` = as before. A link: the source's identities (once), the
   link's identities with links followed (`GetRegKeyIds`); `SalRegKeyIdsAnyWithin(link, source)` or
   `SafeRegKeyIdsReachSource(current source key, ...)` = refuse; `ERROR_FILE_NOT_FOUND` (dangling) =
   `RegOperationError(ERROR_CANT_RESOLVE_FILENAME, IDS_OPEN)`; other errors = the open-error box.
4. A refusal: `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2` with `<root name>\<source>` joined on
   the heap (whole), OK = skip (the parent then keeps its source on a Move), Cancel / low memory =
   stop; nothing of that key is written.

Checked on all roots (scratch `openlink_roots.ps1`, read-only): opening an existing key of HKCR,
HKCU, HKLM, HKCC, HKU as a link succeeds and its `SymbolicLinkValue` query gives 2 (no link);
`HKLM\SYSTEM\CurrentControlSet` gives type 6 (a system link: resolved and followed, as it never lies
in a source the user copies unless it really does).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `build.cmd` (Debug x64) | first attempt C2082 (parameter `top` clashed with the local stack index) - renamed `operation`; then BUILD SUCCEEDED |
| probe after (English) | `link296_probe.ps1` -> `probe/result_after.txt`, re-run after the negative control `probe/result_after_final.txt`, `probe/link296_after.txt` | **29 PASS / 0 FAIL / 0 NOT DRIVEN** (both runs), registry restored identical (34FA77DB...125A) |
| probe after (Czech) | `-Lang czech` -> `probe/result_after_czech.txt`, `probe/link296_after_czech.txt` | **29 PASS / 0 FAIL**, registry restored identical |
| probe before | `-Expect before` on 4420aae1 | 14 PASS / 15 FAIL (above) |
| negative control | the chain branch disabled (`if (FALSE && !refuse)` before `SafeRegKeyIdsReachSource` in the link check), rebuilt, `-Only LINKUP,LINKMOVE` -> `probe/link296_negctl_chain.txt` | LINKUP TEXT / STATE **FAIL** (Hore\<K> moved, w=7 gone), LINKMOVE PASS (first branch); reverted, rebuilt, full probe 29 / 0 |
| 292's probe | `alias292_probe.ps1` on this build -> `probe/alias292_on296.txt` | **33 PASS / 0 FAIL**, registry restored identical |
| 294's probe | `above294_probe.ps1` on this build -> `probe/above294_on296.txt` | **24 PASS / 0 FAIL**, registry restored identical |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 26304 checks, 0 failed` (no rule changed) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |

Not driven (analyze C1 / C2): the "other error" path (needs an ACL change on a link key) and Quick
Rename onto a dangling-link sibling (same wrapper) - left for the review's scratch rows.

## Out of scope (found while measuring)

- A registry link inside the **source** tree (analyze U1): scratch `deletelink.ps1`
  (`HKCU\Software\TcLinkDel296`, removed) - `RegDeleteKeyW` on a link's name deletes the key the
  link points at and leaves the link. So Delete (F8, `DeleteKey`, `fs3.cpp`) and Move of a key
  holding a link remove a key outside the selection. Inbox
  `registry-editor-delete-or-move-deletes-a-linked-key` (`measure:296`).
