// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcassoc.h
//
// Extension lists of archive association records ("rar;r##", "7z") - the pure
// helpers the association update uses (feature 089). Header-only, no globals,
// testable in saltests. Extensions are ASCII, separated by ';', compared
// without case; '#' is an ordinary character here (it is a wildcard only when
// a file name is matched).
//
// Contract: specs/089-7zip-followups/contracts/association-takeover.md
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

namespace SalArcAssocDetail
{
inline char Lower(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c; }

inline BOOL SameExt(const char* a, int aLen, const char* b)
{
    int bLen = (int)strlen(b);
    if (aLen != bLen)
        return FALSE;
    for (int i = 0; i < aLen; i++)
        if (Lower(a[i]) != Lower(b[i]))
            return FALSE;
    return TRUE;
}
} // namespace SalArcAssocDetail

// TRUE when the ';'-separated list 'list' holds the extension 'ext'
// (case-insensitive, whole-item match). NULL or empty arguments: FALSE.
inline BOOL SalExtListContains(const char* list, const char* ext)
{
    if (list == NULL || ext == NULL || *ext == 0)
        return FALSE;
    const char* s = list;
    while (1)
    {
        const char* e = s;
        while (*e != 0 && *e != ';')
            e++;
        if (SalArcAssocDetail::SameExt(s, (int)(e - s), ext))
            return TRUE;
        if (*e == 0)
            return FALSE;
        s = e + 1;
    }
}

// Copies 'list' to 'out' without every occurrence of 'ext' and without empty
// items; the order of the other items is kept. Returns TRUE when something was
// removed. 'out' may be the same buffer as 'list' (the result is never longer);
// an item that does not fit into 'out' is left out whole (never cut).
inline BOOL SalExtListRemove(const char* list, const char* ext, char* out, int outSize)
{
    if (out == NULL || outSize <= 0)
        return FALSE;
    if (list == NULL)
    {
        out[0] = 0;
        return FALSE;
    }
    BOOL removed = FALSE;
    int w = 0;
    const char* s = list;
    while (1)
    {
        const char* e = s;
        while (*e != 0 && *e != ';')
            e++;
        int len = (int)(e - s);
        BOOL last = *e == 0; // read before anything is written: 'out' may alias 'list'
        if (len > 0)
        {
            if (ext != NULL && SalArcAssocDetail::SameExt(s, len, ext))
                removed = TRUE;
            else if (w + (w > 0 ? 1 : 0) + len < outSize)
            {
                if (w > 0)
                    out[w++] = ';';
                memmove(out + w, s, len);
                w += len;
            }
        }
        if (last)
            break;
        s = e + 1;
    }
    out[w] = 0;
    return removed;
}
