# Fix log: 196 - the Renamer in a case-sensitive folder

Backlog: NEXT-WORK A.11, left by 158: "the Renamer refuses 'already exists' (and uses the
code-page `StrICmp`)".

## Measured (before)

Probe `probe/ren_cs_probe.ps1` (the Renamer driver of 155 / 104: only `a.txt` selected, Ctrl+Shift+R,
the new name `A.txt`; folders made case-sensitive with `fsutil file setCaseSensitiveInfo`), the
build at 195 (`probe/result_before.txt`, 6 / 2):
- ren-cs-yes / ren-cs-no (`a.txt` and another `A.txt`): **"Unable to rename file: (183) Cannot
  create a file when that file already exists."** - no overwrite question;
- ren-cs-hl (`A.txt` a hard link of `a.txt`): renamed, one name left - right;
- ren-ci (an ordinary folder): a change of case - right.

`rendlg3.cpp` `MoveFile` overwrote only when `SG->StrICmp(source, target) != 0` - a change of case
never, also when the identity block of 103 had shown the target to be another file.

## Work

`src/plugins/renamer/rendlg3.cpp`: `provenOther` - TRUE only when the temporary-name route found
the target outliving the source's name (for two spellings of one name the rename always goes
that way - review); the overwrite branch runs for a different name by the file system's rule
(`SalNameOrderEqualCI`, 092 / 115, instead of the code-page `StrICmp`) or a proven other file.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 8 / 0: ren-cs-yes - the Renamer's "Confirm File Overwrite", Yes:
`A.txt` holds `a.txt`'s content; ren-cs-no - No: both kept; ren-cs-hl and ren-ci unchanged.
Regression: 155's ren-link (a symbolic link renamed onto its target: refused) 2 / 0. After the
review's change: 8 / 0 again.

## Review

Refute-first review: no critical finding. SHOULD-FIX, taken: the first version also took
"different ids and different metadata" (`setaLegacy` + `simDifferent`) as proof - on a mount with
path-derived ids answering "already exists" to a change of case of the SAME file, with metadata
that differ between the two reads (a file being written, a per-path cache), the branch would
delete the source; before 196 that case could not delete anything. For two spellings of one name
only the temporary-name route proves another file now. **The core's Quick Rename (158,
`fileswn5.cpp` ~2278) has the same exposure** - recorded in NEXT-WORK. Checked: hard links (the
data stays under the source's name), a symlink as source (refused by 103) or target (the link is
deleted), folders (refused before the delete), FAT (never reached), the name rule (strictly
safer), the retry loop. NIT, taken: FR-002's wording (the source's data, not "a link"). NIT,
recorded (older): the plug-in has no step that moves an 8.3 short-name clash aside - renaming to
`LONGFI~1.TXT` asks to overwrite and deletes `longfilename.txt`; measure first.
