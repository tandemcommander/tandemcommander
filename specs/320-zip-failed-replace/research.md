# Research - 320-zip-failed-replace

## R1 - how the archive is replaced

- Decision: `SalReplaceWithTempW(wZip, wTemp, TRUE, TRUE, &err)` after both files are closed.
- Rationale: CLAUDE.md standing rule (105) for replacing a user's file; ReplaceFileW replaces in one
  step and leaves both files as they were on failure (measured in 105: read-only 5, held without
  delete sharing 32, missing 2); the fallback rename only for file systems without ReplaceFile.
  Already used by the PictView and SFTP plug-ins, header-only.
- `targetExisted` TRUE: the archive was opened (OPEN_ALWAYS) and checked by `CheckZip`; when it
  vanished meanwhile the rule moves the temporary file into place (srrDone) or keeps it (srrLeftAtTemp).
- `clearReadOnly` TRUE: the old code cleared the attribute unconditionally; read-only archives are
  refused before any work, so this only matters if the attribute appeared during the operation -
  the rule restores it on failure.
- Alternatives: keep delete + rename and only delete the temporary file when the delete fails -
  rejected: leaves shape (b) (archive gone, message "not changed"); a rename-the-original-to-backup
  scheme - rejected: duplicates the shared rule.

## R2 - results and messages (no new string)

| Result | Archive | Temporary file | Shown | ErrorID |
|---|---|---|---|---|
| srrDone | the updated one | gone | nothing | 0 |
| srrFailedKept | as before | deleted | "Cannot replace original archive ... Archive was not changed." | `IDS_ERRRESTORE` |
| srrLeftAtTemp | gone (third party) | kept | "Cannot open or create file." + system error + the temporary file's name, title the archive | `IDS_NODISPLAY` |
| srrFailedBothGone | gone | gone | "Cannot access file." + system error, title the archive | `IDS_NODISPLAY` |

`ProcessError(id, err, ZipName, PE_NORETRY | PE_NOSKIP, NULL, TempName)` shows the text, the system
error and `extText` (the temporary name) in the core's error box.

## R3 - attributes, times, compression

- srrDone: `SetFileAttributesU8(ZipName, ZipAttr | FILE_ATTRIBUTE_ARCHIVE)` as before.
- ReplaceFileW keeps the replaced file's creation time, ACL, compression, encryption and named
  streams (Zone.Identifier) and takes the replacement's content and last-write time - so "set zip
  file time to the newest file time" (SetFileTime on the temporary file) still holds. Checked in
  saltests (last-write time, named stream).
- The old code called `SetFileAttributesU8` on failure too; on srrFailedKept the archive is
  untouched (the rule restores a cleared read-only attribute), so nothing is set.

## R4 - the 319 stream case

ReplaceFileW onto `file:stream` cannot rename a file into a stream; the fallback rename fails too;
the target is there -> srrFailedKept, the stream unchanged. Not reachable through the UI at HEAD
(Pack 319, Change Directory error 123) - checked in saltests.
