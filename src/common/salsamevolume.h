// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salsamevolume.h
//
// "Is this path on the volume being recovered?" for a check that guards data
// (feature 324). Header-only (wide API only) - the Undelete plug-in includes
// it and saltests checks it.
//
// Undelete warns before it restores onto the volume the files are recovered
// from (writing there can overwrite the clusters of files not yet recovered)
// and keeps the temporary copy of a viewed file off that volume. Both asked
// the core's PathsAreOnTheSameVolume, which answers "different" when it could
// read the volume name of only one of the two paths - the guard failed open.
// Measured: a mount folder named outside ASCII (the core asks the code-page
// GetVolumeNameForVolumeMountPoint with the UTF-8 path) and a junction to a
// volume-GUID folder have no volume name for the core, and its reparse walk may
// not step past them to the parent.
//
// The core's answer and its plug-in contract stay as they are. When it says
// "different" only as an estimation, the file system's identity decides: the
// volume serial number of each path's nearest existing folder (an open handle
// follows junctions, mount folders, symbolic links and subst drives the way
// the writes will). A serial that cannot be read counts as the same volume -
// the check fails closed; two different readable serials are two volumes.
//
//*****************************************************************************

#include "salsamefile.h"

// the volume serials of two identities: simUnknown when either side has no handle-based identity
// (only attribute data, or nothing) or reports serial 0; the 64-bit serials when both sides have
// them (FileIdInfo), else the 32-bit ones
inline int SalVolumeSerialMatch(const CSalFileIdentity& a, const CSalFileIdentity& b)
{
    if (!a.Valid || !b.Valid || !a.Has64 || !b.Has64)
        return simUnknown;
    if (a.Has128 && b.Has128)
    {
        if (a.Vsn64 == 0 || b.Vsn64 == 0)
            return simUnknown;
        return a.Vsn64 == b.Vsn64 ? simEqual : simDifferent;
    }
    if (a.Vsn32 == 0 || b.Vsn32 == 0)
        return simUnknown;
    return a.Vsn32 == b.Vsn32 ? simEqual : simDifferent;
}

// the guard: TRUE = treat the two paths as one volume. 'coreSame' / 'coreIsEstimate' are the
// answer and the 'resIsOnlyEstimation' of PathsAreOnTheSameVolume; 'serialMatch' is
// SalVolumeSerialMatch (simUnknown when it was not read). "Same" and a certain "different" (both
// volume names read) stand; an estimated "different" holds only for two different serials.
inline BOOL SalVolumeGuardSame(BOOL coreSame, BOOL coreIsEstimate, int serialMatch)
{
    if (coreSame)
        return TRUE;
    if (!coreIsEstimate)
        return FALSE;
    return serialMatch != simDifferent;
}

// does a failed open of a path let the walk ask its parent? Only when the path does not exist -
// the restore creates it below the nearest existing folder; any other error leaves it unknown
inline BOOL SalVolumeIdentityStepsUp(DWORD err)
{
    return err == ERROR_FILE_NOT_FOUND || err == ERROR_PATH_NOT_FOUND;
}

// the length of the root of a wide path, its backslash included: "\\?\C:\" 7, "\\?\UNC\srv\share\"
// up to the backslash after the share, "\\?\Volume{...}\" (any other "\\?\" device) up to the
// first backslash after the prefix, "C:\" 3; a root without its closing backslash is the whole
// path; 0 for anything else (a relative path - never stepped up)
inline int SalWPathRootLength(const WCHAR* w)
{
    if (w == NULL)
        return 0;
    if (w[0] == L'\\' && w[1] == L'\\' && w[2] == L'?' && w[3] == L'\\')
    {
        const WCHAR* p = w + 4;
        if (((p[0] >= L'A' && p[0] <= L'Z') || (p[0] >= L'a' && p[0] <= L'z')) && p[1] == L':')
            return p[2] == L'\\' ? 7 : (p[2] == 0 ? 6 : 0);
        if (_wcsnicmp(p, L"UNC\\", 4) == 0)
        {
            p += 4;
            int parts = 0;
            while (*p != 0)
            {
                if (*p == L'\\' && ++parts == 2)
                    return (int)(p - w) + 1;
                p++;
            }
            return parts == 1 && p[-1] != L'\\' ? (int)(p - w) : 0; // "\\?\UNC\srv\share" whole
        }
        while (*p != 0 && *p != L'\\')
            p++;
        if (p == w + 4)
            return 0;
        return *p == L'\\' ? (int)(p - w) + 1 : (int)(p - w);
    }
    if (((w[0] >= L'A' && w[0] <= L'Z') || (w[0] >= L'a' && w[0] <= L'z')) && w[1] == L':' && w[2] == L'\\')
        return 3;
    return 0;
}

// cuts the last component of 'w' in place, leaving the parent with its trailing backslash ("\\?\C:\a\b"
// -> "\\?\C:\a\", "\\?\C:\a" -> "\\?\C:\"); FALSE (unchanged) at the root or without a root
inline BOOL SalWPathCutLast(WCHAR* w)
{
    int root = SalWPathRootLength(w);
    if (root <= 0)
        return FALSE;
    size_t len = wcslen(w);
    while (len > (size_t)root && w[len - 1] == L'\\')
        len--;
    if (len <= (size_t)root)
        return FALSE;
    size_t p = len;
    while (p > (size_t)root && w[p - 1] != L'\\')
        p--;
    w[p] = 0;
    return TRUE;
}

// the identity of 'path' (wide, any length - the \\?\ form when long) or, when it does not exist,
// of its nearest existing ancestor; TRUE only with a handle-based identity (Has64). The path is
// copied, never cut.
inline BOOL SalGetNearestVolumeIdentityW(const WCHAR* path, CSalFileIdentity* id)
{
    SalFileIdentityClear(id);
    if (path == NULL || path[0] == 0)
        return FALSE;
    size_t n = wcslen(path);
    WCHAR* w = (WCHAR*)malloc((n + 1) * sizeof(WCHAR));
    if (w == NULL)
        return FALSE;
    memcpy(w, path, (n + 1) * sizeof(WCHAR));
    BOOL ok = FALSE;
    while (TRUE)
    {
        if (SalGetFileIdentityW(w, FALSE, id))
        {
            ok = id->Has64; // attribute data only: the volume is unknown
            break;
        }
        if (!SalVolumeIdentityStepsUp(GetLastError()) || !SalWPathCutLast(w))
            break;
    }
    free(w);
    if (!ok)
        SalFileIdentityClear(id);
    return ok;
}

// the whole guard for two wide paths and the core's answer: the identities are read only when the
// core is unsure of a "different"; a path that is NULL (not converted) or unreadable is unknown -
// the same volume
inline BOOL SalVolumeGuardForPaths(const WCHAR* path1, const WCHAR* path2, BOOL coreSame, BOOL coreIsEstimate)
{
    int match = simUnknown;
    if (!coreSame && coreIsEstimate && path1 != NULL && path2 != NULL)
    {
        CSalFileIdentity a, b;
        if (SalGetNearestVolumeIdentityW(path1, &a) && SalGetNearestVolumeIdentityW(path2, &b))
            match = SalVolumeSerialMatch(a, b);
    }
    return SalVolumeGuardSame(coreSame, coreIsEstimate, match);
}
