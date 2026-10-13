# Feature Specification: SFTP - nothing is replaced without a question, and never before its replacement is whole

**Feature Branch**: `139-sftp-no-silent-overwrite`
**Created**: 2026-10-13
**Status**: Draft
**Input**: The maintainer: "when everything is finished, run independent tests again and try
everything in detail; queue the medium and critical problems you meet and fix them through the
Spec Kit flow." The final independent review of the SFTP operations (2026-10-13) found, all of
them present in 0.1.9 already:

- **critical**: an upload replaces a file that already exists on the server without asking, by
  truncating it first - a failed or cancelled upload leaves a torso and the old content is gone;
- **critical**: Quick Rename to a name that already exists on the server replaces that other
  file without a word;
- **medium**: a download over an existing local file (after "Overwrite? Yes") writes into the
  file itself - when the download fails the file is deleted and nothing is left.

## User Scenarios & Testing

### User Story 1 - An upload asks before it replaces a file on the server (Priority: P1)

Copying a local file to a server directory that already holds a file of that name: the user is
asked (Yes / No / Cancel = skip the rest), as a download already asks for a local file. No = the
server's file stays.

**Independent Test**: against the test container: upload `report.txt` into a directory that
holds another `report.txt`; answer No - the server's content is unchanged; answer Yes - it is
the new content.

### User Story 2 - A file is replaced only by a complete new one (Priority: P1)

Whatever is being replaced - a file on the server by an upload, a local file by a download -
keeps its old content until the new content has arrived whole. A transfer that fails or is
cancelled leaves the old file as it was and no torso under its name.

**Independent Test**: an upload and a download over an existing file, cut in the middle (the
test seam of the probe): the old content is still there afterwards, byte for byte.

**Acceptance Scenarios**:

1. **Given** an upload over an existing server file fails in the middle, **Then** the server's
   file has its old content and no partial file with its name exists.
2. **Given** a new file is uploaded and the transfer fails, **Then** no file of that name
   appears on the server.
3. **Given** a download over an existing local file fails, **Then** the local file has its old
   content.
4. **Given** the transfers succeed, **Then** the files have the new content, and a replaced
   server file keeps its permission bits.

### User Story 3 - Quick Rename never lands on another file (Priority: P1)

Renaming to a name that already exists in the directory is refused with a message that says
so; both files stay as they were.

**Independent Test**: F2 on `a.txt`, new name `b.txt` (exists): message; `a.txt` and `b.txt`
both still there with their own content.

### User Story 4 - A move to the server removes a local file only after its upload is confirmed (Priority: P1)

(Same review, medium.) A move to the server uploaded a tree and then deleted the local tree by
listing it again: whatever was in it at that moment was deleted - also files of a folder whose
listing had failed during the upload (nothing of it was uploaded, and that counted as success),
files that appeared meanwhile, and a whole tree of empty folders when the server refused to
create them. Now each local file is removed right after its own upload was confirmed (the
server reports the same size), and a folder when everything in it was moved - the rule the
other direction got in feature 138.

**Independent Test**: move a local tree into a server directory where one sub-directory cannot
be created: the files of that sub-directory are still on the disk; the rest is on the server
and gone from the disk.

### User Story 5 - Cloud folders are uploaded; links are skipped aloud; deep trees do not crash (Priority: P2)

(Same review, medium.) A folder that Windows marks as a reparse point was skipped without a
word and the operation reported success - that includes every OneDrive folder, so uploading
one sent nothing. Only folders that are links to another place (junctions, directory symbolic
links) are skipped now, and the user is told once; cloud folders are uploaded like any other.
A local tree about 90 levels deep overflowed the stack; the per-level memory no longer lives
on the stack.

### Edge Cases

- The target on the server is a symbolic link: the upload writes through the link as before
  (replacing the link itself by a file would change what it points to).
- A directory in which the account may write an existing file but not create one: the upload
  falls back to writing in place (after the question), as before.
- A rename that only changes the case of a name on a case-insensitive server.
- A server without the atomic replace operation.

## Requirements

- **FR-001**: An upload MUST NOT replace an existing server file without the user's consent.
- **FR-002**: A replaced file (either side) MUST keep its previous content until the new
  content is complete; an incomplete transfer MUST NOT leave a partial file under the final
  name. Where the server or the directory does not allow that, the old behaviour is used only
  after the question, and this is recorded.
- **FR-003**: Quick Rename MUST NOT replace an existing file or directory.
- **FR-004**: The new upload's completeness MUST be confirmed (the size the server reports
  equals the local size) before it takes the place of the old file.
- **FR-006**: A move to the server MUST remove a local source only after its own upload is
  confirmed complete, and a local folder only when everything in it was moved; a folder that
  could not be listed or created remotely is a failure, never "nothing to do".
- **FR-007**: A skipped link folder MUST be reported; a cloud-provider folder MUST be uploaded.
- **FR-005**: No new texts for translation (the questions follow the existing English ones of
  this plug-in); no interface change.

## Success Criteria

- **SC-001**: Each row of the probe ends with the server's and the disk's content as stated,
  compared by content; before the fix the same rows show the replaced / lost content.
- **SC-002**: The rows of 133 / 137 / 138 still pass.

## Assumptions

- The questions are English texts in the plug-in's existing style (its overwrite question is
  an untranslated literal today); translating them needs new strings and is not part of this.
