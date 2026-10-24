---
title: ISO plug-in: HFS+ hard links extract as empty files, their data under iNode names
type: bug
status: open
severity: 4
area: archives
source: review:332
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: HFS+ hard links extract as empty files, their data under iNode names

## Problem

macOS stores a hard-linked file of an HFS+ volume (TN1150, *Hard Links*) as a link file record (type
`hlnk`, creator `hfs+`, empty data fork) under each of its names, and the data in a file `iNode<n>`
inside the metadata folder "<4 x U+0000>HFS+ Private Data" in the root. The ISO plug-in lists the link
records as ordinary files - so they extract as empty files under the user's names - and, because the
metadata folder itself is not listed, its `iNode<n>` files appear at the HFS+ root. Unpack then gives
the user empty files where their data should be and unexplained `iNode<n>` files; with "Delete archive
after unpacking" the image is deleted (the data is extracted, but under a name the user does not know).
Directory hard links (".HFS+ Private Directory Data\r") are not resolved either.

## Evidence

At d8e666a7 (branch 332-uniso-hfs-skipped-records): `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`
lists every file record with `fd.Size = dataFork.logicalSize` and no hard-link check (only symbolic
links: `kSymLinkCreator` / `kSymLinkFileType`); the metadata folder is `SAL_HFSREC_NOT_ENTRY`
(`src/common/salhfscatalog.h` `SalHfsCatalogRecordClass`, feature 332) and a record whose parent is not
a listed folder is listed at `rootPath` (the parent lookup over `pFolders`). Review 2 of feature 332
(`specs/332-uniso-hfs-skipped-records/fix-log.md`, *Review*): its row R2-PRIV (a folder renamed to the
metadata name) listed that folder's contents at the HFS+ root on main and on the branch. Not
reproduced with a Mac-made image (none available; WSL has no hfsplus support).

## Expected

A hard link is listed and extracted under its own name with the data of its `iNode<n>` file; the
metadata folder's `iNode<n>` files are not listed as user files (or are listed under a name that says
what they are). Directory hard links are resolved or reported.

## Notes

- Needs a Mac-made HFS+ image with hard links (a person step, or `newfs_hfs` + `ln` on macOS), or a
  crafted catalog by an extended `specs/332-uniso-hfs-skipped-records/probe/img332.py`.
- Not verified: how the core's Unpack handles two names of one inode (two extractions of the same data).

## Log

- 2026-10-24 — created (source review:332)
- 2026-10-24 — moved to Next position 27
