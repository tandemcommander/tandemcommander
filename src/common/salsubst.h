// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salsubst.h (feature 301)
//
// The target of a subst drive is the device text QueryDosDeviceW gives for its
// letter ("\??\C:\folder"). It used to be read into MAX_PATH units and, when
// its UTF-8 form did not fit MAX_PATH bytes, asked again in the code page - '?'
// for every letter outside it, a path ResolveSubsts then spliced in front of
// the rest of a UTF-8 path; the copy into the caller's buffer was also cut. The
// device text is now read whole and turned into the subst path here: exact, or
// refused when the caller's buffer cannot hold it.
//
//   SAL_SUBST_TEXT_U8_MAX     bytes that hold every subst path subst.exe can
//                             create (fewer than MAX_PATH units, measured) as
//                             UTF-8 with the terminator
//   SalSubstTargetToPathU8    device text -> subst path (UTF-8 / WTF-8)
//
// Header-only; needs SalWToU8 (salunicode.h).
//
//*****************************************************************************

#define SAL_SUBST_TEXT_U8_MAX (3 * MAX_PATH + 1)

enum
{
    SAL_SUBST_NONE = 0,     // not a subst drive (a volume, a network redirector, ...)
    SAL_SUBST_OK = 1,       // 'path' holds the whole subst path
    SAL_SUBST_TOO_LONG = 2, // a subst drive whose path does not fit 'pathMax' bytes
};

// "\??\C:\folder" -> "C:\folder", "\??\D:" -> "D:", "\??\UNC\server\share" ->
// "\\server\share"; any other device text -> SAL_SUBST_NONE. The UTF-8 size is
// measured before anything is written: a path that does not fit 'pathMax' bytes
// (terminator included) is SAL_SUBST_TOO_LONG - never a cut path. 'path' is
// emptied whenever the result is not SAL_SUBST_OK (and pathMax > 0).
inline int SalSubstTargetToPathU8(const WCHAR* device, char* path, int pathMax)
{
    if (path != NULL && pathMax > 0)
        path[0] = 0;
    if (device == NULL || path == NULL || pathMax <= 0)
        return SAL_SUBST_NONE;
    if (wcsncmp(device, L"\\??\\", 4) != 0)
        return SAL_SUBST_NONE;
    const WCHAR* rest; // the part copied as it is
    char* out = path;
    int outMax = pathMax;
    if (((device[4] >= L'a' && device[4] <= L'z') || (device[4] >= L'A' && device[4] <= L'Z')) &&
        device[5] == L':')
    {
        rest = device + 4; // "C:\folder"
    }
    else if (wcsncmp(device + 4, L"UNC\\", 4) == 0)
    {
        rest = device + 7; // "\server\share" - one more '\' in front
        if (pathMax < 2)
            return SAL_SUBST_TOO_LONG;
        out = path + 1;
        outMax = pathMax - 1;
    }
    else
        return SAL_SUBST_NONE;
    int need = SalWToU8(rest, -1, NULL, 0); // bytes with the terminator
    if (need <= 0 || need > outMax || SalWToU8(rest, -1, out, outMax) != need)
    {
        path[0] = 0;
        return SAL_SUBST_TOO_LONG;
    }
    if (out != path)
        path[0] = '\\';
    return SAL_SUBST_OK;
}
