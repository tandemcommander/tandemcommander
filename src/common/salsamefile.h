// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salsamefile.h
//
// Feature 103: "the target already exists" may name the SOURCE ITSELF.
//
// A rename, move or copy that meets an existing target used to decide by the
// two NAMES whether the target is another file: if the names differed, the
// target was deleted (or opened for overwriting) and the operation retried.
// On a server whose name rule folds more than Windows' - a macOS or Samba
// server that treats the NFC and NFD spellings of a name as one, a WebDAV
// server reached under two host names, any alias path - the "existing
// target" can be the source under another spelling, and deleting it deleted
// the user's file. The names cannot tell; the file system's identity can.
//
// This header holds:
//   - CSalFileIdentity: what identifies a file (volume serial + file id, the
//     128-bit id where the file system has one) plus the metadata used when no
//     id is available (size, times, attributes) and the link count;
//   - the pure comparison and the pure decision (saltests cover them);
//   - the temporary-name route for a rename/move: source -> unique temporary
//     name in the source's folder -> target. If the target name disappears
//     with the source out of the way, it WAS the source and the rename is
//     done; if it is still there, it is another file (or another hard link)
//     and the source is renamed back for the old handling. The route checks
//     itself, so it is safe even when the identity is unknown.
//
// Header-only (wide API only) so that the core, saltests and plug-ins that
// rename files on disk (renamer, pictview) share one rule. Contract:
// specs/103-same-file-delete-guard/spec.md.
//
//*****************************************************************************

#include <windows.h>
#include <stdio.h>
#include <string.h>

// FILE_ID_INFO / FileIdInfo exist in the SDK headers only for _WIN32_WINNT >=
// 0x0602; the product builds for 0x0601. The layout and the class value are
// ABI-stable (documented since Windows 8), so they are mirrored here.
struct CSalFileIdInfo
{
    ULONGLONG VolumeSerialNumber;
    BYTE FileId[16];
};
#define SAL_FILE_ID_INFO_CLASS ((FILE_INFO_BY_HANDLE_CLASS)18) // FileIdInfo

struct CSalFileIdentity
{
    BOOL Valid;  // at least the metadata below was read
    BOOL Has64;  // Vsn32 + Index64 (GetFileInformationByHandle)
    BOOL Has128; // Vsn64 + Id128 (FileIdInfo; ReFS needs the 128 bits)
    DWORD Vsn32;
    ULONGLONG Index64;
    ULONGLONG Vsn64;
    BYTE Id128[16];
    DWORD Links; // number of hard links; 0 = unknown
    DWORD Attr;
    ULONGLONG Size;
    FILETIME CTime; // creation
    FILETIME MTime; // last write
};

inline void SalFileIdentityClear(CSalFileIdentity* id)
{
    memset(id, 0, sizeof(*id));
}

// fills 'id' from an open handle (any access, also FILE_READ_ATTRIBUTES only or overlapped)
inline BOOL SalFileIdentityFromHandle(HANDLE h, CSalFileIdentity* id)
{
    SalFileIdentityClear(id);
    BY_HANDLE_FILE_INFORMATION bhfi;
    if (h == NULL || h == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(h, &bhfi))
        return FALSE;
    id->Valid = TRUE;
    id->Has64 = TRUE;
    id->Vsn32 = bhfi.dwVolumeSerialNumber;
    id->Index64 = ((ULONGLONG)bhfi.nFileIndexHigh << 32) | bhfi.nFileIndexLow;
    id->Links = bhfi.nNumberOfLinks;
    id->Attr = bhfi.dwFileAttributes;
    id->Size = ((ULONGLONG)bhfi.nFileSizeHigh << 32) | bhfi.nFileSizeLow;
    id->CTime = bhfi.ftCreationTime;
    id->MTime = bhfi.ftLastWriteTime;
    CSalFileIdInfo fid;
    if (GetFileInformationByHandleEx(h, SAL_FILE_ID_INFO_CLASS, &fid, sizeof(fid)))
    {
        id->Has128 = TRUE;
        id->Vsn64 = fid.VolumeSerialNumber;
        memcpy(id->Id128, fid.FileId, sizeof(id->Id128));
    }
    return TRUE;
}

