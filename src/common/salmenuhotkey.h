// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmenuhotkey.h
//
// Where a menu item without a hot key gets its '&' (feature 236). Header-only,
// no globals; saltests checks it.
//
// The core's popup menus (CMenuPopup::AssignHotKeys) give items without a hot
// key one: the first letter not used by another item. The texts are UTF-8 (the
// menu draws them through SalU8ToW), but the search went byte by byte with the
// ANSI code page's tables: in a text without a free ASCII letter it took a
// byte >= 0x80 the code page calls a letter - also a UTF-8 continuation byte
// (0x9A, 0x9E, 0xBE ... are letters in cp1250) - and put '&' inside a UTF-8
// character: the item showed broken text. Such a hot key could not work anyway:
// the menu matches the typed key (an ANSI WM_CHAR byte) against the byte after
// '&', which for a letter outside ASCII is a UTF-8 lead byte. Only ASCII letters
// are taken now; an item without a free one gets no hot key. (A few items are
// code-page text - "Internal viewer" of View with, the "(View)" column of the
// file history - where a code-page letter could have worked; they lose it only
// when no ASCII letter of theirs is free.)
//
//*****************************************************************************

// the byte index of 'text' before which '&' goes, or -1 when the text has no ASCII letter that is
// not in 'assigned' (256 entries, indexed by the upper-case byte); 'upper' maps a byte to upper case
inline int SalMenuHotKeyPos(const char* text, const int* assigned, const unsigned char* upper)
{
    for (int i = 0; text[i] != 0; i++)
    {
        unsigned char c = (unsigned char)text[i];
        if (c < 0x80 && (c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z') && !assigned[upper[c]])
            return i;
    }
    return -1;
}

// the byte after the item's hot-key '&', or 0 when it has none ("&&" is a literal '&': "R&&D" has no
// hot key - before feature 236 it took 'D')
inline unsigned char SalMenuHotKeyOf(const char* text)
{
    for (const char* p = text; *p != 0; p++)
    {
        if (*p == '&')
        {
            if (*(p + 1) == '&')
            {
                p++; // the pair is one literal '&'
                continue;
            }
            return (unsigned char)*(p + 1); // 0 for a trailing '&'
        }
    }
    return 0;
}
