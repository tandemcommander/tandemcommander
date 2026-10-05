// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salzipname.h
//
// Is a ZIP member's name the same name as another one? (feature 110, contract
// specs/110-zip-plugin-name-matching/contracts/zip-member-identity.md)
// Header-only, no globals - the ZIP plug-in cannot compile a shared .cpp file
// (its sources find precomp.h beside themselves), and saltests checks it.
//
// The ZIP plug-in sees member names in UTF-8 (interface 104: ProcessName
// converts legacy OEM / code-page names). It used to compare them with
// CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE): the UTF-8 BYTES read as
// text of the system code page, compared linguistically - so on CP1250
// "\xC4\xA5" (h-circumflex) and "\xC4\xB9" (L-acute) were one name, and adding
// one replaced the other. The rule now is feature 092's
// (specs/092-name-identity-unicode/contracts/name-identity.md):
//
//   two valid WTF-8 strings   ordinal: CompareStringOrdinal on UTF-16 (case
//                              ignored when asked) - what Windows calls the
//                              same file name; no normalization, no locale
//   two strings that are not  the old comparison exactly: CompareStringA with
//   valid WTF-8 (legacy text) the user's locale (NORM_IGNORECASE when asked),
//                              equal byte counts only (the old callers had a
//                              length guard)
//   one valid, one not        never the same name
//
// For two names of one printable ASCII character each both rules agree
// (measured: probe/zip_collision_set.py). Longer ASCII names do NOT always: the
// old comparison was linguistic, and on a locale with digraphs (Czech, Slovak,
// Hungarian, Croatian ...) "ch" is one letter, so "cHata.txt" and "chata.txt"
// were two names before and are one now - what Windows sees (one file); the
// change only ever goes from "two names" to "one name" (review of 110: 1,140
// equal-length ASCII pairs of up to 4 characters on a Czech locale, none the
// other way).
// Out of memory (a name over 259 bytes that needs a heap buffer): only
// byte-identical names are equal - the caller then adds instead of replacing,
// it never deletes a member that is not the one meant.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>
#include <stdlib.h>

namespace SalZipNameDetail
{
// one WTF-8 sequence at 's' ('avail' bytes): returns its byte count (0 = malformed - a
// stray continuation byte, an overlong form, a cut sequence, beyond U+10FFFF) and its code
// point; the core's decoder exactly (salunicode.cpp SalWtf8ToWBytes): strict UTF-8 whose
// 3-byte sequences may also decode to a lone surrogate
inline int Seq(const unsigned char* s, int avail, DWORD* cpOut)
{
    if (avail <= 0)
        return 0;
    unsigned char b = s[0];
    DWORD cp;
    int seq;
    if (b < 0x80)
    {
        *cpOut = b;
        return 1;
    }
    else if (b >= 0xC2 && b <= 0xDF)
    {
        cp = b & 0x1F;
        seq = 2;
    }
    else if (b >= 0xE0 && b <= 0xEF)
    {
        cp = b & 0x0F;
        seq = 3;
    }
    else if (b >= 0xF0 && b <= 0xF4)
    {
        cp = b & 0x07;
        seq = 4;
    }
    else
        return 0;
    if (seq > avail)
        return 0;
    for (int k = 1; k < seq; k++)
    {
        unsigned char c = s[k];
        if (c < 0x80 || c > 0xBF)
            return 0;
        cp = (cp << 6) | (c & 0x3F);
    }
    if ((seq == 2 && cp < 0x80) || (seq == 3 && cp < 0x800) || (seq == 4 && (cp < 0x10000 || cp > 0x10FFFF)))
        return 0;
    *cpOut = cp;
    return seq;
}

// decodes 'bytes' bytes into 'buf' (NULL = count only); returns the UTF-16 unit count,
// -1 when the text is not valid WTF-8, -2 when 'buf' is too small
inline int ToW(const char* src, int bytes, WCHAR* buf, int bufSize)
{
    const unsigned char* s = (const unsigned char*)src;
    int out = 0;
    int i = 0;
    while (i < bytes)
    {
        DWORD cp;
        int seq = Seq(s + i, bytes - i, &cp);
        if (seq == 0)
            return -1;
        if (cp >= 0x10000)
        {
            if (buf != NULL)
            {
                if (out + 2 > bufSize)
                    return -2;
                buf[out] = (WCHAR)(0xD800 + ((cp - 0x10000) >> 10));
                buf[out + 1] = (WCHAR)(0xDC00 + ((cp - 0x10000) & 0x3FF));
            }
            out += 2;
        }
        else
        {
            if (buf != NULL)
            {
                if (out + 1 > bufSize)
                    return -2;
                buf[out] = (WCHAR)cp;
            }
            out++;
        }
        i += seq;
    }
    return out;
}

inline BOOL IsAscii(const char* s, int len)
{
    for (int i = 0; i < len; i++)
        if ((unsigned char)s[i] >= 0x80)
            return FALSE;
    return TRUE;
}

inline unsigned char AsciiUpper(unsigned char c)
{
    return (c >= 'a' && c <= 'z') ? (unsigned char)(c - ('a' - 'A')) : c;
}

inline BOOL AsciiEqual(const char* a, const char* b, int len, BOOL ignoreCase)
{
    if (!ignoreCase)
        return memcmp(a, b, len) == 0;
    for (int i = 0; i < len; i++)
        if (AsciiUpper((unsigned char)a[i]) != AsciiUpper((unsigned char)b[i]))
            return FALSE;
    return TRUE;
}

// the old comparison of the ZIP plug-in (kept for text that is not WTF-8)
inline BOOL LegacyEqual(const char* a, int la, const char* b, int lb, BOOL ignoreCase)
{
    return CompareStringA(LOCALE_USER_DEFAULT, ignoreCase ? NORM_IGNORECASE : 0, a, la, b, lb) == CSTR_EQUAL;
}

// UTF-16 form of a valid WTF-8 text: on the stack up to 259 bytes, on the heap above
class CWide
{
public:
    CWide() : Heap(NULL), Text(NULL), Units(0) {}
    ~CWide()
    {
        if (Heap != NULL)
            free(Heap);
    }
    // FALSE when the text is not valid WTF-8 or memory is low
    BOOL Set(const char* s, int len)
    {
        WCHAR* buf = Stack;
        int size = _countof(Stack);
        if (len + 1 > size) // units never outnumber bytes
        {
            Heap = (WCHAR*)malloc((len + 1) * sizeof(WCHAR));
            if (Heap == NULL)
                return FALSE;
            buf = Heap;
            size = len + 1;
        }
        int n = ToW(s, len, buf, size);
        if (n < 0)
            return FALSE;
        Text = buf;
        Units = n;
        return TRUE;
    }

