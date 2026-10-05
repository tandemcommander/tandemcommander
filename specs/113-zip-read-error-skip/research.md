# Research: feature 113 - a read error answered Skip must not lose the member being replaced

Measured by reading the code at HEAD 18dad50c (branch `113-zip-read-error-skip`, on top of 112) and
by one no-GUI measurement of the probe's premise (section 7). No GUI run was allowed today (the
maintainer uses the installed program; it shares `HKCU\Software\Tandem Commander` with every probe):
the GUI measurements of the build before are part of the pending probe runs (`quickstart.md`).
Pre-change build preserved: `build\tandemcommander\Debug_x64_pre113` (incremental build of HEAD -
up to date, identical to `Debug_x64_112` - copied without `Intermediate`).

## 1. The route: F5 / F6 / an edited file packed back into a ZIP archive

`CPluginInterfaceForArchiver::PackToArchive` -> `CZipPack::PackToArchive` -> `PackNormal`
(`src/plugins/zip/add.cpp`); multi-volume and self-extracting packs go to `PackMultiVol` /
`PackSelfExtract`, which always create a NEW archive (`MatchAll`, `NewCentrDir = NULL`, no delete
list) - the delete-first order below does not exist there.

`PackNormal`, archive exists:

1. `EnumFiles2` - the files to add (`AddFiles`).
2. `LoadCentralDirectory` - the central directory in memory (`NewCentrDir`).
3. `MatchFiles` - every member with the name of an added file: the overwrite question (it opens
   the source with `GENERIC_READ`, `FILE_SHARE_READ | FILE_SHARE_WRITE` for its size and time);
   *Yes* puts the member on `DelFiles`.
4. `DeleteFiles` - the members on `DelFiles` are removed (see 2).
5. `PackFiles` - the sources are opened (`GENERIC_READ`, `FILE_SHARE_READ`) and read, one by one.
6. `FinishPack` - central directory (the remaining old records + one per stored file) and end
   record.
7. Move: `CleanUpSource` - deletes the sources marked stored (`AF_ADD` / `AF_OVERWRITE`), only when
   the operation ended without an error and without a cancel.

