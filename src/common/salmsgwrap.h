// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salmsgwrap.h (feature 121)
//
// Where the program's message box (msgbox.cpp, CMessageBox) inserts hard line
// breaks into a text that DrawText cannot fit into the box's width.
//
// DrawText(DT_WORDBREAK) breaks lines between words only; a single "word"
// wider than the box - in practice a long path, which has no spaces - makes
// it report a wider rectangle. The box then inserted a hard break before
// EVERY character that overflowed a line, counting the line from the last
// '\n' only, so every line of the text was cut at its right edge, inside
// words (found by feature 101: "a message box with a very long path breaks
// lines inside words").
//
// The rule now: breaks go only INSIDE a run of non-white-space characters
// that alone is wider than 'maxWidth'; everything else is left to DrawText,
// which breaks between words. Inside such a run a piece ends after the last
// path separator ('\' or '/') that keeps it within 'maxWidth' - when that
// piece is at least a third of 'maxWidth' wide, so a path is not cut into
// slivers - else before the first character that does not fit. Never inside
// a surrogate pair; a single character wider than 'maxWidth' stands alone.
// Every piece is then at most 'maxWidth' wide, so DrawText can place it.
//
// Header-only and pure (the per-unit advances are a parameter): saltests.
//
//*****************************************************************************

namespace SalMsgWrapDetail
{
template <class CH>
inline bool IsSpace(CH c)
{
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

template <class CH>
inline bool IsHighSurrogate(CH c)
{
    return sizeof(CH) == 2 && (unsigned)c >= 0xD800 && (unsigned)c <= 0xDBFF;
}

template <class CH>
inline bool IsLowSurrogate(CH c)
{
    return sizeof(CH) == 2 && (unsigned)c >= 0xDC00 && (unsigned)c <= 0xDFFF;
}
} // namespace SalMsgWrapDetail

// 'text' has 'len' units, 'advance[i]' is the width of unit i (>= 0). Writes the
// positions where a '\n' is to be inserted (before text[pos], ascending) to
// 'breaks' and returns their number - at most 'breaksMax' (the rest of an over-wide
// word then stays as it is). Returns 0 when no break is needed.
template <class CH>
inline int SalMsgWrapBreaks(const CH* text, int len, const int* advance, int maxWidth,
                            int* breaks, int breaksMax)
{
    using namespace SalMsgWrapDetail;
    if (text == 0 || advance == 0 || len <= 0 || maxWidth <= 0 || breaks == 0 || breaksMax <= 0)
        return 0;
    int count = 0;
    int i = 0;
    while (i < len)
    {
        if (IsSpace(text[i]))
        {
            i++;
            continue;
        }
        int ws = i; // a word: [ws, we)
        int we = i;
        long long wordWidth = 0;
        while (we < len && !IsSpace(text[we]))
            wordWidth += advance[we++];
        if (wordWidth > maxWidth)
        {
            int start = ws;
            while (start < we)
            {
                long long lineWidth = 0;
                int lastSep = -1;          // a piece may end after this unit's position
                long long lastSepWidth = 0; // the width of the piece up to it
                int j = start;
                while (j < we && lineWidth + advance[j] <= maxWidth)
                {
                    lineWidth += advance[j];
                    if (text[j] == '\\' || text[j] == '/')
                    {
                        lastSep = j + 1;
                        lastSepWidth = lineWidth;
                    }
                    j++;
                }
                if (j >= we)
                    break; // the rest of the word fits
                int brk = j;
                if (lastSep > start && lastSep < we && lastSepWidth * 3 >= maxWidth)
                    brk = lastSep;
                if (brk > start && brk < len && IsLowSurrogate(text[brk]) && IsHighSurrogate(text[brk - 1]))
                    brk--; // never between the halves of a pair
                if (brk <= start) // one character wider than the box: it stands alone
                {
                    brk = start + 1;
                    if (brk < we && IsLowSurrogate(text[brk]) && IsHighSurrogate(text[start]))
                        brk++;
                }
                if (brk >= we)
                    break;
                if (count >= breaksMax)
                    return count;
                breaks[count++] = brk;
                start = brk;
            }
        }
        i = we;
    }
    return count;
}

// A menu label shown as a message box's title (feature 121: the clipboard error box is titled by
// the existing "&Copy To Clipboard"): the accelerator marks go - a "(&X)" suffix of the CJK
// translations with the space before it, "&&" becomes "&", any other '&' is dropped. 'dst' gets
// at most dstSize - 1 bytes (a label is short; a longer one is cut, ASCII marks only are touched).
inline void SalMenuLabelToTitle(char* dst, size_t dstSize, const char* label)
{
    if (dst == 0 || dstSize == 0)
        return;
    size_t d = 0;
    if (label != 0)
    {
        for (const char* s = label; *s != 0 && d + 1 < dstSize; s++)
        {
            if (s[0] == '(' && s[1] == '&' && s[2] != 0 && s[3] == ')')
            {
                while (d > 0 && dst[d - 1] == ' ')
                    d--;
                s += 3;
                continue;
            }
            if (s[0] == '&')
            {
                if (s[1] == '&')
                {
                    dst[d++] = '&';
                    s++;
                }
                continue;
            }
            dst[d++] = *s;
        }
    }
    dst[d] = 0;
}
