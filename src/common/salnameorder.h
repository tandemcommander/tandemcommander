// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnameorder.h
//
// "Is it the same file name?" and a sort order that agrees with it, for a
// plug-in that cannot compile the core's salunicode.cpp (feature 115: the
// Undelete plug-in, whose sources find precomp.h beside themselves).
// Header-only, no globals except a lazily built byte table; saltests checks it
// against the core's functions.
//
//   SalNameOrderCompareCI  = SalNameCompareOrdinalCI (salunicode.cpp) exactly
//   SalNameOrderEqualCI    = SalNameEqualOrdinalCI exactly
//
// The rule is feature 092's (specs/092-name-identity-unicode/contracts/
// name-identity.md): two valid WTF-8 names are the same name when
// CompareStringOrdinal(..., TRUE) says so on their UTF-16 form - what Windows
// calls one file name ("C-caron.txt" and "c-caron.txt" are one file); no
// character outside ASCII equals an ASCII one; text that is not WTF-8 (a legacy
// plug-in's name) sorts after valid text and among itself by the legacy byte
// fold (CharLowerA per byte - the core's StrICmpEx). The compare function is a
// total order over all byte strings, so a list sorted by it holds every group
// of equal names in one run (a duplicate scan of neighbours finds them all).
//
// The Undelete plug-in used _stricmp (ASCII fold only): two deleted files
// "C-caron.txt" and "c-caron.txt" of one folder were not numbered, and the
// second restore asked to overwrite the first.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>
#include <stdlib.h>

namespace SalNameOrderDetail
{
inline BYTE AsciiUpper(BYTE c)
{
    return (c >= 'a' && c <= 'z') ? (BYTE)(c - ('a' - 'A')) : c;
}

// the legacy fold of str.cpp (LowerCase[] = CharLowerA per byte); filling it twice from two
// threads writes the same values
inline const BYTE* LegacyLowerTable()
{
    static BYTE table[256];
    static volatile LONG ready = 0;
    if (!ready)
    {
        for (int i = 0; i < 256; i++)
            table[i] = (BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)i);
        InterlockedExchange(&ready, 1);
    }
    return table;
}

// exactly StrICmpEx (str.cpp)
inline int LegacyCompareCI(const char* a, int la, const char* b, int lb)
{
    const BYTE* lower = LegacyLowerTable();
    int l = la < lb ? la : lb;
    for (int i = 0; i < l; i++)
    {
        int res = (int)lower[(BYTE)a[i]] - (int)lower[(BYTE)b[i]];
        if (res != 0)
            return res < 0 ? -1 : 1;
    }
    if (la != lb)
        return la < lb ? -1 : 1;
    return 0;
}

// WTF-8 -> UTF-16, the core's decoder exactly (salunicode.cpp SalWtf8ToWBytes): strict UTF-8
// whose 3-byte sequences may also decode to a lone surrogate. 'buf' NULL = count only.
// Returns the unit count, -1 when the text is not valid WTF-8, -2 when 'buf' is too small.
inline int Wtf8ToW(const char* src, int bytes, WCHAR* buf, int bufSize)
{
    const unsigned char* s = (const unsigned char*)src;
    int out = 0;
    int i = 0;
    while (i < bytes)
    {
        DWORD cp;
        int seq;
        unsigned char b = s[i];
        if (b < 0x80)
        {
            cp = b;
            seq = 1;
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
            return -1; // stray continuation, overlong C0/C1, or F5..FF
        if (i + seq > bytes)
            return -1; // cut sequence
        for (int k = 1; k < seq; k++)
        {
            unsigned char c = s[i + k];
            if (c < 0x80 || c > 0xBF)
                return -1;
            cp = (cp << 6) | (c & 0x3F);
        }
        if ((seq == 2 && cp < 0x80) || (seq == 3 && cp < 0x800) || (seq == 4 && (cp < 0x10000 || cp > 0x10FFFF)))
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

// the UTF-16 form of a WTF-8 text: on the stack up to 519 bytes, on the heap above
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
            Heap = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
            if (Heap == NULL)
                return FALSE;
            buf = Heap;
            size = len + 1;
        }
        int n = Wtf8ToW(s, len, buf, size);
        if (n < 0)
            return FALSE;
        Text = buf;
        Units = n;
        return TRUE;
    }

    WCHAR Stack[520];
    WCHAR* Heap;
    const WCHAR* Text;
    int Units;

private:
    CWide(const CWide&);
    CWide& operator=(const CWide&);
};
} // namespace SalNameOrderDetail