// metadata only (no ids): used when the file cannot be opened even for its attributes
inline void SalFileIdentityFromAttrData(const WIN32_FILE_ATTRIBUTE_DATA* d, CSalFileIdentity* id)
{
    SalFileIdentityClear(id);
    id->Valid = TRUE;
    id->Attr = d->dwFileAttributes;
    id->Size = ((ULONGLONG)d->nFileSizeHigh << 32) | d->nFileSizeLow;
    id->CTime = d->ftCreationTime;
    id->MTime = d->ftLastWriteTime;
}

// reads the identity of 'path' (wide, may carry the \\?\ prefix). 'linkItself': TRUE for a
// rename/move (MoveFile renames a symbolic link itself, so the link is what is compared),
// FALSE for a copy (the data is read and written through links). Opens with
// FILE_READ_ATTRIBUTES only - such an open ignores share modes and never starts a download
// on WebDAV - and with FILE_FLAG_BACKUP_SEMANTICS so that directories open too.
inline BOOL SalGetFileIdentityW(const WCHAR* path, BOOL linkItself, CSalFileIdentity* id)
{
    SalFileIdentityClear(id);
    if (path == NULL)
        return FALSE;
    HANDLE h = CreateFileW(path, FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING,
                           FILE_FLAG_BACKUP_SEMANTICS | (linkItself ? FILE_FLAG_OPEN_REPARSE_POINT : 0), NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        BOOL ok = SalFileIdentityFromHandle(h, id);
        CloseHandle(h);
        if (ok)
            return TRUE;
    }
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (GetFileAttributesExW(path, GetFileExInfoStandard, &d))
    {
        SalFileIdentityFromAttrData(&d, id);
        return TRUE;
    }
    return FALSE;
}

//*****************************************************************************
//
// pure rules
//

enum CSalIdMatch
{
    simUnknown = -1, // no usable file id on one side (WebDAV reports 0, some servers too)
    simDifferent = 0,
    simEqual = 1,
};

inline BOOL SalIdIsUsable(const BYTE* p, int len) // neither all zero nor all ones
{
    BOOL zero = TRUE, ones = TRUE;
    for (int i = 0; i < len; i++)
    {
        if (p[i] != 0)
            zero = FALSE;
        if (p[i] != 0xFF)
            ones = FALSE;
    }
    return !zero && !ones;
}

// Are the two the same file by the file system's own identity?
inline int SalFileIdMatch(const CSalFileIdentity& a, const CSalFileIdentity& b)
{
    if (!a.Valid || !b.Valid)
        return simUnknown;
    if (a.Has128 && b.Has128 && SalIdIsUsable(a.Id128, 16) && SalIdIsUsable(b.Id128, 16))
        return (a.Vsn64 == b.Vsn64 && memcmp(a.Id128, b.Id128, 16) == 0) ? simEqual : simDifferent;
    if (a.Has64 && b.Has64 && SalIdIsUsable((const BYTE*)&a.Index64, 8) && SalIdIsUsable((const BYTE*)&b.Index64, 8))
        return (a.Vsn32 == b.Vsn32 && a.Index64 == b.Index64) ? simEqual : simDifferent;
    // no usable ids, but two different volume serials still tell two files apart
    if (a.Has64 && b.Has64 && a.Vsn32 != 0 && b.Vsn32 != 0 && a.Vsn32 != b.Vsn32)
        return simDifferent;
    return simUnknown;
}

inline ULONGLONG SalFileTimeSeconds(const FILETIME& t)
{
    return (((ULONGLONG)t.dwHighDateTime << 32) | t.dwLowDateTime) / 10000000;
}

// Could the two be one file by what is visible without an id? Same kind (file/directory),
// same size (files), the same last-write and creation second (compared in whole seconds:
// a server may round; a missing creation time - 0 - is not compared). Two different files
// can match (equal size, written in the same second): the callers use this only to decide
// that something MAY be the same file, never that it is another one to delete.
inline BOOL SalFileMetaEqual(const CSalFileIdentity& a, const CSalFileIdentity& b)
{
    if (!a.Valid || !b.Valid)
        return FALSE;
    if ((a.Attr & FILE_ATTRIBUTE_DIRECTORY) != (b.Attr & FILE_ATTRIBUTE_DIRECTORY))
        return FALSE;
    if ((a.Attr & FILE_ATTRIBUTE_DIRECTORY) == 0 && a.Size != b.Size)
        return FALSE;
    if (SalFileTimeSeconds(a.MTime) != SalFileTimeSeconds(b.MTime))
        return FALSE;
    ULONGLONG ca = SalFileTimeSeconds(a.CTime), cb = SalFileTimeSeconds(b.CTime);
    if (ca != 0 && cb != 0 && ca != cb)
        return FALSE;
    return TRUE;
}

