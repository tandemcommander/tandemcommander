// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// A REG_MULTI_SZ list as one line of text (feature 189)
//
// The Registry Editor plug-in shows a REG_MULTI_SZ value as its strings
// separated by spaces. The list ends with the terminator of its last string
// and an empty string (two NULs), but a program can store it with one NUL,
// with more, or with none: the old loop took only the exact two-NUL end as
// the end, so a list with one NUL showed a trailing space (and the Find
// window then kept no terminator at all and read past its copy).
//
// SalMultiSzToLine turns every NUL inside the text into a space; the NULs at
// the end of the data (any number) are the end, not separators. 'text' has
// 'units' UTF-16 units as read. Returns the number of units the line has
// with its terminator: the text plus one NUL when the data had one at its
// end, the text alone (no terminator) when it had none - the caller then
// adds one or counts the units. An empty list gives 1 (just a NUL) or 0.
//
// Header-only (the plug-ins cannot compile a .cpp from src\common); needs
// <windows.h>; checked by saltests.
//

inline DWORD SalMultiSzToLine(WCHAR* text, DWORD units)
{
    if (text == NULL)
        return 0;
    DWORD end = units;
    while (end > 0 && text[end - 1] == L'\0')
        end--; // the NULs at the end end the list
    for (DWORD i = 0; i < end; i++)
    {
        if (text[i] == L'\0')
            text[i] = L' '; // a separator
    }
    return end < units ? end + 1 : end;
}
