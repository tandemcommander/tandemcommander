// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfindignore.h
//
// Feature 163: the relative kind of Find's "ignore" list (CFindIgnore, find.cpp).
// An item "Name\Sub" is prepared as "\Name\Sub\" and ignores every folder of the
// search whose path holds it below the search root. It was found with StrIStr,
// the code page's byte fold - two different UTF-8 folder names that fold
// together on the code page were one item, and equal names whose UTF-8 lengths
// differ were missed. Now: the file system's rule (feature 092), tried at each
// backslash of the path (the item starts with one).
//
// Header-only on SalPathHasPrefixOrdinalCI (salunicode.h), covered by saltests.
//
//*****************************************************************************

#include "salunicode.h"

// TRUE when 'path' holds 'item' (itemLen bytes, "\...\") at a backslash and the
// match ends past 'startPathLen' bytes (only subpaths of the search root count)
inline BOOL SalFindIgnoreRelativeMatch(const char* path, const char* item, int itemLen, int startPathLen)
{
    if (path == NULL || item == NULL || itemLen <= 0 || item[0] != '\\')
        return FALSE;
    for (const char* m = path; *m != 0; m++)
    {
        int n = 0;
        if (*m == '\\' && SalPathHasPrefixOrdinalCI(m, item, itemLen, &n) && (int)(m - path) + n > startPathLen)
            return TRUE;
    }
    return FALSE;
}
