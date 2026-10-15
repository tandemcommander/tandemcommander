# Fix log: 195 - F5 Copy within a case-sensitive folder

Backlog: NEXT-WORK A.11, left by 158: "F5 copy within the same case-sensitive folder is refused
'to itself' by name".

## Measured (before)

Probe `probe/cs_copy_probe.ps1` (driver and fixtures from 158's `cs_overwrite_probe.ps1`; folders
made case-sensitive with `fsutil file setCaseSensitiveInfo`), the fix taken out and built
(`probe/result_before.txt`, 7 / 3):
- cs-new (only `a.txt`, copied as `A.txt`): **"Cannot copy a file to itself."**, nothing copied;
- cs-other (`a.txt` and another `A.txt`): the same refusal - no overwrite question;
- cs-dir (folder `d` copied as `D`): **"Cannot copy a directory to itself."**;
- cs-hl (`A.txt` a hard link of `a.txt`) and ci-case (an ordinary folder): refused - right.

`fileswn6.cpp` `BuildScriptFile` and `BuildScriptDir` (the 155 check) compared the names by the
case-insensitive rule only. The worker already decides an existing target by identity.

## Work

`src/fileswn6.cpp`: `CopyTargetIsAnotherName` - the copy is refused "to itself" unless the target
name (the source's in another case) does not exist (a case-insensitive folder would find the
source under it; the worker creates with `CREATE_NEW` and decides by identity if it exists after
all), or the folder holding it says it is case-sensitive (`FileCaseSensitiveInfo`,
`ParentIsCaseSensitive`) and the file system's identity, read through links as the copy reads,
proves it another file.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 12 / 0: cs-new copied (both files), cs-other asks to overwrite (Yes:
`A.txt` holds `a.txt`'s content), cs-dir copied, cs-hl and ci-case refused, cs-junc (`D` a
junction to `d`, added after the review) refused at the folder. Regressions: 158's probe 10 / 0,
103's `samefile_probe -Expect103` 46 / 0 (8 not driven as recorded there).

## Review

Refute-first review: no critical finding. SHOULD-FIX 1, taken: the first version compared the
links themselves - a junction `D` to `d` passed the folder check and the copy went file by file
(each refused, an empty folder "copied"); a file symlink with a multi-link target reached the
worker's old handling. The identities are read through links now (cs-junc). SHOULD-FIX 2, taken:
different ids alone proved nothing on mounts that derive ids from the path - an existing target
is taken for another file only in a folder that says it is case-sensitive. Checked: 8.3 names do
not reach the helper, errors other than not-found refuse, no usable ids refuse, the folder copy
cannot recurse into itself (siblings), Unicode case pairs, the operator precedence.

On the way, the probe's first junction row typed a target without its folder ("\cs\D"); the
program offered to create `C:\cs` and the probe answered Yes - **`C:\cs\D\f.txt` (10 bytes, the
fixture's text "PRECIOUS-6") was created at 03:26 and could not be deleted from this session (a
safety check)** - owed to the maintainer: delete `C:\cs`. The probe refuses a target outside its
fixture now.