enum CSalExistingTargetAction
{
    setaLegacy,      // the old handling: ask, then delete or overwrite the target
    setaViaTempName, // rename/move: the target may be the source - rename through a temporary name
    setaRefuseSame,  // copy (and a move done as copy + delete): the target is the source - refuse
};

// What to do when an operation from 'src' meets an existing target 'tgt' (err = the error
// of MoveFile / CreateFile CREATE_NEW). 'copy': the data is copied into the target (a
// copy, or a move between two roots, which deletes the source afterwards); otherwise the
// source is renamed onto the target.
//   rename/move (the temporary-name route checks itself, so it is taken whenever the
//   target is not clearly another file - it costs two renames on the rare "exists" path):
//   - the same id, or an identity that cannot be read                 -> temporary name;
//   - equal metadata, whatever the ids say (a file system that derives
//     ids from the path - some FUSE/WinFsp/Dokan mounts - gives two
//     spellings of one file two ids)                                  -> temporary name;
//   - different metadata and not the same id                          -> legacy;
//   copy (an overwrite in place truncates the source):
//   - known to be another file (different ids or volumes)             -> legacy;
//   - the same file (ids and metadata, or no ids and equal metadata)  -> refuse,
//     except another hard link of it (link count > 1): deleting that
//     name keeps the data under the source's name - legacy, as before;
//   - metadata differ (also: equal ids on a volume clone) or the
//     target unreadable                                               -> legacy (an
//     overwrite of the source in place is still stopped by the source's
//     open handle, as before).
inline CSalExistingTargetAction SalDecideExistingTarget(BOOL copy, DWORD err,
                                                        const CSalFileIdentity& src, const CSalFileIdentity& tgt)
{
    if (err != ERROR_ALREADY_EXISTS && err != ERROR_FILE_EXISTS)
        return setaLegacy;
    int ids = SalFileIdMatch(src, tgt);
    BOOL meta = SalFileMetaEqual(src, tgt);
    if (copy)
    {
        if (ids == simDifferent || !meta)
            return setaLegacy;
        if (ids == simEqual && src.Links > 1)
            return setaLegacy;
        return setaRefuseSame;
    }
    if (ids == simEqual || !src.Valid || !tgt.Valid || meta)
        return setaViaTempName;
    return setaLegacy;
}

// A symbolic link (or junction) renamed onto the very file (folder) it points at: a rename
// compares the link itself (linkItself), so the link and its target look like two files - and
// the old overwrite deleted the target and moved the link into its name, a link to itself:
// the data was gone (second review of feature 103, both builds). 'srcThroughLink' is the
// source read THROUGH the link (linkItself FALSE), 'tgt' the target as the rename sees it.
// TRUE: the move must be refused ("Cannot move a file to itself.").
inline BOOL SalLinkPointsAtTarget(const CSalFileIdentity& srcLinkItself, const CSalFileIdentity& srcThroughLink,
                                  const CSalFileIdentity& tgt)
{
    if (!srcLinkItself.Valid || (srcLinkItself.Attr & FILE_ATTRIBUTE_REPARSE_POINT) == 0)
        return FALSE; // not a link
    int ids = SalFileIdMatch(srcThroughLink, tgt);
    if (ids == simEqual)
        return TRUE;
    return ids == simUnknown && SalFileMetaEqual(srcThroughLink, tgt);
}

// Feature 106: a pack operation is about to write its output - the archive, a volume of a
// multi-volume archive, the self-extractor - over the existing file 'out', or (the core's Pack
// dialog, "Overwrite") to delete it first. Is that file one of the files the same operation
// packs ('src', read through links)? Then the write would truncate or delete a source before or
// after it is read: the archive would hold garbage, and a Move would delete the rest. TRUE for
// the same id - also another hard link of the source, whose data a truncation reaches - and,
// where the file system gives no usable ids, for equal metadata (a "maybe" counts as yes: the
// operation is refused and nothing is lost).
inline BOOL SalPackOutputIsSource(const CSalFileIdentity& out, const CSalFileIdentity& src)
{
    int ids = SalFileIdMatch(out, src);
    if (ids == simEqual)
        return TRUE;
    return ids == simUnknown && SalFileMetaEqual(out, src);
}

