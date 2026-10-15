# Fix log: 198 - Quick Rename and Move prove another file by the temporary name

Found by the review of 196 (the same pattern in the Renamer): the core's Quick Rename (158,
`fileswn5.cpp` `RenameFileInternal`) and the worker's move (`worker.cpp` `DoMoveFile`) set
`provenOther = SalFileIdMatch(src, tgt) == simDifferent` and, for two names equal by the file
system's rule (a change of case), let the overwrite branch delete the target when `provenOther`.

## Read (before)

Different ids are no proof for two spellings of ONE name: mounts that derive file ids from the
path (FUSE / WinFsp / Dokan, `salsamefile.h` names them) give two ids, and when the metadata
differ between the two reads (a file being written, a per-path cache) `SalDecideExistingTarget`
returns the old handling - a rename `a.txt` -> `A.txt` answered "already exists" for the SAME
file would then delete it as "another file". Such a mount is not available here: not driven;
the change is checked by the case-sensitive rows that take the new route.

## Work

`src/fileswn5.cpp`, `src/worker.cpp`: for two spellings of one name - equal by case or by Unicode
normalization (`SalNamesLooselyEqualU8`: NFC / NFD, review) - the rename always goes through the
temporary name; `provenOther` is set only when that route finds the target outliving the source's
name (`svtTargetIsOther`). Other names are unchanged.

Build: BUILD SUCCEEDED.

## Measured (after)

158's `cs_overwrite_probe -Expect103` 10 / 0 (`probe/regress_158.txt`): a case-sensitive folder,
`a.txt` -> existing other `A.txt` asks to overwrite through the new route (Quick Rename and F6),
Yes and No, a hard link renamed by NTFS itself, an ordinary folder's change of case; 103's
`samefile_probe -Expect103` 46 / 0 (`probe/regress_samefile103.txt`).

## Review

Refute-first review: sound. Names that are not equal keep their route (the four reads of
`provenOther` all sit behind `!SalNameEqualOrdinalCI(...) ||`); a case-sensitive `A.txt` that is
another file still reaches the overwrite question through the temporary name; the 8.3 branch does
nothing for a change of case; directories never reach a delete (a folder renamed only in case on a
server answering "exists" is renamed now instead of "already exists"); `svtLeftAtTemp` /
`svtFailed` unchanged. Recorded (NIT): a deliberate loosening - for one name the temporary-name
result alone now proves another file (two hard links of one file in a case-sensitive folder, a
file system with no ids, newly reach the overwrite question - both keep the data, as 103 does for
names that differ); a case-sensitive folder `A` that is another folder: the user's folder goes to
`salNNN` and back before "already exists" (reported if the way back fails). Taken (SHOULD-FIX,
older): names equal only by NFC / NFD took the old route too - `SalNamesLooselyEqualU8`. Recorded
in NEXT-WORK: PictView's rename (`render1.cpp` ~2991) gates its overwrite with the code-page
`StrICmp` and has no temporary-name route.

After the review's change: 158's probe 10 / 0, 103's 46 / 0 (its WebDAV NFC / NFD rows not driven:
the WebClient service is not running here).
