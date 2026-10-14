# Fix log: 158 - a case-sensitive folder offers the overwrite of another file

Backlog: `specs/NEXT-WORK.md` item 11.

## Before (measured)

`probe/cs_overwrite_probe.ps1` on the build before (`probe/result_pre158.txt`, 7/3): in a
case-sensitive folder Quick Rename `a.txt` -> `A.txt` with `A.txt` another file: "Error Renaming
File (183) already exists"; F6 the same in the worker ("Error Moving File (183)"); both kept.
Controls on both builds: a hard-link pair (NTFS renames a link onto another name of the same file
itself - one name left, content kept, no question, as 103's hl-qren); a case-insensitive folder
(a change of case, done).

## Work

`CFilesWindow::RenameFileInternal` (`fileswn5.cpp`) and `DoMoveFile` (`worker.cpp`): in 103's
identity block `provenOther = SalFileIdMatch(srcId, tgtId) == simDifferent`; the overwrite branch
and the 8.3-name clean-up branch run for a change of case too when `provenOther` (092's exclusion
stays for everything else: unknown identity = refused).

## Decision taken (recorded)

The item was "a behaviour change left for a decision": the overwrite is offered only on proof
(different volume serial + file id); the maintainer may reverse it. With "Confirm on file
overwrite" off the target is replaced without a question - as any other overwrite.

## Review (refute-first agent, 2026-10-14)

No blocker. `simDifferent` cannot name the same file in a realistic case (WebDAV id 0 = unknown;
FAT ids follow the entry; same folder, so no volume-serial fallback; a link onto its target is
caught first; path-derived ids with equal metadata go through the temporary name). Taken over:
(LOW) the 8.3-name clean-up branch also yields to `provenOther` (it would otherwise offer to delete
a file whose 8.3 alias is the new name). Recorded (NEXT-WORK): F5 copy within the same
case-sensitive folder `a.txt` -> `A.txt` is refused "to itself" by name (`fileswn6.cpp`
BuildScriptFile; the folder copy too); the Renamer refuses with "already exists" (and uses the
code-page `StrICmp`).

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
- `probe/result.txt` 10/0 (before 7/3).
- Regression: 103 `samefile_probe -Expect103` 46/0 (its cs-qren row accepts the overwrite now).
