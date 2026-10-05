// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salvolpaths.h
//
// The Undelete plug-in's volume layer in UTF-8 (feature 114). Header-only, no
// globals: the plug-in includes it and saltests checks it.
//
// The plug-in found the mount folders of a volume with the code-page functions
// (GetVolumePathNamesForVolumeNameA, FindFirstVolumeMountPointA,
// GetVolumePathNameA) on UTF-8 paths. A mount folder named outside ASCII came
// back as code-page bytes or as a best-fit look-alike ("voila" for
// "voil<U+00E0>"), and GetVolumePathNameA of a UTF-8 path that therefore did
// not exist answered with the volume of the nearest existing parent - the
// plug-in opened ANOTHER volume than the one chosen. The W functions are used
// now; these are the pure parts of the conversion.
//
//*****************************************************************************

#include <windows.h>

// Converts the UTF-16 multi-string 'multi' (as GetVolumePathNamesForVolumeNameW returns it:
// strings, each terminated, an empty one at the end) into a UTF-8 multi-string in 'out'
// ('outSize' bytes, always double-terminated when outSize >= 2). A path whose UTF-8 form does
// not fit the space left, or that is not valid UTF-16 (an unpaired surrogate), is LEFT OUT -
// never cut: a cut mount path names another folder. Returns the number of paths written.
inline int SalVolumePathsWToU8(const WCHAR* multi, char* out, int outSize)
{
    if (out == NULL || outSize < 2)
        return 0;
    int used = 0;
    int count = 0;
    if (multi != NULL)
    {
        for (const WCHAR* p = multi; *p != 0; p += lstrlenW(p) + 1)
        {
            int need = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, p, -1, NULL, 0, NULL, NULL);
            if (need <= 0 || used + need + 1 > outSize) // +1: the final terminator
                continue;
            WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, p, -1, out + used, need, NULL, NULL);
            used += need;
            count++;
        }
    }
    out[used] = 0;
    if (used + 1 < outSize)
        out[used + 1] = 0;
    return count;
}

// UTF-16 -> UTF-8 of one path into 'out' ('outSize' bytes); FALSE (and "") when it does not
// fit or is not valid UTF-16 - never a cut path
inline BOOL SalVolumePathWToU8(const WCHAR* w, char* out, int outSize)
{
    if (out == NULL || outSize <= 0)
        return FALSE;
    out[0] = 0;
    if (w == NULL)
        return FALSE;
    int r = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w, -1, out, outSize, NULL, NULL);
    if (r <= 0)
    {
        out[0] = 0;
        return FALSE;
    }
    return TRUE;
}
