# Fix log: 199 - the Renamer keeps a file whose short name is the new name

Found by the review of 196 (older): the Renamer has no step that moves an 8.3 short-name clash
aside, as the core's Quick Rename does.

## Measured (before)

Probe `probe/ren_83_probe.ps1` (the Renamer driver of 155 / 196; short names are made on C:,
checked with `dir /x`), the build at 198 (`probe/result_before.txt`, 3 / 1):
- ren-83 (`x.txt` renamed to `LONGFI~1.TXT`, the short name of `longfilename.txt`): **"Confirm
  File Overwrite"** for "LONGFI~1.TXT", answered Yes - **`longfilename.txt`'s content was gone**:
  the file was deleted, and NTFS name tunnelling gave the renamed `x.txt` the long name
  `longfilename.txt` (it holds `x.txt`'s content);
- ren-83-ctl (the control, a free name): renamed, no box.

The script stage (`rendlg2.cpp`) found the new name with `SalGetFileAttributes` - through the
other file's short name - and asked to overwrite; `MoveFile` (`rendlg3.cpp`) then deleted it.

## Work

`src/plugins/renamer/rendlg3.cpp`, `rendlg2.cpp`, `utils.h`: `TargetIsOnlyShortNameOfOther` -
the name exists only as another entry's short name (by the 092 name rule); the script stage
treats it as free (no question); `MoveFile`, on "already exists", moves that entry aside to a
temporary 8.3 name, renames the source and gives the entry its long name back (it gets a new
short name) - the core's Quick Rename does the same. **Such a name never reaches the delete
branch**: a failed move aside is a rename error with its reason and Retry (review CRITICAL); an
entry that cannot get its name back is reported with the temporary name (review); the copy route
(another drive) refuses such a target instead of writing into the other file (review).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 6 / 0: ren-83 - no box, `x.txt` is `LONGFI~1.TXT` with its content,
`longfilename.txt` kept with its content; ren-83-held (added after the review: `longfilename.txt`
held open without delete sharing) - "Unable to rename file: (32) ..." with Retry / Skip, no
overwrite question, both files unchanged. Regressions: 196's `ren_cs_probe` 8 / 0, 155's ren-link
2 / 0. Not driven: the copy route (a rename onto another drive with the full-path option).

## Review

First refute-first review: **not sound**. CRITICAL - when the move aside failed (the other file
held open by another program - reachable, measured by the reviewer: 183, then 32) `MoveFile` fell
into the old branch: the overwrite question (none with confirmations off) and, after Retry,
`DeleteFileU8` of the other file. SHOULD-FIX - the copy route (another drive) opened the other
file `OPEN_ALWAYS` and wrote the source into it (older, now without even the question);
SHOULD-FIX - an entry left under the temporary name was only logged. All three taken (above).
Checked: tunnelling (safe as built - the aside renames by the long name), renaming a file to its
own short name (`MoveFileW` succeeds, unchanged), buffers, the batch case, hidden files, 196.
Recorded in NEXT-WORK: the core's Quick Rename has the same fallback - a failed move aside of an
8.3 clash goes to `COverwriteDlg`, and Yes replaces the other file (`fileswn5.cpp` ~2340-2392).

Second review (of the rework):
no critical finding; no path left where a short-name-only target leads to a delete of, or a
write into, the other file (the 103 identity block above it only ever moves the source; the
overwrite flags cannot reach the delete; no infinite loops; `scrLeftAside` both ways; the logic
as intended). Taken: N1 - the copy route checks again in its "exists" branch (a race after Retry);
N2 - fail closed: an entry found under the new name whose long name is another one counts as the
clash whether or not a short name is reported (a server resolving short names without listing
them); N3 - the reason of an undone rename; N4 - the temporary path reported whole (heap). Recorded
(S1, older): `CheckAndCreateDirectory`'s "adjust the case" step renames a folder whose short name
is a folder part of the new name (`LONGDI~1\x.txt`) to that short name, without a question -
NEXT-WORK. Final: the probe 6 / 0, 196's 8 / 0, 155's ren-link 2 / 0.
