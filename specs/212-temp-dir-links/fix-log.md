# Fix log: 212 - removing a temporary folder never goes through a link

Backlog (left by 197's review, `specs/NEXT-WORK.md`): `_RemoveTemporaryDir` (`src/salamdr3.cpp`)
has no reparse check.

## Read (not measured)

`RemoveTemporaryDir` / `_RemoveTemporaryDir` empty a temporary folder by walking every
subdirectory - also a directory with `FILE_ATTRIBUTE_REPARSE_POINT`. For a junction or a directory
symbolic link inside the folder the walk lists the link's TARGET and deletes its files, then
removes the link. `RemoveEmptyDirs` / `_RemoveEmptyDirs` (the folders an unpack created, removed
after it failed) walk the same way and remove the empty folders of a link's target.

Callers: the viewer and archive cache (`cache.cpp`), the external archivers' temporary folders
(`pack1.cpp` - an unpacker extracting a link from an archive into that folder), the plugin service
`RemoveTemporaryDir` (`zip.cpp`; demoplug, regedt), the unpack routes of `fileswn7.cpp`
(`RemoveEmptyDirs`).

Not driven in the program: a probe would have to plant a link into the program's own temporary
folder; it was not written in this session. The decision used is 197's, checked by `saltests`
(`SalDeleteAsDirLinkDecision`) and driven there (a junction in a folder of 780+ characters).
A step owed to a person: an archive with a directory symbolic link unpacked by an external
archiver through a temporary folder (e.g. viewing a file inside it), the link's target unchanged
afterwards.

## Work

`src/salamdr3.cpp`:
- `_RemoveTemporaryDir`: a found directory with `FILE_ATTRIBUTE_REPARSE_POINT` that
  `DeleteAsDirLink` takes for a link (feature 197, fail closed: a junction, a volume mount point, a
  symbolic link, a name surrogate, a tag that cannot be read) is removed as a link
  (`SalRemoveDirectory`), never walked; a cloud placeholder (not a name surrogate) is walked as
  before;
- `_RemoveEmptyDirs`: such a link is removed as a link, never walked (review: the old walk
  removed the link too, after emptying its target of empty folders);
- `RemoveTemporaryDir` / `RemoveEmptyDirs`: the folder passed in is checked too
  (`IsDirLinkToKeepClosed`, asked without a trailing backslash, fails closed - attributes that
  cannot be read count as a link unless the folder is not there): a link is only removed.

Build: BUILD SUCCEEDED.

## Review

Refute-first review: accept. Checked on this machine with a real junction and a real directory
symbolic link: `RemoveDirectoryW` on the `\\?\` path removes only the link (also with a trailing
backslash), the target's file kept; read-only set on a junction changes only the link (and a
read-only junction cannot be removed - `ClearReadOnlyAttr` before it is needed). `DeleteAsDirLink`
works at any length and holds no state; `continue` in the do / while goes to `SalFindNextFile`; a
cloud placeholder is still walked. Every core caller goes through these two functions
(`cache.cpp` 111 / 1579 and the start-up `SAL*.tmp` sweep, `pack1.cpp`, `salshlib.cpp:390`,
`shellsup.cpp` 1139 / 1613, `zip.cpp:866`, `fileswn7.cpp` 720 / 2246). Taken: the top-level check
fails closed (was: unreadable attributes = walked); `_RemoveEmptyDirs` removes the link as a link.
Owed (MUST, not done here): driving it in the program - the start-up sweep of `SAL*.tmp` folders
(`ClearTEMPIfNeeded`, `cache.cpp:1500`) with a junction inside one, on the build before (the
target's file deleted) and after (kept). Recorded in `specs/NEXT-WORK.md`: the ZIP self-extractor's
own `_RemoveTemporaryDir` (`selfextr.cpp:157`, the same defect, `A` calls) and the external
unpacker's walk in `pack1.cpp:632-692` that moves the extracted folder's content out (a junction
extracted from the archive - its target's content moved; rule 099). The comment of `consts.h:130`
(`SalGetFileAttributes` appending a backslash) is stale - the facade uses `\\?\`.