    WCHAR Stack[260];
    WCHAR* Heap;
    const WCHAR* Text;
    int Units;
};
} // namespace SalZipNameDetail

// TRUE when the 'len' bytes at 's' are valid WTF-8 (-1 = up to the terminator)
inline BOOL SalZipNameIsWtf8(const char* s, int len)
{
    if (s == NULL)
        return TRUE;
    if (len < 0)
        len = (int)strlen(s);
    return SalZipNameDetail::ToW(s, len, NULL, 0) >= 0;
}

// Is 'a' the same name as 'b'? Lengths in bytes, -1 = up to the terminator; NULL = "".
// 'ignoreCase' FALSE: the same text (ordinal; for legacy text CompareStringA without flags).
inline BOOL SalZipNameEqual(const char* a, int aLen, const char* b, int bLen, BOOL ignoreCase)
{
    using namespace SalZipNameDetail;
    if (a == NULL)
    {
        a = "";
        aLen = 0;
    }
    if (b == NULL)
    {
        b = "";
        bLen = 0;
    }
    int la = aLen < 0 ? (int)strlen(a) : aLen;
    int lb = bLen < 0 ? (int)strlen(b) : bLen;
    if (la == lb && memcmp(a, b, la) == 0)
        return TRUE; // byte-identical
    BOOL asciiA = IsAscii(a, la);
    BOOL asciiB = IsAscii(b, lb);
    if (asciiA && asciiB) // no character outside ASCII equals an ASCII one (092, measured)
        return la == lb && AsciiEqual(a, b, la, ignoreCase);
    BOOL va = asciiA || ToW(a, la, NULL, 0) >= 0;
    BOOL vb = asciiB || ToW(b, lb, NULL, 0) >= 0;
    if (va && vb)
    {
        CWide wa, wb;
        if (!wa.Set(a, la) || !wb.Set(b, lb))
            return FALSE; // low memory: only byte-identical names (above) are the same
        return CompareStringOrdinal(wa.Text, wa.Units, wb.Text, wb.Units, ignoreCase) == CSTR_EQUAL;
    }
    if (!va && !vb) // legacy text: the old comparison, with the old equal-length guard
        return la == lb && LegacyEqual(a, la, b, lb, ignoreCase);
    return FALSE; // valid WTF-8 never equals legacy text
}

