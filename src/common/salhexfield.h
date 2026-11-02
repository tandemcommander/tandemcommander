// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salhexfield.h (feature 397)
//
// The tidying of a hex-mode search field (Find's "Containing", the viewer's
// Find) while the user types: leading spaces dropped, a second space outside
// quotes dropped, a space between every two hex digits, a space before an
// opening quote and after a closing quote glued to their neighbours, the caret
// moved along.
//
// It ran in DoHexValidation on the field's text read and written through the
// system code page, so a quoted letter outside the code page became '?' at the
// first typed key and the search looked for '?' bytes. The rule now works on
// the field's own UTF-16 text and caret (CB_GETEDITSEL / CB_SETEDITSEL units):
//
//   SalHexFieldTidyW - the loop of DoHexValidation before 397, character for
//                      character, on wchar_t; one addition: the hex-digit
//                      grouping never puts a space between the two halves of a
//                      surrogate pair. A space is inserted only while the text
//                      is shorter than maxLen and the buffer has room; the text
//                      is never shortened except for the spaces it folds.
//                      FALSE only for a NULL text or a zero capacity.
//
// Header-only and pure: saltests (TestHexFieldTidy397).
//
//*****************************************************************************

#include <stddef.h>
#include <wchar.h>

inline bool SalHexFieldIsHighSurrogate(wchar_t c) { return c >= 0xD800 && c <= 0xDBFF; }
inline bool SalHexFieldIsLowSurrogate(wchar_t c) { return c >= 0xDC00 && c <= 0xDFFF; }

// text: NUL-terminated within a buffer of `capacity` units; start / end: the caret
// (selection) in UTF-16 units, moved with the text; maxLen: insertions only while
// the length is below it (the field's limit)
inline bool SalHexFieldTidyW(wchar_t* text, size_t capacity, int* start, int* end, size_t maxLen)
{
    if (text == NULL || capacity == 0 || start == NULL || end == NULL)
        return false;
    text[capacity - 1] = 0; // a defensive end; the caller passes a terminated text

    // room for one more unit: below the field's limit and inside the buffer
    auto canInsert = [&](const wchar_t* strEnd) -> bool
    {
        size_t len = (size_t)(strEnd - text);
        return len < maxLen && len + 1 < capacity;
    };

    wchar_t* s = text;
    while (*s != 0 && *s == L' ')
        s++;
    if (s != text)
    {
        *start -= (int)(s - text);
        *end -= (int)(s - text);
        if (*start < 0)
            *start = 0;
        if (*end < 0)
            *end = 0;
        wmemmove(text, s, wcslen(s) + 1);
    }
    s = text;
    bool openedQuotes = false;
    wchar_t *st = s, *strEnd = text + wcslen(text);
    while (*s != 0)
    {
        if (*s == L'"')
        {
            if (!openedQuotes && s > text && *(s - 1) != L' ' && canInsert(strEnd))
            {
                if (*start > s - text)
                    (*start)++;
                if (*end > s - text)
                    (*end)++;
                wmemmove(s + 1, s, (strEnd - s) + 1);
                *s++ = L' ';
                strEnd++;
            }
            else
            {
                if (openedQuotes && s + 1 < strEnd && *(s + 1) != L' ' && canInsert(strEnd))
                {
                    if (*start >= (s - text) + 1)
                        (*start)++;
                    if (*end >= (s - text) + 1)
                        (*end)++;
                    wmemmove(s + 2, s + 1, strEnd - s);
                    *(s + 1) = L' ';
                    strEnd++;
                }
                if (openedQuotes && s + 1 < strEnd)
                    s++;
                st = s + 1;
            }
            openedQuotes = !openedQuotes;
        }
        else
        {
            if (!openedQuotes)
            {
                if (*s == L' ')
                {
                    if (st == s) // '  ' -> ' '
                    {
                        s--;
                        if (*start >= st - text)
                            (*start)--;
                        if (*end >= st - text)
                            (*end)--;
                        wmemmove(s, st, (strEnd - st) + 1);
                        strEnd--;
                    }
                    else
                        st = s + 1;
                }
                else
                {
                    // 'ABC' -> 'AB C'; never between the halves of a surrogate pair
                    if ((s - st) == 2 &&
                        !(SalHexFieldIsLowSurrogate(*s) && SalHexFieldIsHighSurrogate(*(s - 1))))
                    {
                        if (canInsert(strEnd))
                        {
                            if (*start >= s - text)
                                (*start)++;
                            if (*end >= s - text)
                                (*end)++;
                            wmemmove(s + 1, s, (strEnd - s) + 1);
                            *s = L' ';
                            st = s + 1;
                            strEnd++;
                        }
                    }
                }
            }
        }
        s++;
    }
    return true;
}
