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
// Feature 107 adds the folder level: a folder copied or moved onto another path of itself
// (SalDirIsSame), a move into itself or one of its subfolders (SalDirChainHolds), and one
// hard link reached through an alias (SalSameDirEntry, SalDecideExistingTargetEx).
// Contract: specs/107-folder-alias-move/spec.md.
//
// Header-only (wide API only) so that the core, saltests and plug-ins that
// rename files on disk (renamer, pictview) share one rule. Contract:
// specs/103-same-file-delete-guard/spec.md.
//
//*****************************************************************************

#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

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
    // feature 107, read only on request (SalGetFileIdentityW's 'volumeTraits'; the folder checks):
    DWORD SnapshotTag; // 0 = the live volume; else a tag of the snapshot (a shadow-copy device or an
                       // @GMT- path component): a snapshot keeps the volume serial and the file ids
    BOOL WeakIds;      // FAT, FAT32, exFAT: the id follows the directory entry, not the object
    BOOL SnapshotUnknown; // the final NT path could not be read and the path showed no token: the
                          // snapshot test cannot tell - it must not make two folders "different"
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
// Feature 107: a tag of the snapshot a path lies in - 0 for the live volume. Two forms: the NT
// device of a volume shadow copy ("\Device\HarddiskVolumeShadowCopy12\..." - the final NT path of
// a handle, also what \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy12\... opens) and an @GMT
// token as a path component ("\\localhost\C$\@GMT-2026.10.04-12.00.00\x" - Previous Versions over
// SMB). The tag is an FNV-1a hash of the token (case-folded ASCII), never 0; two snapshots of one
// volume get two tags. Pure (saltests).
inline DWORD SalSnapshotTagHash(const WCHAR* s, int len)
{
    DWORD h = 2166136261u;
    for (int i = 0; i < len; i++)
    {
        WCHAR c = s[i];
        if (c >= L'a' && c <= L'z')
            c = (WCHAR)(c - L'a' + L'A');
        h = (h ^ (DWORD)c) * 16777619u;
    }
    return h | 1;
}

inline DWORD SalSnapshotTagFromPath(const WCHAR* path)
{
    if (path == NULL)
        return 0;
    const WCHAR* dev = L"HARDDISKVOLUMESHADOWCOPY";
    const int devLen = 24;
    for (const WCHAR* p = path; *p != 0; p++)
    {
        if (p != path && p[-1] != L'\\')
            continue; // tokens start a path component
        int i = 0;
        while (i < devLen && p[i] != 0 && (p[i] == dev[i] || (p[i] >= L'a' && p[i] <= L'z' && p[i] - L'a' + L'A' == dev[i])))
            i++;
        if (i == devLen && p[i] >= L'0' && p[i] <= L'9')
        {
            int n = devLen;
            while (p[n] >= L'0' && p[n] <= L'9')
                n++;
            if (p[n] == 0 || p[n] == L'\\')
                return SalSnapshotTagHash(p, n);
        }
        // "@GMT-YYYY.MM.DD-HH.MM.SS" (24 characters) as a whole component
        if ((p[0] == L'@') && (p[1] == L'G' || p[1] == L'g') && (p[2] == L'M' || p[2] == L'm') &&
            (p[3] == L'T' || p[3] == L't') && p[4] == L'-')
        {
            int n = 5;
            while (n < 24 && p[n] != 0 && p[n] != L'\\')
                n++;
            if (n == 24 && (p[24] == 0 || p[24] == L'\\'))
                return SalSnapshotTagHash(p, 24);
        }
    }
    return 0;
}

// Feature 107: does the file system derive its file ids from directory entries (FAT, FAT32, exFAT -
// the name GetVolumeInformation reports)? Then an equal id alone does not prove one folder.
inline BOOL SalFsNameHasWeakIds(const WCHAR* fsName)
{
    if (fsName == NULL)
        return FALSE;
    return _wcsnicmp(fsName, L"FAT", 3) == 0 || _wcsicmp(fsName, L"exFAT") == 0;
}

