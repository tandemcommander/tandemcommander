# Implementation Plan: a read error answered Skip never loses the member being replaced (feature 113)

**Branch**: `113-zip-read-error-skip` (from `112-cache-pending-edit`, 18dad50c) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre113`, binaries only, = HEAD). The route and every way a replacing file ends "not stored", per mode, by code reading (`research.md` 1-3); the 7-Zip plug-in's update path (5); the probe's lock premise measured without the GUI (7). GUI measurements of the build before: pending (the maintainer's day - no GUI) |
| S1 helpers | `src/common/salzipmember.h` (header-only, pure): `SalZipMemberSpan` (the bytes `DeleteFiles` leaves out), `SalZipCentralRecordLen`, `SalZipRelocateCentralRecord` (record byte for byte with a new local header offset; zip64 block patched, extended or appended) |
| S2 ZIP, temporary copy | `MatchFiles` records each replaced member with its owner and a copy of its central record (`CReplacedMember`, `CZipPack::Replacements`); `PackFiles` on *Skip* (open or read) calls `RestoreReplaced` - the members copied back from the untouched original to the write position, their records relocated and appended to `NewCentrDir`; any failure ends the operation (the original stays) |
| S3 ZIP, in-place | `PackNormal`: with replaced members and no temporary copy, `PackFiles` first; `DeleteReplacedAfterPack` drops the members whose file was not stored, flushes the output buffer, extends `CFile::Size`, and runs `DeleteFiles(dataEnd = end of the added files)` uninterruptible (`DeleteAfterPack`), moving the added files' offsets (`UpdateAddedOffsets`); an error there -> `Recover(true)` (= `FinishPack`, the added entries too) |
| S4 ZIP, found on the path | AES: the MAC write no longer replaces the error of a skipped / cancelled file; the progress after a *Skip* no longer reads the freed `SourFile`; `LoadCentralDirectory` clears `NewCentrDir` after freeing it (double free); `DelFiles.Add` checked |
| S5 7-Zip | `CUpdateInfo::Replaces` (an *Overwrite*); `GetStream`: Retry / Cancel only for it (also after *Skip all*), any unhandled answer aborts; a skipped file gets `CanDelete = FALSE` (a Move must not delete it) |
| S6 tests | saltests `TestZipMember113`: spans, record length, relocation cases and every combination of marked fields x block layout x old/new offset, composition into a readable archive |
| S7 probe | `probe/zipskip_probe.ps1` + `zipskip.py` (derived from 110's): 37 rows - temporary copy, encrypted adding, in-place, 7-Zip; locks held by the probe (open / byte range); written, GUI runs pending |
| S8 gates | Debug + full Release builds, saltests, strict encoding guard, sources' BOM / CRLF; records (fix-log, CHANGELOG, NEXT-WORK, the proposed CLAUDE.md entry) |

No plug-in interface change (107), no configuration change, no new string.