// Does 'path' begin with a name equal to the 'prefixLen' bytes of 'prefix' (-1 = all)?
// On TRUE '*pathBytes' (may be NULL) = the number of bytes of 'path' the prefix covers - it
// can differ from 'prefixLen' (7 case pairs have different UTF-8 lengths: U+023A / U+2C65 ...),
// so the caller looks at path[*pathBytes] (a backslash or the end), never at path[prefixLen].
// A prefix that would end inside a character of 'path' (or inside a surrogate pair) is not a
// prefix. A prefix that is not valid WTF-8 (legacy text) matches only a path that is not valid
// WTF-8 either, by the old comparison over 'prefixLen' bytes.
inline BOOL SalZipNamePrefix(const char* path, int pathLen, const char* prefix, int prefixLen, BOOL ignoreCase, int* pathBytes)
{
    using namespace SalZipNameDetail;
    if (pathBytes != NULL)
        *pathBytes = 0;
    if (path == NULL)
    {
        path = "";
        pathLen = 0;
    }
    if (prefix == NULL)
    {
        prefix = "";
        prefixLen = 0;
    }
    int ll = pathLen < 0 ? (int)strlen(path) : pathLen;
    int pl = prefixLen < 0 ? (int)strlen(prefix) : prefixLen;
    if (pl == 0)
        return TRUE;

    if (IsAscii(prefix, pl) && ll >= pl && IsAscii(path, pl))
    {
        if (!AsciiEqual(path, prefix, pl, ignoreCase))
            return FALSE;
        if (pathBytes != NULL)
            *pathBytes = pl;
        return TRUE;
    }

    int up = ToW(prefix, pl, NULL, 0);
    if (up < 0) // legacy prefix
    {
        if (ToW(path, ll, NULL, 0) >= 0 || ll < pl || ToW(path, pl, NULL, 0) >= 0)
            return FALSE; // valid WTF-8 never equals legacy text
        if (!LegacyEqual(path, pl, prefix, pl, ignoreCase))
            return FALSE;
        if (pathBytes != NULL)
            *pathBytes = pl;
        return TRUE;
    }

    // the bytes of 'path' that hold exactly 'up' UTF-16 units
    const unsigned char* s = (const unsigned char*)path;
    int pos = 0;
    int units = 0;
    DWORD cp = 0;
    while (units < up)
    {
        int seq = Seq(s + pos, ll - pos, &cp);
        if (seq == 0)
            return FALSE; // runs out, or not WTF-8 within the prefix's reach
        pos += seq;
        units += cp >= 0x10000 ? 2 : 1;
    }
    if (units != up)
        return FALSE; // the prefix would end inside a supplementary character
    if (cp >= 0xD800 && cp <= 0xDBFF && pos < ll)
    {
        DWORD next;
        if (Seq(s + pos, ll - pos, &next) != 0 && next >= 0xDC00 && next <= 0xDFFF)
            return FALSE; // inside a surrogate pair written as two sequences
    }
    CWide wp, wt;
    if (!wp.Set(prefix, pl) || !wt.Set(path, pos))
    {
        // low memory: only a byte-identical prefix
        if (pos != pl || memcmp(path, prefix, pl) != 0)
            return FALSE;
    }
    else if (CompareStringOrdinal(wt.Text, wt.Units, wp.Text, wp.Units, ignoreCase) != CSTR_EQUAL)
        return FALSE;
    if (pathBytes != NULL)
        *pathBytes = pos;
    return TRUE;
}

// The ZIP plug-in's update matching (add.cpp CZipPack::MatchFiles): is the member 'inZip'
// the item 'target'? Both are full paths inside the archive, '\' separated; the first
// 'rootLen' bytes of 'target' are the panel's folder in the archive (ZipRoot), compared
// case-insensitively in a DOS/Windows archive and case-sensitively in a Unix one
// ('rootIgnoreCase'); the rest (it starts with '\' when 'rootLen' > 0) always ignoring case.
// '*rootBytes' (may be NULL) = the bytes of 'inZip' that hold the folder.
inline BOOL SalZipMemberIs(const char* inZip, int inZipLen, const char* target, int targetLen, int rootLen,
                           BOOL rootIgnoreCase, int* rootBytes)
{
    if (rootBytes != NULL)
        *rootBytes = 0;
    if (inZip == NULL)
        inZip = "";
    if (target == NULL)
        target = "";
    int li = inZipLen < 0 ? (int)strlen(inZip) : inZipLen;
    int lt = targetLen < 0 ? (int)strlen(target) : targetLen;
    if (rootLen < 0 || rootLen > lt)
        return FALSE;
    int c = 0;
    if (!SalZipNamePrefix(inZip, li, target, rootLen, rootIgnoreCase, &c))
        return FALSE;
    if (!SalZipNameEqual(inZip + c, li - c, target + rootLen, lt - rootLen, TRUE))
        return FALSE;
    if (rootBytes != NULL)
        *rootBytes = c;
    return TRUE;
}

// The same, for "is the member 'inZip' the item 'target' or inside it?" (a folder that a
// Move does not add because the archive already holds it or something in it)
inline BOOL SalZipMemberIsOrIsIn(const char* inZip, int inZipLen, const char* target, int targetLen, int rootLen,
                                 BOOL rootIgnoreCase)
{
    if (inZip == NULL)
        inZip = "";
    if (target == NULL)
        target = "";
    int li = inZipLen < 0 ? (int)strlen(inZip) : inZipLen;
    int lt = targetLen < 0 ? (int)strlen(target) : targetLen;
    if (rootLen < 0 || rootLen > lt)
        return FALSE;
    int c1 = 0;
    int c2 = 0;
    if (!SalZipNamePrefix(inZip, li, target, rootLen, rootIgnoreCase, &c1) ||
        !SalZipNamePrefix(inZip + c1, li - c1, target + rootLen, lt - rootLen, TRUE, &c2))
        return FALSE;
    return c1 + c2 == li || inZip[c1 + c2] == '\\';
}
