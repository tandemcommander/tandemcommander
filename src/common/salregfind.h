// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The Registry Editor's Find: pure rules (feature 257)
//
// SalRegFindWholeWordInLine - a regular expression is searched line by line;
// the match position the search returns counts from the start of the LINE.
// The whole-word test read the characters around the match from the start of
// the whole value, so on the second and later lines of a list it missed whole
// words and took fragments for words. The rule gets the line and its length.
// A word boundary is a space character (isspace) or the line's start / end;
// an empty match is no word.
//
// SalHexPatternToBytes - the pattern of the HEX mode: pairs of hex digits,
// "text" (UTF-16LE, 2 bytes a unit), 'text' (the code page), spaces between.
// The 'text' was converted one UTF-16 unit at a time into one byte: a letter
// of 2+ bytes in the code page (every non-ASCII letter with UTF-8) became a
// 0x00 byte, a surrogate pair two replacement characters. Now each 'text' is
// converted as one text with WideCharToMultiByte(codePage, 0, ...) - the call
// the plain-text search's byte pattern uses - and its bytes are counted or
// written whole. 'strict' is the check before the search (two digits a byte,
// only spaces between); otherwise a lone digit is a byte and other characters
// are skipped (the conversion at the search start, after the check).
// 'out' == NULL counts only. Returns SALHEXPAT_OK with the byte count in
// *outLen; SALHEXPAT_BAD (bad syntax when strict, or a 'text' that cannot be
// converted at all); SALHEXPAT_TOOLONG (the bytes do not fit 'outSize' - never
// cut). An unclosed quote runs to the end of the pattern.
//
// Header-only (the plug-ins cannot compile a .cpp from src\common); needs
// <windows.h> and <ctype.h>; checked by saltests.
//

inline BOOL SalRegFindWholeWordInLine(const char* line, int lineLen, int pos, int matchLen)
{
    if (line == NULL || matchLen <= 0 || pos < 0 || pos + matchLen > lineLen)
        return FALSE;
    return (pos == 0 || isspace((unsigned char)line[pos - 1])) &&
           (pos + matchLen == lineLen || isspace((unsigned char)line[pos + matchLen]));
}

#define SALHEXPAT_OK 0
#define SALHEXPAT_BAD 1
#define SALHEXPAT_TOOLONG 2

inline int SalHexPatternDigit(WCHAR c)
{
    if (c >= L'0' && c <= L'9')
        return c - L'0';
    if (c >= L'a' && c <= L'f')
        return 10 + (c - L'a');
    if (c >= L'A' && c <= L'F')
        return 10 + (c - L'A');
    return -1;
}

inline int SalHexPatternToBytes(const WCHAR* text, UINT codePage, BOOL strict, char* out, int outSize, int* outLen)
{
    int len = 0;
    if (outLen != NULL)
        *outLen = 0;
    if (text == NULL)
        return SALHEXPAT_BAD;
    const WCHAR* s = text;
    BOOL quotesCodePage = FALSE; // 'text'
    BOOL quotesUnicode = FALSE;  // "text"
    while (1)
    {
        if (*s == L'"' && !quotesCodePage)
        {
            s++;
            quotesUnicode = !quotesUnicode;
            continue;
        }
        if (*s == L'\'' && !quotesUnicode)
        {
            s++;
            quotesCodePage = !quotesCodePage;
            continue;
        }
        if (*s == 0)
            break; // the end (also of an unclosed quote)
        if (quotesUnicode)
        {
            if (out != NULL)
            {
                if (len + 2 > outSize)
                    return SALHEXPAT_TOOLONG;
                out[len] = (char)(*s & 0xFF);
                out[len + 1] = (char)(*s >> 8);
            }
            s++;
            len += 2;
            continue;
        }
        if (quotesCodePage)
        {
            // the whole text up to the closing quote (or the end), converted at once
            const WCHAR* end = s;
            while (*end != 0 && *end != L'\'')
                end++;
            int units = (int)(end - s);
            if (units > 0) // ('' is no byte)
            {
                int bytes = WideCharToMultiByte(codePage, 0, s, units, NULL, 0, NULL, NULL);
                if (bytes <= 0)
                    return SALHEXPAT_BAD;
                if (out != NULL)
                {
                    if (bytes > outSize - len)
                        return SALHEXPAT_TOOLONG;
                    if (WideCharToMultiByte(codePage, 0, s, units, out + len, bytes, NULL, NULL) != bytes)
                        return SALHEXPAT_BAD;
                }
                len += bytes;
            }
            s = end;
            continue;
        }
        int d = SalHexPatternDigit(*s);
        if (d >= 0)
        {
            int d2 = SalHexPatternDigit(s[1]);
            if (d2 < 0 && strict)
                return SALHEXPAT_BAD; // a byte has two digits
            if (out != NULL)
            {
                if (len + 1 > outSize)
                    return SALHEXPAT_TOOLONG;
                out[len] = (char)(d2 >= 0 ? (d << 4) | d2 : d);
            }
            s += d2 >= 0 ? 2 : 1;
            len++;
            continue;
        }
        if (strict && *s != L' ')
            return SALHEXPAT_BAD;
        s++; // a separator
    }
    if (outLen != NULL)
        *outLen = len;
    return SALHEXPAT_OK;
}
