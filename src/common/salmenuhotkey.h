// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmenuhotkey.h
//
// Where a menu item without a hot key gets its '&' (feature 236), and which item
// a typed key selects (feature 237). Core only - SalMenuKeyMatch calls
// salunicode.cpp (plug-ins do not include this header); no globals; saltests
// checks it.
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

#include <windows.h>
#include "salunicode.h"

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

// feature 237: how a typed character 'key' (UTF-16; a code-page WM_CHAR byte through SalACPCharToW)
// selects a popup item 'text' (UTF-8, or legacy code-page text): 2 - it is the item's mnemonic; 1 -
// the item has no mnemonic and starts with it; 0 - neither. Before, the typed ANSI byte was compared
// with the byte after '&': a UTF-8 item's accented mnemonic never matched, and a byte could match
// another letter (cp1250: "&\xC4\x8C" - C-caron - matched the key a-umlaut, 0xC4). Core only (it
// calls SalMnemonicMatchW of salunicode.cpp).
inline int SalMenuKeyMatch(const char* text, WCHAR key)
{
    if (text == NULL || *text == 0 || key == 0)
        return 0;
    if (SalMnemonicMatchW(text, key))
        return 2;
    if (SalMenuHotKeyOf(text) != 0)
        return 0; // another mnemonic
    // the first character: "&" + up to 4 bytes of the text, read as a mnemonic
    char first[6];
    first[0] = '&';
    int n = 0;
    while (n < 4 && text[n] != 0 && text[n] != '&')
    {
        first[1 + n] = text[n];
        n++;
    }
    first[1 + n] = 0;
    return n > 0 && SalMnemonicMatchW(first, key) ? 1 : 0;
}

// feature 256: what a popup does with its owner's answer 'ret' to WM_MENUCHAR (the low DWORD of the
// result) in a popup of 'count' items: MNC_SELECT or MNC_EXECUTE with '*index' the item, or 0 -
// ignore it (MNC_IGNORE, MNC_CLOSE, an unknown kind, an item that does not exist). Before, only
// MNC_SELECT was carried out, with an unchecked index - and the question carried no character, so no
// owner could answer. The caller still refuses a separator or an item hidden at the skill level.
inline int SalMenuCharAnswer(DWORD ret, int count, int* index)
{
    int kind = HIWORD(ret);
    int i = LOWORD(ret);
    if (kind != MNC_SELECT && kind != MNC_EXECUTE || i >= count)
        return 0;
    *index = i;
    return kind;
}

// feature 256: the hot key of a dialog control's text 'text' (UTF-16) - the unit after a single '&'
// ("&&" is a literal '&'), or 0 when there is none or it is half of a surrogate pair. Before, the
// Find window read the text in the code page and took the byte after the first '&' not followed by
// another one - "R&&D" gave 'D'.
inline WCHAR SalDlgHotKeyW(const WCHAR* text)
{
    if (text == NULL)
        return 0;
    for (const WCHAR* p = text; *p != 0; p++)
    {
        if (*p == L'&')
        {
            if (*(p + 1) == L'&')
            {
                p++; // the pair is one literal '&'
                continue;
            }
            WCHAR c = *(p + 1); // 0 for a trailing '&'
            return IS_HIGH_SURROGATE(c) || IS_LOW_SURROGATE(c) ? 0 : c;
        }
    }
    return 0;
}

// feature 256: an Alt+key press (WM_SYSKEYDOWN, virtual key 'vk') is the hot key 'hotKey' - only an
// ASCII letter or digit, whose virtual key is its upper-case form (the old byte-to-virtual-key
// comparison, kept for these); other hot keys are matched by character (SalDlgHotKeyCharMatch)
inline BOOL SalDlgHotKeyVkMatch(WCHAR hotKey, WPARAM vk)
{
    if (hotKey >= L'a' && hotKey <= L'z')
        hotKey = (WCHAR)(hotKey - L'a' + L'A');
    if (!(hotKey >= L'A' && hotKey <= L'Z' || hotKey >= L'0' && hotKey <= L'9'))
        return FALSE;
    return vk == (WPARAM)hotKey;
}

// feature 256: a typed character 'typed' (WM_SYSCHAR of a wide loop, UTF-16) is the hot key 'hotKey',
// case ignored
inline BOOL SalDlgHotKeyCharMatch(WCHAR hotKey, WCHAR typed)
{
    if (hotKey == 0 || typed == 0)
        return FALSE;
    return (WCHAR)(ULONG_PTR)CharUpperW((LPWSTR)(ULONG_PTR)hotKey) ==
           (WCHAR)(ULONG_PTR)CharUpperW((LPWSTR)(ULONG_PTR)typed);
}
