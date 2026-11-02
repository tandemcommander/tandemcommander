---
title: Pack Overwrite into an archive reached through a symbolic link replaces the link
type: bug
status: open
severity: 3
area: archives
source: review:399
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Pack Overwrite into an archive reached through a symbolic link replaces the link

## Problem

When the name in the Pack dialog is a file symbolic link to an existing archive (`a.zip` ->
`D:\real\a.zip`) and the user answers the "add into existing archive or overwrite" question with
Overwrite, the core moves the *link* aside (feature 176) and the packer writes a new plain file
under the link's name: the link is gone (a plain archive in its place) and the real archive the
link led to keeps its old content. A related corner in the ZIP plug-in: a cancelled or failed pack
into a zero-length archive deletes `ZipName` - when that name is a link, the link is deleted and
the empty real file stays.

## Evidence

Review of feature 399 (`specs/399-zip-symlink-archive/fix-log.md`, *Review*, review 1, NOTE 2),
read at `d93b1b2d`, not reproduced by a probe:

- `src/fileswn7.cpp` - the Pack "Overwrite" branch (`msgBoxRed == IDNO`, comment "feature 176:
  aside, not deleted"): `SalMoveFileEx(fileBuf, overwriteAside, MOVEFILE_REPLACE_EXISTING)` renames
  the name itself (the link), then the packer creates a new file under that name.
- `src/plugins/zip/add.cpp` - `CZipPack::PackNormal`, the `ZeroZip && (ErrorID || UserBreak ||
  NothingToDo)` branch: `DeleteFileU8(ZipName)`.

Feature 399 fixed only adding to and deleting from an archive through a link (the update with the
temporary working file).

## Expected

Overwrite through a link either writes the new archive as the real file the link leads to (the
link stays a link) or says clearly that it cannot - never turns the link into a plain file
silently. A cancelled pack into an empty archive reached through a link removes nothing the user
did not create.

## Notes

- Not verified on the build: the reviewer read the code; measure first with a probe in the style of
  `specs/399-zip-symlink-archive/probe/zipsymlink_probe.ps1` (an "overwrite" row).
- Whether "overwrite" of a link name should mean the link or the target is a product question; the
  conservative reading of 399's item ("never replaces the link by a plain file") points at the
  target.
- Severity 3: no content is lost (the old real archive and the moved-aside link are kept), but the
  result is not what the user expects and the link is broken.

## Log

- 2026-11-02 — created (source review:399)
- 2026-11-02 — related item zip-cannot-update-an-archive-reached-through-a-symbolic-link done in feature 399
- 2026-11-02 — moved to Next position 85