// Feature 106: the same question for one selected item of the Pack dialog. 'isDir': the item is
// a directory, whose whole tree is packed - then the archive is a source when the item is one of
// the archive's folders ('ancestors': the identities of the archive's parent, its parent, ... up
// to the root). A file item is a source when it is the archive itself.
inline BOOL SalPackTargetInSelection(const CSalFileIdentity& archive, const CSalFileIdentity* ancestors,
                                     int ancestorCount, const CSalFileIdentity& item, BOOL isDir)
{
    if (!isDir)
        return SalPackOutputIsSource(archive, item);
    for (int i = 0; i < ancestorCount; i++)
    {
        if (SalPackOutputIsSource(ancestors[i], item))
            return TRUE;
    }
    return FALSE;
}

//*****************************************************************************
//
// the temporary-name route
//

enum CSalViaTempResult
{
    svtDone,          // renamed: source -> temporary name -> target
    svtTargetIsOther, // the target name outlived the source's: another file or link; the source is back
    svtFailed,        // not renamed, the source is back under its name; *err holds the reason
    svtLeftAtTemp,    // not renamed and the source could not be renamed back: it is at 'tmpName'
};

// The temporary name: "sal" + 3 hex digits (8.3-compliant, so no short name is generated)
// in the folder of 'src'. Returns FALSE when 'tmpName' is too small.
inline BOOL SalBuildTempSibling(const char* src, DWORD num, char* tmpName, int tmpNameSize)
{
    const char* slash = strrchr(src, '\\');
    int dirLen = slash == NULL ? 0 : (int)(slash - src) + 1;
    if (dirLen + 7 + 1 > tmpNameSize)
        return FALSE;
    memcpy(tmpName, src, dirLen);
    sprintf(tmpName + dirLen, "sal%03X", (unsigned)(num & 0xFFF));
    return TRUE;
}

// TMove: BOOL move(const char* from, const char* to, DWORD* err) - a MoveFile without
// MOVEFILE_REPLACE_EXISTING (it never replaces anything). 'seed' picks the first
// temporary name; at most 4096 names are tried.
template <class TMove>
inline CSalViaTempResult SalRenameViaTempName(const char* src, const char* tgt, TMove move,
                                              char* tmpName, int tmpNameSize, DWORD seed, DWORD* err)
{
    *err = NO_ERROR;
    const char* srcName = strrchr(src, '\\');
    srcName = srcName == NULL ? src : srcName + 1;
    const char* tgtName = strrchr(tgt, '\\');
    tgtName = tgtName == NULL ? tgt : tgtName + 1;
    BOOL away = FALSE;
    for (DWORD i = 0; i < 0x1000; i++)
    {
        if (!SalBuildTempSibling(src, seed + i, tmpName, tmpNameSize))
        {
            *err = ERROR_FILENAME_EXCED_RANGE;
            return svtFailed;
        }
        // never the source's or the target's own name: a "rename" of the source onto its own
        // name would succeed without moving it out of the way, and the check below would then
        // take the source for another file
        const char* cand = strrchr(tmpName, '\\');
        cand = cand == NULL ? tmpName : cand + 1;
        if (_stricmp(cand, srcName) == 0 || _stricmp(cand, tgtName) == 0)
            continue;
        DWORD e = NO_ERROR;
        if (move(src, tmpName, &e))
        {
            away = TRUE;
            break;
        }
        if (e != ERROR_ALREADY_EXISTS && e != ERROR_FILE_EXISTS)
        {
            *err = e;
            return svtFailed;
        }
    }
    if (!away)
    {
        *err = ERROR_ALREADY_EXISTS;
        return svtFailed;
    }
    DWORD e2 = NO_ERROR;
    if (move(tmpName, tgt, &e2))
        return svtDone;
    DWORD e3 = NO_ERROR;
    if (!move(tmpName, src, &e3))
    {
        *err = e2;
        return svtLeftAtTemp;
    }
    if (e2 == ERROR_ALREADY_EXISTS || e2 == ERROR_FILE_EXISTS)
        return svtTargetIsOther;
    *err = e2;
    return svtFailed;
}
