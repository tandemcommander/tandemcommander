// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnamerun.h
//
// Which of the dragged / pasted names a listed name is (feature 230). Core only
// (it calls SalNameCompareOrdinalCI of salunicode.cpp; plug-ins have
// salnameorder.h); saltests checks it.
//
// DragDropToArcOrFS matches the source folder's listing against the names of
// the data object, sorted by SalNameCompareOrdinalCI. In a case-sensitive folder
// (WSL, setCaseSensitiveInfo) "a.txt" and "A.txt" are two files that compare
// equal: before feature 230 the second one listed was taken as a "duplicate" and
// added anyway - an item nobody selected was packed (and with Move deleted), and
// the index array sized by the names was overrun. Now each name is taken once:
//   1. by the listed item byte-equal to it;
//   2. only when none is: by the one listed item equal to it case-insensitively
//      - the drag source may give a name in another case than the disk lists it
//      (a path the user typed) - provided the name's case-insensitive run holds
//      that name alone (SalNameCIRunSingle) and the folder is not case-sensitive
//      (decided by the caller after the listing).
//
//*****************************************************************************

#include <windows.h>
#include <string.h>
#include "salunicode.h"

// 'names' (count entries, sorted with SalNameCompareOrdinalCI), 'ciIndex' an index ContainsString
// found for 'name' (a case-insensitive match). Returns the index of the byte-equal entry within the
// run of entries equal to 'name' case-insensitively, or -1 when none is byte-equal.
inline int SalNameExactInCIRun(char* const* names, int count, int ciIndex, const char* name)
{
    if (ciIndex < 0 || ciIndex >= count)
        return -1;
    int lo = ciIndex;
    while (lo > 0 && SalNameCompareOrdinalCI(names[lo - 1], -1, name, -1) == 0)
        lo--;
    for (int i = lo; i < count && SalNameCompareOrdinalCI(names[i], -1, name, -1) == 0; i++)
    {
        if (strcmp(names[i], name) == 0)
            return i;
    }
    return -1;
}

// the index of 'names' (as above) that the case-insensitive run around 'ciIndex' consists of alone,
// or -1 when the run holds more entries (then a listed name in another case cannot tell which one)
inline int SalNameCIRunSingle(char* const* names, int count, int ciIndex)
{
    if (ciIndex < 0 || ciIndex >= count)
        return -1;
    const char* n = names[ciIndex];
    if (ciIndex > 0 && SalNameCompareOrdinalCI(names[ciIndex - 1], -1, n, -1) == 0)
        return -1;
    if (ciIndex + 1 < count && SalNameCompareOrdinalCI(names[ciIndex + 1], -1, n, -1) == 0)
        return -1;
    return ciIndex;
}

// after the listing: does the one item equal to a name only case-insensitively take it? Only when no
// byte-equal item took the name, exactly one such item was listed and the folder is not
// case-sensitive (there "A.txt" is another file than a dragged "a.txt")
inline BOOL SalNameCIFallbackTakes(BOOL nameTaken, int ciOnlyCount, BOOL dirCaseSensitive)
{
    return !nameTaken && ciOnlyCount == 1 && !dirCaseSensitive;
}