// Feature 107: fills SnapshotTag and WeakIds of 'id' from an open handle (final NT path, file system
// name) and from the path it was opened by (an @GMT token the SMB client may not report back)
inline void SalFileIdentityVolumeTraits(HANDLE h, const WCHAR* openedPath, CSalFileIdentity* id)
{
    id->SnapshotTag = SalSnapshotTagFromPath(openedPath);
    id->SnapshotUnknown = FALSE;
    if (h != NULL && h != INVALID_HANDLE_VALUE)
    {
        if (id->SnapshotTag == 0)
        {
            // the final NT path, any length (re-check of 107: a fixed buffer could miss a long path)
            id->SnapshotUnknown = TRUE;
            DWORD need = GetFinalPathNameByHandleW(h, NULL, 0, FILE_NAME_NORMALIZED | VOLUME_NAME_NT);
            if (need > 0 && need < 0x10000)
            {
                WCHAR* nt = (WCHAR*)malloc((need + 1) * sizeof(WCHAR));
                if (nt != NULL)
                {
                    DWORD n = GetFinalPathNameByHandleW(h, nt, need + 1, FILE_NAME_NORMALIZED | VOLUME_NAME_NT);
                    if (n > 0 && n <= need)
                    {
                        id->SnapshotTag = SalSnapshotTagFromPath(nt);
                        id->SnapshotUnknown = FALSE;
                    }
                    free(nt);
                }
            }
        }
        WCHAR fs[MAX_PATH + 1];
        if (GetVolumeInformationByHandleW(h, NULL, 0, NULL, NULL, NULL, fs, _countof(fs)))
            id->WeakIds = SalFsNameHasWeakIds(fs);
    }
}

// 'volumeTraits' (feature 107): also read SnapshotTag and WeakIds (two more queries - the folder
// checks ask for them; the file rules of 103/106 do not).
inline BOOL SalGetFileIdentityW(const WCHAR* path, BOOL linkItself, CSalFileIdentity* id, BOOL volumeTraits = FALSE)
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
        if (ok && volumeTraits)
            SalFileIdentityVolumeTraits(h, path, id);
        CloseHandle(h);
        if (ok)
            return TRUE;
    }
    WIN32_FILE_ATTRIBUTE_DATA d;
    if (GetFileAttributesExW(path, GetFileExInfoStandard, &d))
    {
        SalFileIdentityFromAttrData(&d, id);
        if (volumeTraits)
        {
            id->SnapshotTag = SalSnapshotTagFromPath(path);
            id->SnapshotUnknown = id->SnapshotTag == 0; // no handle: the device was not read
        }
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
//     name keeps the data under the source's name - legacy, as before
//     (feature 107: only when 'sameEntry' says it IS another entry);
//   - metadata differ (also: equal ids on a volume clone) or the
//     target unreadable                                               -> legacy (an
//     overwrite of the source in place is still stopped by the source's
//     open handle, as before).
//
// Feature 107 ('sameEntry', copy only): when the ids are equal and the source has more than one
// hard link, the target is either ANOTHER link of the file (another name or folder - deleting
// that name keeps the data under the source's name: the old handling) or the SAME link reached
// through an alias (\\localhost\C$, SUBST, a junction, the 8.3 spelling - the old handling asked
// "overwrite x with x?" and then failed with a sharing violation; on a server whose share modes
// are not shared between two paths of one link it would truncate the source). SalSameDirEntry
// tells them apart: sseNo -> the old handling; sseYes and sseUnknown (fail-closed) -> refuse.
// SalDecideExistingTarget (the plug-ins) passes sseNo: the behaviour of feature 103.
enum CSalSameEntry
{
    sseUnknown = -1, // the folders or the stored names could not be read
    sseNo = 0,       // another directory entry (another name or another folder)
    sseYes = 1,      // the same directory entry under another path
};

inline CSalExistingTargetAction SalDecideExistingTargetEx(BOOL copy, DWORD err, const CSalFileIdentity& src,
                                                          const CSalFileIdentity& tgt, int sameEntry)
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
            return sameEntry == sseNo ? setaLegacy : setaRefuseSame;
        return setaRefuseSame;
    }
    if (ids == simEqual || !src.Valid || !tgt.Valid || meta)
        return setaViaTempName;
    return setaLegacy;
}

inline CSalExistingTargetAction SalDecideExistingTarget(BOOL copy, DWORD err,
                                                        const CSalFileIdentity& src, const CSalFileIdentity& tgt)
{
    return SalDecideExistingTargetEx(copy, err, src, tgt, sseNo);
}

// Feature 107: does SalDecideExistingTargetEx need 'sameEntry' for this pair? Only a copy onto a
// file with the source's id, equal metadata and more than one link - the rare case that pays for
// two more identity reads and two directory look-ups.
inline BOOL SalDecideNeedsSameEntry(BOOL copy, DWORD err, const CSalFileIdentity& src, const CSalFileIdentity& tgt)
{
    return copy && (err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS) &&
           SalFileIdMatch(src, tgt) == simEqual && SalFileMetaEqual(src, tgt) && src.Links > 1;
}

