// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salinfolinebuf.h
//
// How large may the panel's information line text grow (feature 276)?
// Header-only, no globals; saltests checks it; CFilesWindow::ItemFocused
// (src/fileswn2.cpp) asks it when the expansion did not fit.
//
// The default Information Line content names the item twice ($(FileName) and
// $(FileDOSName), which is the name itself when the item has no short name -
// every archive member), so a name of 604 bytes did not fit the 1000-byte
// buffer and every focus said "Expanded string is too large." The expansion is
// repeated into a larger buffer instead: doubled, up to SAL_INFOLINE_MAX_LEN -
// the hot-text placements are MAKELPARAM(position, length), WORDs. Names alone
// stay far below the bound (a 199-character content names the item at most 18
// times, a listed name has at most 765 bytes); only width modifiers of
// thousands of characters reach it.
//
//*****************************************************************************

#define SAL_INFOLINE_FIRST_LEN 1000  // the first attempt (and a plug-in's buffer, spl_com.h)
#define SAL_INFOLINE_MAX_LEN 65535   // the bound: hot-text positions are WORDs

// the buffer length to try after an expansion into 'len' bytes did not fit;
// 0 = 'len' already is the bound, no further attempt
inline int SalInfoLineNextLen(int len)
{
    if (len < SAL_INFOLINE_FIRST_LEN)
        return SAL_INFOLINE_FIRST_LEN;
    if (len >= SAL_INFOLINE_MAX_LEN)
        return 0;
    return len > SAL_INFOLINE_MAX_LEN / 2 ? SAL_INFOLINE_MAX_LEN : 2 * len;
}
