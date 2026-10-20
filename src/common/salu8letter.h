// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salu8letter.h
//
// Feature 254: the letters ("units") of a UTF-8 (WTF-8) name for a byte engine - the Renamer's
// regular expressions stepped, backed off and classified single BYTES: '.' took the lead byte of
// a letter, "[z-caron]" matched it alone, '\w' judged the code page's meaning of a byte, '\b' found
// a "boundary" inside a Cyrillic word (a wrong letter was replaced) - and a new name holding half a
// letter was refused "(123)".
//
// A unit is a valid UTF-8 character, a WTF-8 lone surrogate (ED A0..BF 80..BF), or one byte that
// starts neither. Lead bytes are never continuation bytes, so units never overlap: stepping back
// from a boundary gives the same units as stepping forward from any earlier boundary. A unit's
// value is its code point, or SALU8_INVALID_BASE + the byte.
//
// Classification (SalU8LetterTypes): the C1 types of GetStringTypeW for the BMP; outside the BMP
// (where GetStringTypeW sees two surrogates) and for combining marks the general category of the
// system's Unicode library (icu.dll, part of every supported Windows; loaded from System32 at the
// first use, a missing library = no class).
//
// Header-only (plug-ins use it); checked by saltests.
//
//*****************************************************************************

#include "salu8fold.h"

#define SALU8_INVALID_BASE 0x110000u // value of a byte that starts no unit: base + the byte
#define SALU8_TYPE_MARK 0x10000u     // SalU8LetterTypes: a combining mark (Mn, Mc, Me)

// the length (1-4) of the unit at 'p' ('p' < 'end') and its value; 0 only when 'p' >= 'end'
inline int SalU8UnitLen(const char* p, const char* end, unsigned* value)
{
    int avail = (int)(end - p);
    if (avail <= 0)
        return 0;
    const unsigned char* s = (const unsigned char*)p;
    unsigned cp;
    int n = SalU8DecodeChar(s, avail, &cp);
    if (n > 0)
    {
        *value = cp;
        return n;
    }
    if (avail >= 3 && s[0] == 0xED && s[1] >= 0xA0 && s[1] <= 0xBF && (s[2] & 0xC0) == 0x80)
    {
        *value = 0xD000 | ((unsigned)(s[1] & 0x3F) << 6) | (s[2] & 0x3F); // a WTF-8 lone surrogate
        return 3;
    }
    *value = SALU8_INVALID_BASE + s[0];
    return 1;
}

// the start of the unit that ends at 'q' ('q' > 'start'), never before 'start'
inline const char* SalU8UnitBack(const char* start, const char* q)
{
    for (int k = 2; k <= 4 && q - start >= k; k++)
    {
        const char* p = q - k;
        unsigned char c = (unsigned char)*p;
        unsigned v;
        if (c >= 0xC2 && c <= 0xF4 && SalU8UnitLen(p, q, &v) == k)
            return p;
    }
    return q - 1;
}

// is 'q' not inside a multi-byte unit of the text 'start'..'end'?
inline BOOL SalU8IsUnitBoundary(const char* start, const char* end, const char* q)
{
    if (q <= start || q >= end)
        return TRUE;
    for (int k = 1; k <= 3 && q - k >= start; k++)
    {
        unsigned char c = (unsigned char)q[-k];
        if (c >= 0xC2 && c <= 0xF4) // a lead byte: 'q' is inside its unit when the unit reaches past it
        {
            unsigned v;
            return SalU8UnitLen(q - k, end, &v) <= k;
        }
        if ((c & 0xC0) != 0x80)
            return TRUE; // ASCII or a byte that starts nothing: no unit spans it
    }
    return TRUE;
}

