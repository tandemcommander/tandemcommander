// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salu8fold.h
//
// Feature 210: a case-insensitive search over UTF-8 names by a byte engine (the Renamer's
// Boyer-Moore and regular expressions) folded the BYTES through the code page's table - with
// cp1250 the continuation bytes 8A and 9A are one letter's two cases, so "C-dot" (C4 8A) matched
// "E-caron" (C4 9A) and the Renamer replaced the wrong letter; a lead byte could be folded alone
// and a letter cut. Here the text is folded by CHARACTERS: each one whose lower-case form has the
// same UTF-8 length is replaced by it, everything else is copied - the folded text has the
// original's length, an offset in it is an offset in the original, and a match of folded
// characters lies on whole characters (UTF-8 synchronizes itself). Two letters fold to one only
// when they are one letter in two cases (a pair of different UTF-8 lengths stays case-sensitive).
// Bytes that are not valid UTF-8 (a legacy name, a WTF-8 surrogate) are copied unchanged.
//
// Header-only (plug-ins use it); checked by saltests. Regular expressions still judge \b, \w,
// classes and '.' by single bytes (a byte engine) - recorded in NEXT-WORK.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// the length of the valid UTF-8 character at 'in' (at most 'avail' bytes) and its code point, or 0
inline int SalU8DecodeChar(const unsigned char* in, int avail, unsigned* cp)
{
    if (avail <= 0)
        return 0;
    unsigned c = in[0];
    if (c < 0x80)
    {
        *cp = c;
        return 1;
    }
    int n;
    unsigned v, min;
    if (c >= 0xC2 && c <= 0xDF)
        n = 2, v = c & 0x1F, min = 0x80;
    else if (c >= 0xE0 && c <= 0xEF)
        n = 3, v = c & 0x0F, min = 0x800;
    else if (c >= 0xF0 && c <= 0xF4)
        n = 4, v = c & 0x07, min = 0x10000;
    else
        return 0;
    if (avail < n)
        return 0;
    for (int i = 1; i < n; i++)
    {
        if ((in[i] & 0xC0) != 0x80)
            return 0;
        v = (v << 6) | (in[i] & 0x3F);
    }
    if (v < min || v > 0x10FFFF || (v >= 0xD800 && v <= 0xDFFF))
        return 0; // overlong, beyond Unicode, a surrogate (WTF-8): not valid UTF-8
    *cp = v;
    return n;
}

