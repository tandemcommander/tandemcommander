# Fix log: feature 113 - a read error answered Skip never loses the member being replaced

Branch `113-zip-read-error-skip` (from `112-cache-pending-edit`, HEAD 18dad50c). Pre-change build
preserved as `build\tandemcommander\Debug_x64_pre113` (incremental build of HEAD first - up to
date, byte-identical to `Debug_x64_112` - then the binaries copied, `Intermediate` left out).
`Debug_x64_111` / `Debug_x64_112` not touched. Not committed (the coordinator commits after an
independent review).

**Working constraint today**: the maintainer used the installed program during the day, and it
shares `HKCU\Software\Tandem Commander` with every GUI probe - so **no GUI run** was made: no
`tandemcommander.exe` started, no registry import/export. The research is by code reading plus one
no-GUI measurement of the probe's premise; the probe is written and its runs are pending
(`quickstart.md`, on the maintainer's copy `Debug_x64_113`).

## T001 - measured first (code reading)

Route, both modes, every path and the analysis: `research.md`. In short:

- The premise holds and is wider. Default mode (temporary copy, `Config.BackupZip`): *Skip* /
  *Skip all* of a replacing file that cannot be opened (`CreateCFile` -> `ERR_SKIP`) or read
  (`Read` -> `IDS_SKIP` in `Store` / `Deflate`) loses the member - `DeleteFiles` had left it out of
  the new archive, which then replaces the original. *Cancel* / errors / a cancelled progress:
  the temporary copy is discarded, no loss. In-place mode (option off): the member is ALSO lost on
  *Cancel* at the error (`Recover()` writes the directory without it), on a cancelled progress
  (`FinishPack` with `UserBreak`) and on any error while packing.
- **AES (new, serious)**: `PackFiles` wrote the AES MAC with `errorID = Write(...)` AFTER `Deflate`
  returned the skip / cancel code - success replaced the error. A file added with AES that could
  not be read to the end was stored incomplete as if complete (cannot be extracted: size / CRC
  wrong), a replaced member was deleted anyway, a **Move deleted the source**, and *Cancel* went on
  with the operation. Every pack route (shared `PackFiles`).
- **Use after free**: the `IDS_SKIP` branch read `SourFile->Size - SourFile->FilePointer` after
  `CloseCFile(SourFile)` freed it (progress only).
- **Double free**: `LoadCentralDirectory` freed `NewCentrDir` on a read error without clearing it;
  `PackNormal` freed it again.
- Move: `CleanUpSource` deletes only stored sources after a clean end (110) - except via the AES
  defect.
- Multi-volume / SFX: always a new archive (`MatchAll`, no delete list) - not affected by the
  delete-first order. SFX unreachable in this build (106).
- **7-Zip plug-in, the same loss**: an *Overwrite* puts the file on 7-Zip's update plan as a new
  item and leaves the archived item OFF the plan; `GetStream` *Skip* = `S_FALSE` = 7-Zip writes
  nothing for it (`7zUpdate.cpp` "we don't add file here") - the item is gone. And a file skipped
  in `GetStream` kept `CanDelete`, so a Move deleted it although it was not packed. Mid-read errors:
  Retry / Abort only (no loss).
- Probe premise measured without the GUI (`research.md` 7): a holder opened ReadWrite with share
  ReadWrite+Delete lets the ZIP overwrite question open the file and makes the packing's open fail
  (error 32); a holder opened Read with a byte-range lock from 1 MB makes the read at 1 MB fail
  (error 33); `DeleteFile` succeeds under the first holder.
- Not reproduced in the GUI on the build before (no GUI today) - the pending pre-113 run is the
  measurement; the predictions per row are in `quickstart.md`.

## Decisions (spec.md Clarifications)

- Rule: **a member is deleted only if the file replacing it is stored** - every answer, every mode.
- Temporary-copy mode: keep the delete-first order (no extra work on the ordinary path) and **copy
  the member back** from the untouched original when its file is not stored (option (b)).
- In-place mode: the old bytes are overwritten by the compaction, so **pack first, delete after**
  (option (a)). Costs: the compaction also moves the added files (only when members are replaced);
  free space for the added files beside the members they replace until the compaction; the
  compaction after packing is uninterruptible (stopping half-way would leave old members beside
  their replacements). Gains: *Cancel*, a cancelled progress and errors while packing leave the
  old content.
- Rejected: opening every replacing source before deleting (mid-file read errors remain); always a
  temporary copy (overrides the user's setting, needs a whole copy's space); no *Skip* for
  replacing files in ZIP (dialog change; in-place *Cancel* would still lose).
- 7-Zip: the plan is fixed before the engine runs - **Retry / Cancel only** for a file that replaces
  an archived item (also after *Skip all*); a skipped file is not deleted by a Move.
- No plug-in interface change (107), no new string, no registry change.

## T003 - `src/common/salzipmember.h` (header-only, pure; BOM + CRLF)

- `SalZipMemberSpan(localNameLen, localExtraLen, compSize, flag, size, locHeaderOffs)` - the bytes
  of a member from its local header (data descriptor 16 / 24 bytes with signature, the plug-in's
  `DeleteFiles` count; `add.cpp` asserts the structure sizes equal the header's constants).
- `SalZipCentralRecordLen(rec, avail)`.
- `SalZipRelocateCentralRecord(rec, recLen, newOffs, dst, dstCap)` - the record byte for byte with a
  new local header offset: patched in the zip64 block when it is there; else in the 32-bit field
  when it fits; else the field becomes 0xFFFFFFFF and the offset goes into the zip64 block at its
  place (after marked sizes, before a marked disk) or into a new block put FIRST in the extra
  field (review S1 - first draft: appended), "version needed" raised to 4.5 (high byte kept).
- `SalZipCentralRecordOffsetPos(rec, recLen)` (review S1) - where a record keeps its local header
  offset: the 32-bit field, or the value in the zip64 block found BY ITS ID. 0 for a malformed record / zip64 block, an extra field over 64 KiB,
  or a short destination - the caller then ends the operation.

## T004 - ZIP, temporary-copy mode (`add.cpp`, `add_del.{h,cpp}`)

- `CReplacedMember` (`add_del.h`): the DelFiles entry, its owner (`CAddInfo*`), a copy of its central
  record. `CZipPack::Replacements` (owns them). `MatchFiles` records one at every *Yes* (also checks
  `DelFiles.Add` - its failure leaked the entry and counted `Replaced`).
- `PackNormal`: `ReplacedDeletedFirst = true` before the delete-first `DeleteFiles`.
- `PackFiles`, both Skip paths (open `ERR_SKIP`, read `IDS_SKIP`): `RestoreReplaced(next, &writePos)`:
  for each member of that owner - local header read from the original (`SIG_LOCALFH` checked), span
  by `SalZipMemberSpan`, record relocated to `writePos`, `NewCentrDir` grown and the record appended
  (entries +1), bytes copied with `MoveData` (original -> new archive), `writePos += span`. A partial
  copy (cancel during it) or any failure -> error -> the new archive is discarded, the original
  stays. The member lands where the skipped file's partial data began (overwrites it).

## T005 - ZIP, in-place mode (`add.cpp`, `del.cpp`)

- `PackNormal`: `packFirst = DelFiles.Count && !BackupZip && !ZeroZip` - no `DeleteFiles` before
  `PackFiles` (which then writes from the old directory's place); a `PackFiles` error -> `Recover()`
  = the old directory at its place (nothing was deleted); a cancelled progress -> `FinishPack` with
  `UserBreak` = the same.
- `DeleteReplacedAfterPack`: members whose owner is not stored are marked (`IF_KEEP_MEMBER` in the
  DelFiles copy's `InternalFlags` - cleared first: `MatchFiles` copies that field uninitialized) and
  dropped from `DelFiles`, which is re-sorted; **flush of the output buffer** (the compaction reads
  through the handle) and **`CFile::Size` extended to the end of the added data** (`Read` refuses
  anything beyond the size at opening) - both found by reading `CFile`, before any run;
  `ProgressEnableCancel(FALSE)`; `DeleteFiles(&n, NewCentrDirOffs)` with `DeleteAfterPack`; then
  `UserBreak = false`.
- `DeleteFiles(int*, QWORD dataEnd)`: the last region ends at `dataEnd` (was `CentrDirOffs`; the
  delete-from-archive and delete-first callers pass `CentrDirOffs`); with `DeleteAfterPack` a cancel
  neither stops nor sets `UserBreak`, and `UpdateAddedOffsets` moves the added files' offsets of
  the last region (they all follow the last old member).
- `Recover(bool withAdded)`: with `withAdded` (an I/O error during that compaction) = `FinishPack`
  quietly - the added files' entries are written too (best effort; old members may remain beside
  them, never the added data lost). Not driven.

## T006 - ZIP, found on the path (`add.cpp`)

- AES: the MAC is written only when `errorID == 0`; its write failure is `IDS_NODISPLAY` (was the
  raw `Write` result).
- The progress after a *Skip* uses the unread rest computed before `CloseCFile`; `SourFile = NULL`.
- `LoadCentralDirectory`: `NewCentrDir = NULL` after the free.

## T007 - 7-Zip plug-in (`structs.h`, `7zclient.cpp`, `update.cpp`)

- `CUpdateInfo::Replaces` - set by `AddFileUpdateInfo(..., true)` for an *Overwrite*, false in every
  other constructor (both list builders, the delete path).
- `GetStream`: open failure of a replacing file -> `BUTTONS_RETRYCANCEL`, shown also after *Skip all*;
  *Skip* / *Skip all* set `fi->CanDelete = FALSE`; *Cancel* and any other answer -> `E_ABORT` (the
  update ends, the temporary archive is deleted, the archive unchanged; before, an unexpected answer
  went on with an unopened stream).

## T008 - saltests `TestZipMember113`

Spans (descriptor 16 / 24, every 64-bit trigger, the 0xFFFFFFFE / 0xFFFFFFFF boundary), record
length (complete, truncated, wrong signature), relocation cases (32-bit patch leaves every other
byte; appended block with name / comment / other blocks / fixed fields kept and the exact minimum
capacity; version needed raised keeping the high byte, never lowered; marked offset without a block
or with a short block refused; malformed extra: small offset patched, large refused; trailing
3 bytes; 65,531-byte extra refused, 65,523 + 12 = 65,535 accepted), **every combination** of marked
size / compressed size / offset / disk x 4 extra layouts x old offset below / above 4 GiB x 6 new
offsets (768) read back by a reference parser written like the plug-in's `ProcessHeader` (values,
other blocks, name, comment, fixed fields, exact growth), and a composition: kept members, an added
file, a member put back - every member found by its record at its new offset with its own bytes.
saltests **14,236 -> 14,286 / 0**; after the review (S1) **14,301 / 0**.

## T009 - the probe (written, not run)

`probe/zipskip_probe.ps1` (derived from 110's `zipname_probe.ps1`; the 098 library) + `probe/zipskip.py`
(own ZIP writer: plain / ZipCrypto / AES-256 members, zip64 records, data descriptors, comments,
time-stamp blocks, Unix host; 7z through 7z.exe; own reader: structure, overlaps, local / central
names, CRC / AES MAC, sizes; Python `zipfile` as a second opinion; per member a fingerprint of its
bytes and of its central record without the offset). The probe holds the locks itself (`open`,
`range` - `research.md` 7), answers the overwrite question, the error dialog (S / A / C / R = release
then Retry / SC = Skip when offered, else Cancel; buttons recorded), the ZIP options dialog (AES-256
or ZIP 2.0 with a password) and can cancel the progress. It refuses the Default desktop (as 112's)
and another running `tandemcommander.exe`; registry backed up / restored / verified. 37 rows:
18 temporary copy, 5 encrypted adding, 11 in-place, 3 7-Zip (list and predictions in
`quickstart.md`). Helper self-tested without the GUI: make + read of every member kind (CHECK ok,
ZIPFILE ok, 7z t ok), one flipped byte detected (CRC, both readers), 7z read. Script parses with 0
errors; ASCII, CRLF.

## Gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | BUILD SUCCEEDED, 0 errors, 0 warnings |
| full Release build (`build.cmd full release`) | BUILD SUCCEEDED, 0 errors, no compiler warning (the 46 MSBuild "Remote deployment might be slow" notices of the full build), 20 plug-ins registered, 189 language modules, runtime closure OK (218 modules) - re-run after the review fixes: the same |
| saltests | **14,327 checks, 0 failed** (14,236 before; 14,286 / 14,301 / 14,323 before the review fixes) |
| `python tools\check_encoding.py --strict` | TOTAL 0 |
| touched sources | UTF-8 BOM + CRLF kept (`add.cpp`, `add_del.{h,cpp}`, `del.cpp`, `7zclient.cpp`, `update.cpp`, `structs.h`); new `salzipmember.h` BOM + CRLF; `saltests.cpp` / `.vcxproj` no BOM, CRLF; probe files ASCII + CRLF; no control characters |
| GUI probe, regressions | **PENDING** (`quickstart.md`) |

## Hostile re-read of the diff

- Every Skip path of `PackFiles` (open, read; *Skip all* and an earlier *Skip all* go the same way):
  temporary copy -> `RestoreReplaced`; in-place -> the owner `AF_NOADD`, its members dropped from
  the delete list. *Cancel* at either error: an error -> temporary copy discarded / in-place old
  directory rewritten at its place (nothing deleted). Progress cancel: same. *Retry*: unchanged.
- Several members of one owner (`Replaced` > 1, *All*): all put back / all kept.
- A member put back over a skipped file's partial data: the output buffer is flushed by `Write`
  when the position jumps back; the next file starts after the member; anything beyond is
  overwritten or cut by `SetEndOfFile`.
- In-place compaction reads data written in the same operation: flush + size, as above; its last
  region now includes the added files; their offsets follow (`UpdateAddedOffsets`), old records by
  the unchanged `UpdateCentrDir`. Old member headers are read before the compaction reaches them
  (writes stay below the next member, as before).
- Move: `CleanUpSource` unchanged; a skipped source is `AF_NOADD` -> kept; AES no longer marks an
  incomplete file stored.
- Encrypted archives: members put back verbatim (ZIP 2.0 / AES, any of 094's forms); new files'
  encryption unchanged except the AES error fix.
- Large archives: offsets over 4 GiB handled by the relocation (saltests), the in-place order
  temporarily needs the added files' space; `ZipFile` is opened as a big file.
- Temporary files: the temporary-copy mode still deletes its `Sal*.tmp` on every error / cancel
  (unchanged code); the probe reports any `Sal*.tmp` left beside an archive.
- Low memory: recording a member fails before anything is deleted; putting one back fails ->
  error -> the original stays.
- 7-Zip: replacing items can no longer be skipped; a non-replacing skip still works (*Skip all*
  stays silent for them).
- Not covered by the change (recorded): an I/O error on the archive itself during the in-place
  compaction (best effort, as in-place always was); a data descriptor without its optional
  signature makes `DeleteFiles` fail with a format error (pre-existing, archive unchanged in the
  default mode).

## Found on the way (recorded)

- The AES error swallow, the use after free and the double free above - fixed here (same path).
- `DeleteFiles` assumes a data descriptor WITH its optional signature (16 / 24 bytes). A member
  written without it (12 bytes, allowed by APPNOTE): worse than first recorded (review S2) - the
  computed end passed the next member, `moveSize` underflowed, `MoveData` copied the rest chunk by
  chunk shifted by 4 bytes, and the offsets were updated before the error was checked; in-place,
  `Recover()` then wrote a directory with every later member (now also the added files) off by 4.
  The temporary-copy mode kept the original. And when the next member ON DISK was an untouched one
  (`{x, y}`, x replaced or deleted), the old guard idea - the next DELETED member - let it through:
  y was moved without its first 4 bytes and its record pointed 4 bytes before its data, silently,
  in BOTH modes (the corrupted copy replaced the original). **Guard added** (review S2 + R1): the
  member's computed end must not pass the next member on disk - the smallest offset above it in
  `NewCentrDir` (still original there: earlier regions only changed offsets below it), or the old
  central directory (`SalZipNextMemberOffset`, pure, saltests; it fails closed - an unreadable
  record or a truncated directory refuses too) - else a format error BEFORE anything moves, nothing
  changed.
  Such a member still cannot be replaced or deleted (an error, nothing changed); handling 12-byte
  descriptors is a NEXT-WORK candidate.
- `ProcessHeader` (`common.cpp`) compares `LocHeaderOffs + ExtraBytes` with 0xFFFFFFFF, so a zip64
  offset is missed when `ExtraBytes` is not 0 - unreachable when packing (`CheckForExtraBytes`
  refuses such archives for modification). Recorded only.
- `tools/run_on_hidden_desktop.ps1`'s usage comment still holds the control bytes 110 recorded.

## Code-only review: ACCEPT pending GUI, once S1 fixed - applied

- **S1 (harness-confirmed by the reviewer)**: the relocation APPENDED a new zip64 block at the end of
  the extra field, but the plug-in's own `UpdateCentrDir` (`del.cpp`) assumed the zip64 block is
  the FIRST one (what `WriteCentralHeader` writes) and read the offset at extra + 4 without checking
  the id. A member put back above 4 GiB with other blocks (the plug-in's AES 0x9901, Info-ZIP UT/ux,
  NTFS 0x000a) was broken by any later F5-replace / F8 of an earlier member (stale offset, or the new
  offset written into its AES block - unextractable). Fixed both ways: the new block goes FIRST
  (`insertAt = 0`), and `UpdateCentrDir` finds the block by its id (`SalZipCentralRecordOffsetPos`,
  unaligned access by `memcpy`) - also correct for foreign archives that put zip64 after another
  block (before: read and wrote inside that block). The only zip64-offset reader of the plug-in
  besides `ProcessHeader` (which already searched by id). saltests: the appended case now checks the
  block is first and the others follow unchanged; a member with NTFS + AES blocks put back at 5 GiB
  read by the new helper AND the transcribed pre-113 `UpdateCentrDir` (same position), moved down by
  a delta with the AES block intact; a foreign record (zip64 after AES, with and without marked
  sizes) where the old reader looks inside the AES block and the helper finds the value; unmarked /
  no block / short block / incomplete; the 768-combination loop checks the helper's position too.
- **S2**: guard in `DeleteFiles` (see "Found on the way").
- **N1**: `DeleteFiles` updated the directory (`UpdateCentrDir`, `UpdateAddedOffsets`) even when
  `MoveData` failed - now only after a successful move. In-place, a failure on the first block
  (nothing written) now leaves a consistent directory; a failure in the middle of a region is best
  effort as before (part of the region moved).
- **N2 (recorded)**: `SalZipMemberSpan` decides 16 / 24 descriptor bytes as `DeleteFiles` does (24
  only when a size or the offset needs 64 bits); a writer that uses a 24-byte zip64 descriptor for
  a small entry would be cut by 8 bytes - by `DeleteFiles` too (the S2 guard then refuses when the
  next member follows directly).
- **Re-check (ACCEPT) - R1**: the guard bounds by the next member ON DISK, not the next deleted one
  (see "Found on the way"); `SalZipCentralRecordOffset` + `SalZipNextMemberOffset` in
  `salzipmember.h`; saltests: out-of-order directory, zip64 offset, a broken record passed over,
  truncated directory, the `{x, y}` case refused (the old bound let it through), a member with its
  signature accepted exactly. **N-a**: `SalZipCentralRecordOffsetPos` / `SalZipRelocateCentralRecord`
  refuse `recLen` < 46 (they read `rec + 42` / `rec + 28` of a 0-length buffer; unreachable from the
  callers). **N-b**: `UpdateCentrDir` never adjusts a record whose offset field is the zip64 marker
  without a value (it could write 0xFFFFFFFF - delta into the 32-bit field; pre-existing, already
  broken records). Debug 0 / 0, saltests **14,323 / 0**, guard 0, full Release BUILD SUCCEEDED (same
  notices, 20 plug-ins, 189 modules, closure OK).
- **Re-check 2 (ACCEPT) - NIT 1**: the bound fails CLOSED: `SalZipNextMemberOffset` returns false
  ("unknown") for a truncated directory or a record whose offset cannot be read (skipping it could
  only enlarge the bound), and `DeleteFiles` then refuses with a format error before anything
  moves. saltests: truncated directory (also when the nearer member was already seen), an
  unreadable record after / before the members, NULL with a length, an empty directory (limit).
  **NIT 2 (recorded, performance)**: the guard walks the central directory once per deleted member,
  as `UpdateCentrDir` already does - about n x d for n records and d deleted members; one sorted
  offset array with bisection would serve both (NEXT-WORK). Debug 0 / 0, saltests **14,327 / 0**,
  guard 0, full Release BUILD SUCCEEDED (same notices, 20 plug-ins, 189 modules, closure OK).
- **N3**: `CUpdateInfo::Replaces` has a default member initializer (`= false`).
- **N4 (recorded, the spec accepts it)**: in the 7-Zip plug-in a replacing file that cannot be opened
  can no longer be skipped - the user must make it readable (*Retry*) or *Cancel* the whole update.
- Gates after the fixes: Debug build 0 errors / 0 warnings; saltests 14,301 / 0; strict guard 0;
  full Release build BUILD SUCCEEDED, 0 errors, no compiler warning (46 "Remote deployment"
  notices), 20 plug-ins, 189 language modules, runtime closure OK. The pending GUI commands are
  unchanged (no probe row reaches 4 GiB; S1 is covered by saltests).

## Pending (GUI, after 18:00 - exact commands in `quickstart.md`)

1. `zipskip_probe.ps1` on `Debug_x64_113` (expected: every row PASS; progress rows may be NOT
   DRIVEN) and on `Debug_x64_pre113` (predicted failures in `quickstart.md`).
2. Regressions on `Debug_x64_113`: 110 `zipname_probe.ps1` (42 / 0), 106 `packself_probe.ps1`
   (70 / 0 / 4), 094 `zip_gui_probe.ps1` (56 / 1, X1).
3. Registry SHA-256 prefix `1AB614304771DBE0` before / after each run.

Committed after the code-only reviews (S1, R1 and the fail-closed bound accepted) with the GUI
runs still owed; the build of this commit is preserved as `build\tandemcommander\Debug_x64_113`
(zip.spl 09:42:47) and the evening runs use it. Results and any fix follow in a separate commit.

## CLAUDE.md entry

Proposed for "Recent Changes" (plain text):

- 113-zip-read-error-skip: **a file that cannot be read while it is added
  into an archive no longer costs the member it replaces.** The 110 note,
  measured by code reading (no GUI that day) and wider: the ZIP plug-in's
  `DeleteFiles` left the replaced members out BEFORE `PackFiles` read the new
  files, so *Skip* / *Skip all* of a source that could not be opened or read
  lost the member; with "temporary copy" off also *Cancel*, a cancelled
  progress and any error while packing.
  - **Rule**: a member is deleted only if the file replacing it is stored.
    Temporary-copy mode (default): `MatchFiles` records each replaced
    member with its owner and central record (`CReplacedMember`), and
    `RestoreReplaced` copies it back from the untouched original byte for
    byte, the record relocated (`src/common/salzipmember.h`:
    `SalZipMemberSpan`, `SalZipRelocateCentralRecord` - zip64 block patched,
    extended or put FIRST; review S1: the plug-in's `UpdateCentrDir`
    assumed zip64 is the first block - now found by id,
    `SalZipCentralRecordOffsetPos`). In-place mode: pack first, then
    `DeleteReplacedAfterPack` compacts away only the stored files' members
    (`DeleteFiles(dataEnd)` + `DeleteAfterPack`, the added files' offsets
    moved, uninterruptible). Trap: the compaction reads what was just
    written through the same `CFile` - flush the output buffer and extend
    `CFile::Size` (writes never update it) first.
  - Also fixed: AES - the MAC write replaced the error of a skipped or
    cancelled file (stored incomplete, a Move deleted the source, Cancel went
    on); a use after free of `SourFile` on the Skip path; a double free of
    `NewCentrDir`; `DeleteFiles` refuses a member whose end passes the next
    member ON DISK (`SalZipNextMemberOffset`; a 12-byte data descriptor moved
    the rest of the archive 4 bytes, or silently cut the first 4 bytes of the
    untouched member after it, both modes) and
    updates offsets only after a successful move. 7-Zip plug-in, the same loss (an *Overwrite* leaves the
    item off 7-Zip's plan, `S_FALSE` drops the file): Retry / Cancel only for
    a replacing file (`CUpdateInfo::Replaces`), and a file skipped in a Move
    is no longer deleted (`CanDelete`).
  - saltests 14,236 -> 14,327. Performance note: the bound and `UpdateCentrDir`
    walk the directory once per deleted member (n x d). Interface stays 107, no string, no registry
    change. Probe `probe/zipskip_probe.ps1` + `zipskip.py` (37 rows: locks
    held by the probe - "open" / byte-range; temporary copy, AES adding,
    in-place, 7z) written, **GUI runs pending**. Records:
    `specs/113-zip-read-error-skip/fix-log.md`.