// The order of two names, case ignored: < 0, 0 (the same name), > 0. Lengths in bytes, -1 = up
// to the terminator; NULL = "". The same result as the core's SalNameCompareOrdinalCI for every
// input (saltests); for two valid WTF-8 names it is CompareStringOrdinal(..., TRUE) on the whole
// names. Low memory (a name over 519 bytes that needs a heap buffer): the tail is ordered as text
// that is not WTF-8 - deterministic, never "the same name" unless the bytes fold equal.
inline int SalNameOrderCompareCI(const char* a, int aLen, const char* b, int bLen)
{
    using namespace SalNameOrderDetail;
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
    // lexicographic over the leading ASCII characters (folded to upper case), then the tail -
    // everything from the first non-ASCII byte on (an ASCII unit sorts below every other unit and
    // equals none of them, so this IS the ordinal comparison of the whole names)
    int i = 0;
    while (1)
    {
        BOOL endA = aLen < 0 ? a[i] == 0 : i >= aLen;
        BOOL endB = bLen < 0 ? b[i] == 0 : i >= bLen;
        if (endA || endB) // one is a prefix of the other (ignoring ASCII case): the shorter is smaller
            return endA && endB ? 0 : (endA ? -1 : 1);
        BYTE ra = (BYTE)a[i];
        BYTE rb = (BYTE)b[i];
        if ((ra | rb) & 0x80)
            break;
        BYTE ca = AsciiUpper(ra);
        BYTE cb = AsciiUpper(rb);
        if (ca != cb)
            return ca < cb ? -1 : 1;
        i++;
    }
    if (((BYTE)a[i] & 0x80) == 0)
        return -1; // an ASCII character against a tail
    if (((BYTE)b[i] & 0x80) == 0)
        return 1;

    // two tails: valid WTF-8 ones by the file system's rule, text that is not WTF-8 after them
    // and among itself by the legacy byte fold
    const char* ta = a + i;
    const char* tb = b + i;
    int lta = aLen < 0 ? (int)strlen(ta) : aLen - i;
    int ltb = bLen < 0 ? (int)strlen(tb) : bLen - i;
    CWide wa, wb;
    BOOL va = wa.Set(ta, lta);
    BOOL vb = wb.Set(tb, ltb);
    if (va && vb)
    {
        int cmp = CompareStringOrdinal(wa.Text, wa.Units, wb.Text, wb.Units, TRUE);
        if (cmp == 0) // cannot happen with valid arguments; stay deterministic
            return LegacyCompareCI(ta, lta, tb, ltb);
        return cmp - CSTR_EQUAL;
    }
    if (va)
        return -1;
    if (vb)
        return 1;
    return LegacyCompareCI(ta, lta, tb, ltb);
}

// Is 'a' the same name as 'b' (case ignored)? = SalNameOrderCompareCI(...) == 0, with the
// byte-identical and "two different ASCII first characters" answers found without converting.
inline BOOL SalNameOrderEqualCI(const char* a, int aLen, const char* b, int bLen)
{
    using namespace SalNameOrderDetail;
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
    if (aLen != 0 && bLen != 0)
    {
        BYTE fa = (BYTE)a[0];
        BYTE fb = (BYTE)b[0];
        if (((fa | fb) & 0x80) == 0 && AsciiUpper(fa) != AsciiUpper(fb))
            return FALSE;
    }
    int la = aLen < 0 ? (int)strlen(a) : aLen;
    int lb = bLen < 0 ? (int)strlen(b) : bLen;
    if (la == lb && memcmp(a, b, la) == 0)
        return TRUE; // byte-identical
    return SalNameOrderCompareCI(a, la, b, lb) == 0;
}
