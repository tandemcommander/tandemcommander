# Fix log: 230 - drag & drop / paste into an archive takes exactly the dragged names

Backlog (228's review): `CFilesWindow::DragDropToArcOrFS` (`fileswna.cpp`) matches the source
folder's listing against the dragged / pasted names (sorted with `SalNameCompareOrdinalCI`) with
`ContainsString` (case-insensitive). A second match for one name was traced as a "duplicate" and
**added anyway**.

## Read (not driven)

In a case-sensitive folder (`fsutil file setCaseSensitiveInfo`, WSL - such a folder can be made
here) holding a.txt and A.txt, dragging or pasting only a.txt into a ZIP: both were added to the
item list - **A.txt, which nobody selected, was packed (with Move: deleted from disk)**, and the
index array (`nameFound`, one int per name, reused as `dataEnum.Indexes` of `IndexesCount`
entries) was **overrun on the heap**. The route needs drag & drop or the clipboard (Ctrl+C,
Ctrl+V into an archive panel): neither exists on the hidden desktop - a step owed to a person.

## Work

`src/common/salnamerun.h` (new; saltests `TestNameExactInCIRun230`):
- `SalNameExactInCIRun`: the byte-equal entry within the case-insensitive run of the sorted names;
- `SalNameCIRunSingle`: the entry when the run holds it alone.

`src/fileswna.cpp`:
- the item-building code moved unchanged into `AddDragDropItem`;
- a name is taken once: by the listed item byte-equal to it; an item equal to it only
  case-insensitively (a drag source may give a name in another case - a path the user typed) only
  after the listing, when no byte-equal item took it, it is the only such item, the name is alone
  in its run and the folder is not case-sensitive (`SalDirIsCaseSensitive`, factored out of 195's
  `ParentIsCaseSensitive` in `fileswn6.cpp`);
- a guard: more items than names -> nothing done (unreachable now).

Build: BUILD SUCCEEDED; saltests 22,682 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Review

1. Refute-first review of the first version (byte-equal only): **SHOULD, taken - too strict**: a
   source giving another case (e.g. PowerShell `Set-Clipboard -Path .\README.TXT` for readme.txt)
   turned a working paste in a normal folder into "some files were not found"; the fallback above.
   Other places with the same pattern recorded in NEXT-WORK.
2. Second review: no MUST; the refactor behaviour-identical, every path frees, the fallback can
   never take an item another name took (never more items than names). SHOULD taken: the
   fallback decision as a pure rule (`SalNameCIFallbackTakes`, saltests). Kept: `ciOnlyData` is one
   find record per name (only when a case-only match is seen); a folder whose case sensitivity
   cannot be told (SMB, `\\wsl$`) gets the fallback - only for a name not on disk byte for byte
   with exactly one other-case item (the old code took any).
