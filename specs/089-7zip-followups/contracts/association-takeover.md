# Contract: taking over an association for viewing, WTF-8 plug-in converters, 7z update matching

## C1 — `AddPanelArchiver(extensions, edit = FALSE, updateExts = TRUE)`

Before the legacy processing, for the requested extensions:

1. An extension already present in a record whose unpacker is the calling
   plug-in is done (nothing is added a second time).
2. For an extension held by a record **N** whose unpacker is an external
   archiver that can never browse (`CArchiverConfig::NeverBrowses`): N's
   unpacker becomes the plug-in, its packer and extension list are kept;
   every requested extension N holds is done, and each of them is removed
   from the plug-in's other records (a record left without extensions is
   deleted).
3. Extensions still not done go through the legacy path unchanged.

Not applied when `edit` is TRUE, when `updateExts` is FALSE, to records whose
unpacker is a plug-in, or to external archivers that have a list command
(installed or not).

Step 2 is tried before step 1 for each extension, so that a record joined by
a development build of feature 087 (the plug-in's `7z;rar;r##`) is repaired.

## C2 — 7zip plug-in, configuration version 5

`AddPanelArchiver("rar;r##", FALSE, ConfigVersion >= 1 && ConfigVersion < 5)`.
Result for versions 1–3 (0.1.8), 4 (087 development: joined, or already
taken over by a new installation) and 0 (new installation): one `rar;r##`
record, unpacker = the plug-in, packer = RAR console as stored; the plug-in's
own record holds `7z` only.

This holds when a record of the RAR console archiver claims `rar` (every
configuration the program itself produced). When there is none — the user
deleted it, or gave `rar` to another plug-in or to an external archiver that
can list — nothing is taken over and the legacy path applies (C1 step 3): the
extensions join the plug-in's own first record, as in feature 087.

## C3 — `splunicode.h`

`SplWToU8`, `SplWToU8Alloc`: total for every UTF-16 input (an unpaired
surrogate → `ED A0 80` … `ED BF BF`); failure only for a too-small buffer or
no memory. `SplU8ToW`, `SplU8ToWAlloc`, `SplU8ToWExtAlloc`: accept strict
UTF-8 plus those sequences; every other malformed input fails as before. For
valid Unicode the results are byte-identical to the previous strict versions
and to the core's `SalWToU8` / `SalU8ToW`
(`specs/066-fix-surrogate-filenames/contracts/name-encoding-wtf8.md`).

## C4 — 7z update matching

`CArchiveItem::Name` holds `SalArcCleanItemPath(kpidPath)` (an empty path is
left empty); files are matched to archive items by that name. When several
archive items share the name, the file replaces the one stored under exactly
that name if there is one, else the first; the others stay. An archive
directory item matched by name stays in the archive (it used to be dropped).
