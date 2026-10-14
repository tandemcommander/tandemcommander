# Fix log: 175 - Convert and Quick Rename replace an existing file in one step

Backlog: NEXT-WORK items 5f and 5g (found by 173's review).

## Measured (before)

Probe `probe/replace_probe.ps1` (hidden desktop), the build at 168 (`Debug_x64_pre169`) and the
build at 174: `probe/result_before.txt` (7 / 1).

- **Files > Convert** (CONV-PLAIN, end of line CRLF -> LF): the content was converted, but the
  file **lost its alternate data stream** `a.txt:note` - the conversion deleted the user's file and
  moved a new one in (the same loses the ACL and the short name; a failed move after the delete
  would leave the file gone - not producible on Windows 11 NTFS, see 173).
- CONV-LOCKED (the file held open without `FILE_SHARE_DELETE`): the delete fails, the error box,
  the file kept - on both builds.
- **Quick Rename** onto an existing file (REN-PLAIN, overwrite question Yes): works on both;
  REN-LOCKED (target held without `FILE_SHARE_DELETE`): the delete fails, both files kept. The
  probe's first version answered the Quick Rename dialog that opens again after the error - it then
  retried after the handle was closed; the probe now cancels that dialog.

## Work

- `src/worker.cpp` (Convert): the temporary file is flushed (a failed flush is a write error);
  `SalReplaceWithTempW` puts it in the file's place in one step (rule 105); done - the source's
  attributes on the file as before; the file gone and the content only in the temporary file - the
  existing move-retry box that names it; otherwise the existing "error overwriting" box (Retry /
  Skip / Cancel) with the replace's error.
- `src/fileswn5.cpp` (Quick Rename onto an existing file): `MoveFileEx(MOVEFILE_REPLACE_EXISTING)`
  in one step; the target's read-only attribute put back when it fails.

No string, interface or registry change. Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

The same probe: 10 / 0 (`probe/result_after.txt`; before 8 / 2) - the converted file keeps its
stream, a read-only file stays read-only (CONV-RO, added after the review: the attribute is now set
after the replace); the locked rows unchanged; registry identical. A hidden + system file cannot be
driven: the panel does not list it ("No matches found").

## Review

Independent refute-first review (read-only): nothing CRITICAL; the flush-failure `goto` (handles
closed once, the error kept, Retry / Skip / Cancel), the retried replace, encryption / compression
of the temporary file against `ReplaceFileW`, the attributes after the replace, `srrLeftAtTemp`, and
Quick Rename (same folder only, read-only target restored on failure, `err` / `ret` /
`NextFocusName` as before) checked.
- SHOULD-FIX, taken: a read-only file probed (CONV-RO).
- NIT, taken: the comment of the overwrite-error branch names the both-gone case.
- Accepted: a file system whose `FlushFileBuffers` fails always reports a write error (as 105 and
  173); Quick Rename lost the NetWare read-only-source retry of `SalMoveFile`; hard links share a
  cleared read-only attribute (as before).
- Recorded in NEXT-WORK: F6 Move onto an existing file deletes the target before the move (5h);
  Pack with "overwrite" deletes the existing archive before packing (5i).
