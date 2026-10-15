# Fix log: 202 - PictView's Rename to another file's short name never replaces it

Found by the review of 200: PictView's rename of the shown image (`render1.cpp`
`RenameFileInternal`) has the 8.3 trap 199 fixed in the Renamer - a new name that is only the short
(8.3) name of another file goes to the overwrite question for that file.

## Measured (before)

Probe `probe/pv_83_probe.ps1` (111's driver; short names are made on C:), the build at 201
(`probe/result_before.txt`, 6 / 3):
- **pv-83** (the shown `x.png` renamed to `LONGFI~1.PNG`, the short name of `longfilename.png`):
  **"Confirm File Overwrite"** for `LONGFI~1.PNG`; Yes replaced `longfilename.png` - it is gone, its
  content `OTHER` lost (rows OTHER, BOXES);
- **pv-83-held** (`longfilename.png` held open, no delete sharing): the same question; Yes failed
  only because the file was held ("(5) Access is denied") (row BOXES).

## Work

`src/plugins/pictview/render1.cpp`:
- `PvTargetIsOnlyShortNameOfOther` - the entry found under the new name has another long name (the
  092 rule `SalNameOrderEqualCI`, fail closed whether or not a short name is reported); a search
  that fails other than "not found" (a folder that cannot be listed) answers "cannot tell";
- `PvMoveAsideShortNameClash` - that entry renamed to a temporary `salNNN` name, the shown file to
  the new name, the entry back to its long name (a new short name); if that last step fails the
  rename is undone and retried; still failing, the box names where the other file is. Never deletes;
- in `RenameFileInternal`, before the overwrite branch: for such a name (and for "cannot tell")
  `keepTarget` - the overwrite branch never runs for it; a failed move aside is the rename's error.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 9 / 0: pv-83 - renamed, `longfilename.png` keeps `OTHER`, no question;
pv-83-held - "Error Renaming File (32)", no question, both files unchanged. Regressions: 200's
probe 5 / 0 (`probe/regress_200.txt`), 111's rename rows 11 / 0 (`probe/regress_111_rename.txt`).

## Review

Refute-first review: sound - the viewer lets go of the shown file before the rename and retakes
the name that is really there in every outcome; `keepTarget` is set before the move is tried, so
no failure (also "already exists") reaches the overwrite branch; 103 (a link to the target, the
file's own short name - same identity) and 200 (two spellings in a case-sensitive folder) keep
their routes; names past MAX_PATH work (heap paths, a 255-unit component fits `clashLong`).
SHOULD-FIX taken: the search failing other than "not found" refused instead of falling back to the
question (a drop-box folder, a share that resolves short names on open but not in a search) -
re-measured 9 / 0, 5 / 0, 11 / 0. NITs recorded: a server that folds more than Windows (NFC / NFD,
"ss") moves a legitimately same-named file aside briefly and reports "already exists" instead of
the question (nothing lost); the other file shown in another PictView window - "in use" without
naming it (120 lets a target's viewers go only for an overwrite); a folder's short name typed is
renamed aside and back as in the Renamer (199). Not driven: the undo-and-retry and "left at"
branches (the Renamer's code, reviewed twice).