The two modes (`Config.BackupZip`, ZIP configuration "Use temporary copy of archive for its
modifications (recommended, crash immune)", **on by default** - `common.cpp DefConfig`):

| | temporary copy (default) | in-place (option off) |
|---|---|---|
| where the new archive is written | `TempFile`, a `Sal*.tmp` beside the archive; renamed over the archive at the end | the archive itself (`TempFile == ZipFile`) |
| `DeleteFiles` | copies the archive into `TempFile` leaving the replaced members out | compacts the archive in place: the data after each replaced member is moved down over it |
| the replaced member's bytes while `PackFiles` runs | still in the original archive, untouched until the rename | **overwritten** |
| error or cancel | `TempFile` deleted, the archive unchanged | `Recover()` / `FinishPack` write the central directory of what is left |

## 2. Every way a replacing file ends "not stored" - the build before, by code reading

`PackFiles` marks a file not stored (`AF_NOADD`) or ends the operation:

| event in `PackFiles` | code | temporary copy | in-place |
|---|---|---|---|
| the source cannot be opened (locked, vanished, access denied), answer *Skip* / *Skip all* (or an earlier *Skip all*) | `CreateCFile` -> `ERR_SKIP` -> `AF_NOADD` | **member lost** (the new archive was written without it, then renamed over the original) | **member lost** |
| a read error in the middle (I/O error, a locked range), *Skip* / *Skip all* | `Read` -> `IDS_SKIP` from `Store` / `Deflate` -> `AF_NOADD` | **member lost** | **member lost** |
| either error, *Cancel* | `IDS_NODISPLAY` -> error | archive unchanged | **member lost** (`Recover()` writes the directory without it) |
| progress *Cancel* while packing | `UserBreak` | archive unchanged | **member lost** (`FinishPack` with `UserBreak` writes the directory without it) |
| write error, low memory | error | archive unchanged | **member lost** |

110 recorded the first two rows ("Recorded, not fixed"); the in-place rows are wider than the
record: in that mode a *Cancel* (at the error or on the progress) and any error after the deletion
lose the members too.

Two more defects on the same path:

- **AES: the error of a skipped or cancelled file was overwritten.** After `Deflate` returned
  `IDS_SKIP` (or `IDS_NODISPLAY` for *Cancel*), the AES branch wrote the MAC with
  `errorID = Write(TempFile, mac, ...)` - success replaced the error with 0. So for a file added
  with AES encryption a read error answered *Skip* stored the PARTLY read file as complete (its
  sizes and CRC say otherwise - the member cannot be extracted), a replaced member was deleted
  anyway, a Move then **deleted the source** (it counts as stored), and *Cancel* went on with the
  operation instead of ending it. ZIP 2.0 encryption has no MAC and is not affected. Applies to
  every pack route (`PackFiles` is shared - also multi-volume packs with AES).
- **Use after free on the Skip path.** The `IDS_SKIP` branch computed the progress from
  `SourFile->Size - SourFile->FilePointer` after `CloseCFile(SourFile)` freed the structure (Debug:
  0xDD fill, difference 0 by coincidence; Release: whatever the heap holds -> a wrong progress
  step, no data effect).
- **Double free** (found reading `PackNormal`): `LoadCentralDirectory` freed `NewCentrDir` on a
  read error of the central directory but did not clear it, and `PackNormal` frees it again.
  Needs an I/O error reading the archive's own directory. Not driven.

Move (F6): `CleanUpSource` deletes only `AF_ADD` / `AF_OVERWRITE` sources and only after a clean
end - a skipped source is never deleted (verified by 110), except through the AES defect above.

## 3. Where the old member can still come from

- Temporary copy: the original archive (`ZipFile`) is open and unchanged until `FinishPack` and the
  rename. Its member - local header, data, data descriptor - can be copied byte for byte to the
  current end of `TempFile`; its central record (saved in `MatchFiles`, before `DeleteFiles` removes
  it from `NewCentrDir`) needs only the new local header offset. Option (b) of the brief.
- In-place: the member is gone after `DeleteFiles`. Nothing can be copied back; the order must
  change - pack first, delete after (option (a)). `PackFiles` already writes after the old data
  (`NewCentrDirOffs`, the old central directory's place) when nothing was deleted, and
  `DeleteFiles` already compacts any region; what changes is that the last moved region now holds
  the added files (their offsets in `AddFiles` move too) and ends at the end of the added data.

Two traps of the in-place order, found reading `CFile` (`common.cpp`): `Read` goes to the handle
while `Write` buffers - the last file's local header is still in the output buffer when
`PackFiles` returns; and `CFile::Size` is the size at opening (`Write` never updates it) - `Read`
refuses everything beyond it as "end of file". The compaction after packing reads exactly that
data, so the buffer is flushed and the readable size extended first.

## 4. The offset of a member put back

The central record keeps the local header offset in 32 bits, or `0xFFFFFFFF` + the zip64 extra
block (id 1; fields in the order uncompressed size, compressed size, offset, disk - only the marked
ones; APPNOTE 4.5.3). A member put back at a new place can need 64 bits where it had 32 (the
archive grew past 4 GiB before it): the field becomes the marker and the offset goes into the
zip64 block at its place, or a new block is put FIRST in the extra field - where the plug-in
writes its own (review S1: the first draft appended it, and the plug-in's `UpdateCentrDir` read the
offset of a zip64 record at extra + 4 without checking the block id - a later compaction then read
and wrote inside an AES / time-stamp / NTFS block; it now finds the block by its id,
`SalZipCentralRecordOffsetPos`, which also fixes foreign archives with zip64 not first). Everything else is kept byte for byte (AES
0x9901 block, time stamps, comments, host, attributes). `src/common/salzipmember.h`
(`SalZipRelocateCentralRecord`, `SalZipMemberSpan`), checked by saltests over every combination of
marked fields, block layouts, old/new offsets on both sides of 4 GiB.

The span of a member is counted exactly as `DeleteFiles` counts what it leaves out (local header +
name + extra + compressed size + 16 / 24 bytes of a data descriptor with signature). A descriptor
written without its optional signature (12 bytes) made `DeleteFiles` compute an end past the next
member: `moveSize` underflowed and the rest of the archive was moved shifted by 4 bytes, the offsets
updated before the error was checked (review S2) - in-place a corrupt tail; and when the member
after it on disk was an untouched one, that member was moved without its first 4 bytes, silently,
in both modes (review R1). Now refused before anything moves (format error): the end is bounded by
the next member on disk (`SalZipNextMemberOffset`).

## 5. The 7-Zip plug-in

`C7zClient::UpdateMakeUpdateList` (`src/plugins/7zip/7zclient.cpp`): an *Overwrite* puts the file on
the update list as a NEW item and leaves the archived item OFF the list. The engine opens the file
later (`CArchiveUpdateCallback::GetStream`, `update.cpp`): on an open failure the dialog offered
Retry / Skip / Skip all / Cancel; *Skip* returns `S_FALSE`, and 7-Zip 26.03 then writes nothing for
it (`7zUpdate.cpp`: `if (!inStreamSpec->Processed[subIndex]) { // we don't add file here`): **the
archived item is lost** - the same defect. Mid-read errors offer only Retry / Abort
(`CRetryableInFileStream::Read`) - Abort ends the update, the temporary archive is deleted, no loss.

A second 7-Zip defect on the same path: a file skipped in `GetStream` kept `CFileItem::CanDelete`
(TRUE for every file of a Move), and after the update the Move **deleted the source that was not
packed** - when the delete is allowed although the read open was not (a program holding the file
open with delete sharing - measured in 7 below - or a file the user may delete but not read).

The plan of 7-Zip's update is fixed before the engine runs; putting an archived item back after
`GetStream` would need a second update pass. Contained fix: a file that replaces an archived item
is offered Retry / Cancel only (also after an earlier *Skip all*); a skipped file is never deleted
by the Move.

## 6. Other routes checked

- Multi-volume, self-extracting: new archives only (section 1) - no deletion before packing;
  `RestoreReplaced` is a no-op there. SFX is unreachable in this build anyway (106).
- Delete from an archive (F8): pure deletion, unchanged.
- The core's external archivers (WinRAR console): the archiver's own update; out of scope.
- TAR and the other archive plug-ins: no packing.

## 7. The probe's premise, measured without the GUI

A 2 MB file, held by a second process (PowerShell `FileStream`), opened with `CreateFileW` the way
the plug-ins open it (`scratchpad` test, `LkT`):

| holder | ZIP overwrite question (`GENERIC_READ`, share R+W) | packing open (`GENERIC_READ`, share R) | read at 0 / at 1 MB | `DeleteFile` |
|---|---|---|---|---|
| open for ReadWrite, share ReadWrite+Delete ("open") | opens | **fails, error 32** | - | succeeds (the name goes at once) |
| open for Read, share ReadWrite+Delete, `Lock(1 MB, rest)` ("range") | opens | opens | ok / **fails, error 33** | - |

So the "open" holder lets the ZIP question pass and makes the packing fail to open (no timing
needed), the "range" holder makes the packing fail in the middle of the file, and a Move can delete
a file the packing could not open.
