// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcachename.h
//
// Does the disk cache's temporary copy (its folder + the name) fit (feature 260)?
// Header-only, no globals; saltests checks it; the core's CCacheDirData
// (src/cache.cpp) asks it before it places a new temporary file.
//
// The cache refused a copy whose UTF-8 path reached 260 BYTES: F3 / F4 of an
// archive member of 90 CJK letters (274 bytes, 94 UTF-16 units - a valid name,
// a path of about 140 units) said "resulting filename is too long". The core's
// own F3 / F4 of archive members ask for the long mode now: the path fits when
// it has at most MAX_PATH - 1 UTF-16 units - what the viewers, the editors, the
// shell and the archivers open without the "\\?\" prefix. The plug-in services
// keep the byte rule (a plug-in may copy the path into a MAX_PATH buffer).
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

#include "salmaskname.h" // SalNameUtf16UnitsU8

// 'folder' ends with a backslash (CCacheDirData::Path); 'name' is one UTF-8 name
inline BOOL SalCacheTmpPathFitsU8(const char* folder, const char* name, BOOL longTmpPath)
{
    if (folder == NULL || name == NULL)
        return FALSE;
    if (!longTmpPath)
        return strlen(folder) + strlen(name) + 1 <= MAX_PATH; // the historical rule, in bytes
    // bytes that do not form a sequence count one unit each, as the code-page text they are
    return SalNameUtf16UnitsU8(folder) + SalNameUtf16UnitsU8(name) <= MAX_PATH - 1;
}
