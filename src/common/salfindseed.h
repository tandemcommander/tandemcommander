// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfindseed.h (feature 398)
//
// The internal viewer's Find pre-fills its field with the selected text (a
// seed - a suggestion the user sees before OK, not the user's text). Before
// 398 the selection's raw bytes went to the field through an ANSI WM_SETTEXT:
// a UTF-8 selection became code-page mojibake (U+00E9 as U+0102 U+00A9), the
// search looked for that, and since 311 a long selection was refused at OK
// ("The path specified is too long.") because its mojibake did not fit the
// 200 UTF-8 bytes the search text takes.
//
//   SalFindSeedDecodeW - decodes the selected bytes by the viewer's content
//                        encoding (enc = the viewer's VCE_* value: 0 code page
//                        'codePage', 1 UTF-8, 2 UTF-16 LE, 3 UTF-16 BE) into
//                        UTF-16, character by character, and keeps the longest
//                        beginning of whole characters whose length stays
//                        within 'maxUnits' UTF-16 units (the field's limit) and
//                        whose UTF-8 form stays within 'maxU8Bytes' bytes (what
//                        OK accepts) and that leaves room for the terminator in
//                        'outCap'. The text ends at a NUL character and at an
//                        incomplete character at the end of 'bytes' when more of
//                        the selection follows (the read limit fell inside it,
//                        'atEnd' FALSE); when 'bytes' end where the selection
//                        ends ('atEnd' TRUE) such a character is U+FFFD for its
//                        first byte, as the viewer draws it. UTF-8: an invalid lead or
//                        continuation byte, an overlong form, a surrogate or a
//                        value above U+10FFFF is U+FFFD for one byte. UTF-16: a
//                        surrogate pair is one character (two units, four UTF-8
//                        bytes), a lone surrogate is U+FFFD. Code page: a lead
//                        byte (IsDBCSLeadByteEx) takes the next byte, each
//                        character through MultiByteToWideChar (a failure is
//                        U+FFFD); a code page that is UTF-8 (CP_UTF8, or CP_ACP
//                        on a system whose ANSI code page is 65001) is decoded
//                        as UTF-8. Returns the units written (out[ret] == 0), or
//                        -1 for out == NULL / outCap <= 0.
//
// Header-only and pure apart from the two code-page calls: saltests
// (TestFindSeed398).
//
//*****************************************************************************

#include <windows.h>

// the UTF-8 length of the character held in 'w' (one unit, or a surrogate pair when n == 2)
inline int SalFindSeedU8Len(const wchar_t* w, int n)
{
    if (n == 2 && w[0] >= 0xD800 && w[0] <= 0xDBFF && w[1] >= 0xDC00 && w[1] <= 0xDFFF)
        return 4;
    int len = 0;
    for (int k = 0; k < n; k++)
    {
        unsigned int c = (unsigned int)w[k];
        len += c < 0x80 ? 1 : c < 0x800 ? 2 : 3;
    }
    return len;
}

// one character of UTF-8 at 'p' ('avail' bytes): returns the bytes it takes, 0 when the bytes end
// inside a well-formed beginning of a sequence (incomplete); *cp receives the code point (U+FFFD for
// an invalid byte, which then takes one byte)
inline int SalFindSeedUtf8Char(const unsigned char* p, int avail, unsigned int* cp)
{
    unsigned char c = p[0];
    if (c < 0x80)
    {
        *cp = c;
        return 1;
    }
    int need;
    unsigned int v;
    unsigned char lo = 0x80, hi = 0xBF; // the allowed range of the second byte
    if (c >= 0xC2 && c <= 0xDF)
    {
        need = 1;
        v = c & 0x1F;
    }
    else if (c >= 0xE0 && c <= 0xEF)
    {
        need = 2;
        v = c & 0x0F;
        if (c == 0xE0)
            lo = 0xA0; // no overlong form
        if (c == 0xED)
            hi = 0x9F; // no surrogate
    }
    else if (c >= 0xF0 && c <= 0xF4)
    {
        need = 3;
        v = c & 0x07;
        if (c == 0xF0)
            lo = 0x90; // no overlong form
        if (c == 0xF4)
            hi = 0x8F; // not above U+10FFFF
    }
    else
    {
        *cp = 0xFFFD; // a continuation byte, C0, C1, F5..FF
        return 1;
    }
    for (int k = 1; k <= need; k++)
    {
        if (k >= avail)
            return 0; // well-formed so far, cut by the end of the bytes
        unsigned char cc = p[k];
        unsigned char kl = (k == 1) ? lo : 0x80;
        unsigned char kh = (k == 1) ? hi : 0xBF;
        if (cc < kl || cc > kh)
        {
            *cp = 0xFFFD;
            return 1;
        }
        v = (v << 6) | (cc & 0x3F);
    }
    *cp = v;
    return need + 1;
}