// icu.dll's u_charType, or NULL when the library or the export is missing
typedef signed char(__cdecl* FSalU8IcuCharType)(int c);
inline FSalU8IcuCharType SalU8IcuCharType()
{
    static FSalU8IcuCharType fn = []() -> FSalU8IcuCharType
    {
        HMODULE m = LoadLibraryExW(L"icu.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (m == NULL)
            return NULL;
        return reinterpret_cast<FSalU8IcuCharType>(reinterpret_cast<void*>(GetProcAddress(m, "u_charType")));
    }();
    return fn;
}

// the C1 types of an ICU general category (UCharCategory)
inline unsigned SalU8TypesOfIcuCategory(int cat)
{
    switch (cat)
    {
    case 1: // Lu
    case 3: // Lt
        return C1_ALPHA | C1_UPPER;
    case 2: // Ll
        return C1_ALPHA | C1_LOWER;
    case 4:  // Lm
    case 5:  // Lo
    case 10: // Nl
        return C1_ALPHA;
    case 6: // Mn
    case 7: // Me
    case 8: // Mc
        return SALU8_TYPE_MARK;
    case 9: // Nd
        return C1_DIGIT;
    case 12: // Zs
        return C1_SPACE | C1_BLANK;
    case 13: // Zl
    case 14: // Zp
        return C1_SPACE;
    case 15: // Cc
        return C1_CNTRL;
    case 11: // No
    case 19: // Pd
    case 20: // Ps
    case 21: // Pe
    case 22: // Pc
    case 23: // Po
    case 24: // Sm
    case 25: // Sc
    case 26: // Sk
    case 27: // So
    case 28: // Pi
    case 29: // Pf
        return C1_PUNCT;
    }
    return 0; // unassigned, format, private use, surrogate
}

// the C1 types (C1_UPPER ... C1_ALPHA) and SALU8_TYPE_MARK of a unit's value; 0 for a byte that
// starts no unit and for a lone surrogate
inline unsigned SalU8LetterTypes(unsigned value)
{
    if (value >= SALU8_INVALID_BASE || (value >= 0xD800 && value <= 0xDFFF))
        return 0;
    FSalU8IcuCharType icu = SalU8IcuCharType();
    if (value >= 0x10000)
        return icu != NULL ? SalU8TypesOfIcuCategory(icu((int)value)) : 0;
    WCHAR w = (WCHAR)value;
    WORD t1 = 0, t3 = 0;
    GetStringTypeW(CT_CTYPE1, &w, 1, &t1);
    GetStringTypeW(CT_CTYPE3, &w, 1, &t3);
    unsigned types = t1 & (C1_UPPER | C1_LOWER | C1_DIGIT | C1_SPACE | C1_PUNCT | C1_CNTRL | C1_BLANK |
                           C1_XDIGIT | C1_ALPHA);
    if (icu != NULL)
    {
        int cat = icu((int)value);
        if (cat == 6 || cat == 7 || cat == 8)
            types |= SALU8_TYPE_MARK;
    }
    else if ((t3 & (C3_NONSPACING | C3_VOWELMARK)) != 0 && (t1 & C1_ALPHA) == 0)
        types |= SALU8_TYPE_MARK; // (Windows calls a precomposed letter with an accent "nonspacing" too)
    return types;
}

// a letter, a digit or a combining mark? (the Renamer's plain "Whole words")
inline BOOL SalU8IsAlnumValue(unsigned value)
{
    return (SalU8LetterTypes(value) & (C1_ALPHA | C1_DIGIT | SALU8_TYPE_MARK)) != 0;
}

// a word character of a regular expression: a letter, a digit, a combining mark or '_'
inline BOOL SalU8IsWordValue(unsigned value)
{
    return value == '_' || SalU8IsAlnumValue(value);
}

// is the unit starting at byte 'pos' of 'text' ('len' bytes) a letter, a digit or a mark? (whole words)
inline BOOL SalU8IsAlnumAt(const char* text, int len, int pos)
{
    if (pos < 0 || pos >= len)
        return FALSE;
    unsigned v;
    SalU8UnitLen(text + pos, text + len, &v);
    return SalU8IsAlnumValue(v);
}

// is the unit ENDING just before byte 'pos' of 'text' a letter, a digit or a mark?
inline BOOL SalU8IsAlnumBefore(const char* text, int len, int pos)
{
    if (pos <= 0 || pos > len)
        return FALSE;
    const char* p = SalU8UnitBack(text, text + pos);
    unsigned v;
    SalU8UnitLen(p, text + pos, &v);
    return SalU8IsAlnumValue(v);
}