// UTF-8 of the code point 'cp' into 'out' (4 bytes); its length
inline int SalU8EncodeChar(unsigned cp, unsigned char* out)
{
    if (cp < 0x80)
    {
        out[0] = (unsigned char)cp;
        return 1;
    }
    if (cp < 0x800)
    {
        out[0] = (unsigned char)(0xC0 | (cp >> 6));
        out[1] = (unsigned char)(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000)
    {
        out[0] = (unsigned char)(0xE0 | (cp >> 12));
        out[1] = (unsigned char)(0x80 | ((cp >> 6) & 0x3F));
        out[2] = (unsigned char)(0x80 | (cp & 0x3F));
        return 3;
    }
    out[0] = (unsigned char)(0xF0 | (cp >> 18));
    out[1] = (unsigned char)(0x80 | ((cp >> 12) & 0x3F));
    out[2] = (unsigned char)(0x80 | ((cp >> 6) & 0x3F));
    out[3] = (unsigned char)(0x80 | (cp & 0x3F));
    return 4;
}

// the lower-case form of the code point 'cp' (CharLowerBuffW on its UTF-16)
inline unsigned SalU8LowerCodePoint(unsigned cp)
{
    WCHAR w[2];
    int units;
    if (cp < 0x10000)
    {
        w[0] = (WCHAR)cp;
        units = 1;
    }
    else
    {
        w[0] = (WCHAR)(0xD800 + ((cp - 0x10000) >> 10));
        w[1] = (WCHAR)(0xDC00 + ((cp - 0x10000) & 0x3FF));
        units = 2;
    }
    CharLowerBuffW(w, units);
    if (units == 1)
        return (w[0] >= 0xD800 && w[0] <= 0xDFFF) ? cp : w[0];
    if (w[0] >= 0xD800 && w[0] <= 0xDBFF && w[1] >= 0xDC00 && w[1] <= 0xDFFF)
        return 0x10000 + ((unsigned)(w[0] - 0xD800) << 10) + (w[1] - 0xDC00);
    return cp;
}

// 'len' bytes of 'in' folded into 'out' (the same 'len' bytes; it may be 'in' itself);
// 'onlyNonAscii': ASCII is left as it is (for an engine that folds ASCII itself)
inline void SalU8FoldSameLength(const char* in, int len, char* out, BOOL onlyNonAscii)
{
    const unsigned char* s = (const unsigned char*)in;
    unsigned char* d = (unsigned char*)out;
    int i = 0;
    while (i < len)
    {
        unsigned cp;
        int n = SalU8DecodeChar(s + i, len - i, &cp);
        if (n == 0) // not valid UTF-8: the byte as it is
        {
            d[i] = s[i];
            i++;
            continue;
        }
        if (n == 1)
        {
            unsigned char c = s[i];
            d[i] = (!onlyNonAscii && c >= 'A' && c <= 'Z') ? (unsigned char)(c + 32) : c;
            i++;
            continue;
        }
        unsigned char enc[4];
        unsigned lower = SalU8LowerCodePoint(cp);
        if (lower != cp && SalU8EncodeChar(lower, enc) == n)
            memcpy(d + i, enc, n);
        else
            memmove(d + i, s + i, n);
        i += n;
    }
}

// is the character starting at byte 'pos' of 'text' ('len' bytes) a letter or a digit? (whole words)
inline BOOL SalU8IsAlnumAt(const char* text, int len, int pos)
{
    if (pos < 0 || pos >= len)
        return FALSE;
    unsigned cp;
    int n = SalU8DecodeChar((const unsigned char*)text + pos, len - pos, &cp);
    if (n == 0)
        return FALSE;
    if (cp >= 0x10000)
        return FALSE; // outside the BMP: IsCharAlphaNumericW sees one unit only
    return IsCharAlphaNumericW((WCHAR)cp) ? TRUE : FALSE;
}

// is the character ENDING just before byte 'pos' of 'text' a letter or a digit?
inline BOOL SalU8IsAlnumBefore(const char* text, int len, int pos)
{
    if (pos <= 0 || pos > len)
        return FALSE;
    int start = pos - 1;
    while (start > 0 && pos - start < 4 && (((unsigned char)text[start]) & 0xC0) == 0x80)
        start--;
    unsigned cp;
    int n = SalU8DecodeChar((const unsigned char*)text + start, len - start, &cp);
    if (n == 0 || start + n != pos)
        return FALSE;
    if (cp >= 0x10000)
        return FALSE;
    return IsCharAlphaNumericW((WCHAR)cp) ? TRUE : FALSE;
}

// 'count' characters forward from 'from' (not past 'end'); a byte that is not valid UTF-8 counts
// as one character
inline const char* SalU8Advance(const char* from, const char* end, int count)
{
    while (count > 0 && from < end)
    {
        unsigned cp;
        int n = SalU8DecodeChar((const unsigned char*)from, (int)(end - from), &cp);
        from += n > 0 ? n : 1;
        count--;
    }
    return from;
}

// 'count' characters back from 'from' (not before 'start')
inline const char* SalU8Back(const char* from, const char* start, int count)
{
    while (count > 0 && from > start)
    {
        const char* p = from - 1;
        while (p > start && from - p < 4 && (((unsigned char)*p) & 0xC0) == 0x80)
            p--;
        unsigned cp;
        int n = SalU8DecodeChar((const unsigned char*)p, (int)(from - p), &cp);
        from = (n > 0 && p + n == from) ? p : from - 1;
        count--;
    }
    return from;
}