// Feature 107: one directory entry or two? 'srcDir'/'tgtDir': the identities of the folders
// holding the two names (read through links); 'srcName'/'tgtName': the names AS STORED in those
// folders (FindFirstFile's cFileName - the long name, whatever spelling the path used), NULL when
// they could not be read. Two entries of one folder have different stored names; an alias path of
// one entry finds the same folder and the same stored name.
inline int SalSameDirEntry(const CSalFileIdentity& srcDir, const CSalFileIdentity& tgtDir,
                           const WCHAR* srcName, const WCHAR* tgtName)
{
    if (srcDir.SnapshotTag != tgtDir.SnapshotTag && !srcDir.SnapshotUnknown && !tgtDir.SnapshotUnknown)
        return sseNo; // a snapshot's folder and the live one (read with volumeTraits): two entries
    int dirs = SalFileIdMatch(srcDir, tgtDir);
    if (dirs == simDifferent)
        return sseNo; // two folders: two entries
    if (dirs != simEqual || srcName == NULL || tgtName == NULL)
        return sseUnknown;
    return wcscmp(srcName, tgtName) == 0 ? sseYes : sseNo;
}

// Feature 107: is the directory 'tgt' the directory 'src' - read under another path (SUBST,
// \\localhost\C$, \\127.0.0.1\C$, a mapped drive, a junction, the 8.3 or another-case spelling,
// a second server name, another Unicode spelling on a folding server)? Both identities read with
// 'volumeTraits'.
//   - one side unreadable                                   -> 'failClosed' (a move that would
//     delete the source tree passes TRUE);
//   - a snapshot against the live volume, or two snapshots   -> no: a shadow copy / Previous
//     Versions folder keeps the serial and the ids of the live one, yet restoring from it must
//     merge (independent review of 107, SF1) - only when both sides' snapshot test could tell
//     (SnapshotUnknown: then the ids decide, a "maybe" for a move);
//   - equal ids                                              -> yes - on FAT/FAT32/exFAT only with
//     equal times as well (the id follows the directory entry there);
//   - different ids                                          -> no;
//   - an id on one side only (local/SMB against WebDAV)      -> no: two file systems (otherwise a
//     re-upload into a WebDAV copy with kept folder times would be refused);
//   - no ids on both sides (WebDAV)                          -> a "maybe" when the kind and the
//     times agree AND 'pathsMatch': the two paths, resolved (a mapped drive -> UNC) and below the
//     server name (DavWWWRoot dropped), are one path up to case and Unicode normalization
//     (SalPathsBelowServerLooselyEqualU8; unresolvable -> the names) - an alias of the same server
//     (a second server name, another Unicode spelling) keeps the path, a backup in another folder
//     does not; folder times alone are equal far too often (kept times, one archive unpacked twice)
//     and do not change when a file inside changes (review SF2). A "maybe" is refused - nothing is
//     lost.
inline BOOL SalHasUsableFileId(const CSalFileIdentity& a)
{
    return a.Valid && ((a.Has128 && SalIdIsUsable(a.Id128, 16)) || (a.Has64 && SalIdIsUsable((const BYTE*)&a.Index64, 8)));
}

inline BOOL SalDirIsSame(const CSalFileIdentity& src, const CSalFileIdentity& tgt, BOOL failClosed,
                         BOOL pathsMatch = TRUE)
{
    if (!src.Valid || !tgt.Valid)
        return failClosed;
    if (src.SnapshotTag != tgt.SnapshotTag && !src.SnapshotUnknown && !tgt.SnapshotUnknown)
        return FALSE; // (a side whose snapshot test could not tell never makes them "different")
    int ids = SalFileIdMatch(src, tgt);
    if (ids == simEqual)
        return (src.WeakIds || tgt.WeakIds) ? SalFileMetaEqual(src, tgt) : TRUE;
    if (ids == simDifferent)
        return FALSE;
    if (SalHasUsableFileId(src) != SalHasUsableFileId(tgt))
        return FALSE;
    return pathsMatch && SalFileMetaEqual(src, tgt);
}

// Feature 107: is the folder a copy or move of 'src' goes INTO (the target folder T, where the
// source would become T\name) the source itself or a folder inside it? 'chain': the identities of
// T, T's parent, ... up to the root (unreadable folders left out); 'pathsMatch' (NULL = all TRUE):
// for each entry, is its path the source's path below the server name (see SalDirIsSame - used
// only without ids). Returns the index of the chain entry that is the source, or -1. A move of a
// folder into itself or into one of its subfolders cannot succeed: a rename is refused by Windows,
// and a move between two roots (an alias path is another root) copied the tree into itself and
// then deleted the source's files and folders.
inline int SalDirChainHolds(const CSalFileIdentity& src, const CSalFileIdentity* chain, int chainCount,
                            const BOOL* pathsMatch = NULL)
{
    for (int i = 0; i < chainCount; i++)
    {
        if (SalDirIsSame(src, chain[i], FALSE, pathsMatch == NULL || pathsMatch[i]))
            return i;
    }
    return -1;
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
