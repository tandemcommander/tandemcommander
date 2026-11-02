// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salsafereplace.h
//
// Feature 105: an existing file is replaced only by a new file that already
// exists in full.
//
// PictView's Save As deleted the existing file the user agreed to replace and
// then wrote the image; when the write failed - and since feature 006 it always
// failed (the built-in engine could not encode) - the file was simply gone. The
// rule here: the new content is written into a temporary file in the target's
// own folder (same volume, so the last step is a rename), and only after that
// file is complete and flushed does it take the target's place:
//   - an existing target: ReplaceFileW - one step on NTFS, and the target keeps
//     its attributes, ACL, creation time and short name. Where the file system
//     does not support it, MoveFileExW(MOVEFILE_REPLACE_EXISTING);
//   - a new target: MoveFileExW without REPLACE_EXISTING - a file that appeared
//     meanwhile is never overwritten unasked.
// Every failure keeps the target as it was (a read-only attribute cleared for
// the replace is restored) and leaves the temporary file to the caller, who
// deletes it - except the one case where the target is already gone (ReplaceFileW's
// ERROR_UNABLE_TO_MOVE_REPLACEMENT without a backup name, or a target deleted by
// someone else meanwhile): then the temporary file holds the only copy of the new
// content and is moved into place, or - if that fails too - kept and reported by
// its name, never deleted.
//
// Measured (specs/105-pictview-saveas-loss/research.md): ReplaceFileW onto a
// read-only target fails with 5, onto a target open without FILE_SHARE_DELETE
// (the WIC decoder of the shown image) with 32, onto a missing target with 2 -
// in all three cases both files are left as they were.
//
// Header-only (wide API only): PictView and saltests share it.
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

enum CSalReplaceResult
{
    srrDone,           // the target now holds the new content; the temporary file is gone
    srrFailedKept,     // nothing changed: the target (or its absence) is as it was; delete the temporary file
    srrLeftAtTemp,     // the target is gone and the new content stayed in the temporary file: report it, keep it
    srrFailedBothGone, // the target and the temporary file are both gone (a third party): report the error
};

enum CSalReplaceFailureNext
{
    srnKeepTarget,   // the target is intact: give up, the caller deletes the temporary file
    srnFallbackMove, // the file system does not do ReplaceFile: try a replacing rename
    srnFinishMove,   // the target is gone, the new content is in the temporary file: move it into place
    srnBothGone,     // nothing left to do
};

// pure: what follows a failed ReplaceFileW (err = its error), given what is left on disk
inline CSalReplaceFailureNext SalReplaceFailureNext(DWORD err, BOOL targetThere, BOOL tempThere)
{
    if (!targetThere)
        return tempThere ? srnFinishMove : srnBothGone;
    if (!tempThere)
        return srnKeepTarget; // nothing to put in place
    switch (err)
    {
    case ERROR_NOT_SUPPORTED:
    case ERROR_INVALID_FUNCTION:
    case ERROR_INVALID_PARAMETER:
    case ERROR_CALL_NOT_IMPLEMENTED:
        return srnFallbackMove;
    }
    return srnKeepTarget;
}

// "<folder of targetPath>\<prefix>XXXX.tmp": the folder part (up to and including the last
// backslash) of 'targetPath', the prefix and four hex digits of 'num'. Returns a malloc'ed
// string (NULL on no memory). Pure.
inline WCHAR* SalBuildTempNextToW(const WCHAR* targetPath, const WCHAR* prefix, DWORD num)
{
    const WCHAR* slash = wcsrchr(targetPath, L'\\');
    size_t dirLen = slash != NULL ? (size_t)(slash - targetPath) + 1 : 0;
    size_t size = dirLen + wcslen(prefix) + 4 + 4 + 1; // XXXX + ".tmp" + NUL
    WCHAR* p = (WCHAR*)malloc(size * sizeof(WCHAR));
    if (p == NULL)
        return NULL;
    memcpy(p, targetPath, dirLen * sizeof(WCHAR));
    swprintf_s(p + dirLen, size - dirLen, L"%s%04X.tmp", prefix, (unsigned)(num & 0xFFFF));
    return p;
}