inline int SalFindSeedDecodeW(const unsigned char* bytes, int n, bool atEnd, int enc, unsigned int codePage,
                              wchar_t* out, int outCap, int maxUnits, int maxU8Bytes)
{
    if (out == NULL || outCap <= 0)
        return -1;
    out[0] = 0;
    if (bytes == NULL || n <= 0)
        return 0;
    // review 1: a code page that is UTF-8 (the system's ANSI code page set to 65001, "Use Unicode
    // UTF-8 for worldwide language support") is decoded as UTF-8 - byte by byte through
    // MultiByteToWideChar every non-ASCII letter would be U+FFFD, and the viewer draws it as UTF-8
    if (enc == 0 && (codePage == CP_UTF8 || (codePage == CP_ACP && GetACP() == CP_UTF8)))
        enc = 1;
    int units = 0, u8 = 0, i = 0;
    while (i < n)
    {
        wchar_t w[2];
        int nw = 1, take = 0;
        if (enc == 1) // UTF-8
        {
            unsigned int cp;
            take = SalFindSeedUtf8Char(bytes + i, n - i, &cp);
            if (take == 0)
            {
                if (!atEnd)
                    break; // an incomplete character at the read limit
                cp = 0xFFFD; // at the end of the selection: drawn as U+FFFD
                take = 1;
            }
            if (cp >= 0x10000)
            {
                cp -= 0x10000;
                w[0] = (wchar_t)(0xD800 + (cp >> 10));
                w[1] = (wchar_t)(0xDC00 + (cp & 0x3FF));
                nw = 2;
            }
            else
                w[0] = (wchar_t)cp;
        }
        else if (enc == 2 || enc == 3) // UTF-16 LE / BE
        {
            if (i + 1 >= n)
            {
                if (!atEnd)
                    break; // an odd byte at the read limit
                w[0] = 0xFFFD; // an odd last byte of the selection
                take = 1;
                goto append;
            }
            unsigned int a = (enc == 2) ? (bytes[i] | (bytes[i + 1] << 8)) : (bytes[i + 1] | (bytes[i] << 8));
            take = 2;
            w[0] = (wchar_t)a;
            if (a >= 0xD800 && a <= 0xDBFF)
            {
                if (i + 3 >= n)
                {
                    if (!atEnd)
                        break; // a high surrogate at the read limit: its pair may follow
                    w[0] = 0xFFFD; // the last unit of the selection
                    goto append;
                }
                unsigned int b = (enc == 2) ? (bytes[i + 2] | (bytes[i + 3] << 8)) : (bytes[i + 3] | (bytes[i + 2] << 8));
                if (b >= 0xDC00 && b <= 0xDFFF)
                {
                    w[1] = (wchar_t)b;
                    nw = 2;
                    take = 4;
                }
                else
                    w[0] = 0xFFFD;
            }
            else if (a >= 0xDC00 && a <= 0xDFFF)
                w[0] = 0xFFFD;
        }
        else // code page
        {
            take = 1;
            if (IsDBCSLeadByteEx(codePage, bytes[i]))
            {
                if (i + 1 >= n)
                {
                    if (!atEnd)
                        break; // a lead byte at the read limit
                    w[0] = 0xFFFD; // the last byte of the selection
                    goto append;
                }
                take = 2;
            }
            wchar_t cw[4];
            int got = MultiByteToWideChar(codePage, 0, (const char*)(bytes + i), take, cw, 4);
            if (got == 1 || got == 2)
            {
                w[0] = cw[0];
                if (got == 2)
                    w[1] = cw[1];
                nw = got;
            }
            else
                w[0] = 0xFFFD;
        }
    append:
        if (w[0] == 0)
            break; // the field cannot hold a NUL (the old WM_SETTEXT ended there too)
        int b8 = SalFindSeedU8Len(w, nw);
        if (units + nw > maxUnits || units + nw >= outCap || u8 + b8 > maxU8Bytes)
            break; // the first character that does not fit ends the seed
        out[units] = w[0];
        if (nw == 2)
            out[units + 1] = w[1];
        units += nw;
        u8 += b8;
        i += take;
    }
    out[units] = 0;
    return units;
}
