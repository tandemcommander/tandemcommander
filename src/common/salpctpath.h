// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpctpath.h
//
// A path with %...% that names an existing folder as it is (feature 238).
// Header-only, no globals; saltests checks it.
//
// A path on the command line (-l / -r / -a) or typed into Change Directory had
// its %VAR% expanded always: a folder literally named "p%OS%q" opened
// "pWindows_NTq" - another folder. The core now uses the path literally when
// the part of it up to the last component holding a '%' exists as typed
// ("C:\x\p%OS%q\a.zip\inner": "C:\x\p%OS%q"); else it expands as before.
//
//*****************************************************************************

#include <string.h>

// the length of 'path's prefix that ends with the last component holding a '%' (up to the next
// '\' or '/', or the end), or 0 when the path has no '%'
inline int SalPercentPrefixLen(const char* path)
{
    const char* lastPct = strrchr(path, '%');
    if (lastPct == NULL)
        return 0;
    const char* end = lastPct;
    while (*end != 0 && *end != '\\' && *end != '/')
        end++;
    return (int)(end - path);
}

// how the path is anchored: 1 - a local drive path "X:\..." (or "X:/..."); 2 - a network path
// ("\\..." or "//..."); 3 - relative to the current folder ("name", "..\name"); 4 - relative to the
// current drive's root ("\name"); 0 - drive-relative ("X:name") or empty
inline int SalPercentPathKind(const char* path)
{
    if (path[0] == 0)
        return 0;
    if (path[1] == ':')
        return (path[2] == '\\' || path[2] == '/') ? 1 : 0;
    if ((path[0] == '\\' || path[0] == '/') && (path[1] == '\\' || path[1] == '/'))
        return 2;
    if (path[0] == '\\' || path[0] == '/')
        return 4;
    return 3;
}