// creates a new empty file next to 'targetPath' (wide, may carry \\?\) and returns it open
// for reading and writing, not shared, in '*h', its name in '*tempPath' (free() it).
// FALSE + '*err' when no such file can be created (a read-only folder: 5).
inline BOOL SalCreateTempNextToW(const WCHAR* targetPath, const WCHAR* prefix, WCHAR** tempPath, HANDLE* h, DWORD* err)
{
    *tempPath = NULL;
    *h = INVALID_HANDLE_VALUE;
    DWORD num = GetTickCount() & 0xFFFF;
    for (int i = 0; i < 0x10000; i++, num++)
    {
        WCHAR* p = SalBuildTempNextToW(targetPath, prefix, num);
        if (p == NULL)
        {
            *err = ERROR_NOT_ENOUGH_MEMORY;
            return FALSE;
        }
        HANDLE f = CreateFileW(p, GENERIC_READ | GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (f != INVALID_HANDLE_VALUE)
        {
            *tempPath = p;
            *h = f;
            return TRUE;
        }
        DWORD e = GetLastError();
        free(p);
        if (e != ERROR_FILE_EXISTS && e != ERROR_ALREADY_EXISTS)
        {
            *err = e;
            return FALSE;
        }
    }
    *err = ERROR_FILE_EXISTS;
    return FALSE;
}

// TRUE only when 'path' certainly does not exist (not found); an entry whose attributes cannot be
// read for another reason (access denied, ...) counts as present - "gone" leads to moving the new
// file in, which must never be decided on a guess
inline BOOL SalPathIsGoneW(const WCHAR* path)
{
    if (GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES)
        return FALSE;
    DWORD e = GetLastError();
    return e == ERROR_FILE_NOT_FOUND || e == ERROR_PATH_NOT_FOUND;
}

// Feature 399: a file reached through a symbolic link. ReplaceFileW onto a link's name fails (1464,
// ERROR_SYMLINK_NOT_SUPPORTED) and a replacing rename would turn the link into a plain file; the
// file to replace is the one the link leads to, and the temporary file belongs in ITS folder (same
// volume). Only a name that itself redirects to another name is followed (a name-surrogate reparse
// point that is not a folder: a file symbolic link) - a plain file, a hard link, a cloud placeholder
// or a file whose folder is reached through a junction keep their own name.

// pure: does a replace of the name with these attributes and this reparse tag (FindFirstFileW's
// dwReserved0) go to the file the name leads to?
inline BOOL SalReplaceFollowsName(DWORD attrs, DWORD reparseTag)
{
    return attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_REPARSE_POINT) != 0 &&
           (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0 && IsReparseTagNameSurrogate(reparseTag);
}

// pure: the plain form of a path GetFinalPathNameByHandleW gave with VOLUME_NAME_DOS:
// "\\?\C:\a" -> "C:\a", "\\?\UNC\srv\sh\a" -> "\\srv\sh\a"; anything else (a volume GUID path
// "\\?\Volume{...}\a", a path without the "\\?\" prefix, NULL) -> NULL. malloc'ed.
inline WCHAR* SalFinalPathPlainW(const WCHAR* finalPath)
{
    if (finalPath == NULL || wcsncmp(finalPath, L"\\\\?\\", 4) != 0)
        return NULL;
    const WCHAR* rest = finalPath + 4;
    BOOL unc = _wcsnicmp(rest, L"UNC\\", 4) == 0;
    if (unc)
    {
        rest += 4;
        if (rest[0] == 0 || rest[0] == L'\\')
            return NULL;
    }
    else if (!(((rest[0] >= L'A' && rest[0] <= L'Z') || (rest[0] >= L'a' && rest[0] <= L'z')) && rest[1] == L':' &&
               rest[2] == L'\\'))
        return NULL;
    size_t len = wcslen(rest);
    WCHAR* p = (WCHAR*)malloc((len + 3) * sizeof(WCHAR));
    if (p == NULL)
        return NULL;
    size_t pos = 0;
    if (unc)
    {
        p[pos++] = L'\\';
        p[pos++] = L'\\';
    }
    memcpy(p + pos, rest, (len + 1) * sizeof(WCHAR));
    return p;
}

// The file a replace of 'name' (wide, may carry \\?\) must target when 'name' is a file symbolic
// link (SalReplaceFollowsName): the plain final path of 'h', the file opened through 'name'
// (malloc'ed). NULL when the name is not followed, or when the final path cannot be read or has no
// drive / UNC form - the caller then keeps 'name' (a replace onto a link fails safe, 1464).
inline WCHAR* SalReplaceTargetOfLinkW(const WCHAR* name, HANDLE h)
{
    if (name == NULL || h == NULL || h == INVALID_HANDLE_VALUE)
        return NULL;
    WIN32_FIND_DATAW fd;
    HANDLE f = FindFirstFileW(name, &fd);
    if (f == INVALID_HANDLE_VALUE)
        return NULL;
    FindClose(f);
    if (!SalReplaceFollowsName(fd.dwFileAttributes, fd.dwReserved0))
        return NULL;
    DWORD need = GetFinalPathNameByHandleW(h, NULL, 0, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    if (need == 0 || need >= 0x10000)
        return NULL;
    WCHAR* buf = (WCHAR*)malloc((need + 1) * sizeof(WCHAR));
    if (buf == NULL)
        return NULL;
    WCHAR* ret = NULL;
    DWORD got = GetFinalPathNameByHandleW(h, buf, need + 1, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    if (got > 0 && got <= need)
        ret = SalFinalPathPlainW(buf);
    free(buf);
    return ret;
}

// Puts the complete, closed file 'tempPath' in the place of 'targetPath' (both wide, the same
// folder). 'targetExisted': the caller saw the target (and the user agreed to replace it);
// 'clearReadOnly': the user agreed to replace a read-only target. '*err' gets the error of a
// failure (for srrDone it is left alone).
inline CSalReplaceResult SalReplaceWithTempW(const WCHAR* targetPath, const WCHAR* tempPath, BOOL targetExisted,
                                             BOOL clearReadOnly, DWORD* err)
{
    if (!targetExisted)
    {
        if (MoveFileExW(tempPath, targetPath, 0)) // never replaces: a file that appeared meanwhile stays
            return srrDone;
        *err = GetLastError();
        return srrFailedKept;
    }

    DWORD oldAttr = GetFileAttributesW(targetPath);
    BOOL cleared = FALSE;
    if (clearReadOnly && oldAttr != INVALID_FILE_ATTRIBUTES && (oldAttr & FILE_ATTRIBUTE_READONLY) &&
        SetFileAttributesW(targetPath, oldAttr & ~FILE_ATTRIBUTE_READONLY))
    {
        cleared = TRUE;
    }
    if (ReplaceFileW(targetPath, tempPath, NULL, REPLACEFILE_IGNORE_MERGE_ERRORS | REPLACEFILE_IGNORE_ACL_ERRORS, NULL, NULL))
        return srrDone;
    DWORD e = GetLastError();
    BOOL targetThere = !SalPathIsGoneW(targetPath);
    BOOL tempThere = !SalPathIsGoneW(tempPath);
    CSalReplaceFailureNext next = SalReplaceFailureNext(e, targetThere, tempThere);
    if (next == srnFallbackMove)
    {
        if (MoveFileExW(tempPath, targetPath, MOVEFILE_REPLACE_EXISTING))
            return srrDone;
        e = GetLastError();
        targetThere = !SalPathIsGoneW(targetPath);
        tempThere = !SalPathIsGoneW(tempPath);
        next = !targetThere ? (tempThere ? srnFinishMove : srnBothGone) : srnKeepTarget;
    }
    switch (next)
    {
    case srnFinishMove:
        if (MoveFileExW(tempPath, targetPath, 0))
            return srrDone;
        *err = GetLastError();
        return srrLeftAtTemp;

    case srnBothGone:
        *err = e;
        return srrFailedBothGone;

    default: // srnKeepTarget
        if (cleared)
            SetFileAttributesW(targetPath, oldAttr); // the read-only attribute back
        *err = e;
        return srrFailedKept;
    }
}
