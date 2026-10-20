// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcodetable.h
//
// The Code Viewer's encoding list with the product's conversion tables
// (feature 262). Header-only, no globals; saltests checks it; the codeview
// plug-in (viewer.cpp, intake.cpp) uses it.
//
// The list has five fixed positions - UTF-8, UTF-8 with BOM, UTF-16 LE,
// UTF-16 BE, the system code page (0..4, the plug-in's CvEncoding values) -
// followed by the conversion tables EnumConversionTables hands out (position
// 5 + table index; separators are not positions). A table is applied as the
// built-in viewer applies it: every byte replaced by table[byte], the result
// read in the system code page.
//
// Table names are code-page bytes (the CCodeTablesData::Name invariant of
// feature 069, B-5): they are compared byte for byte, never folded.
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

#include <string>

#define SAL_CODETABLE_FIXED 5 // the five fixed positions
#define SAL_CODETABLE_ANSI 4  // "System code page" (CvEncoding cvEncAnsi)

// Replaces every byte of 'buf' by the table's byte, in place ('table' holds 256
// bytes; use as table[(unsigned char)c], spl_gen.h).
inline void SalCodeTableApply(unsigned char* buf, size_t n, const char* table)
{
    if (buf == NULL || table == NULL)
        return;
    for (size_t i = 0; i < n; i++)
        buf[i] = (unsigned char)table[buf[i]];
}

// The name for a status bar: a single '&' (menu hot-key) dropped, "&&" -> "&",
// trailing spaces trimmed (convert.cfg marks a table excluded from recognition
// with a trailing space). Still code-page bytes.
inline std::string SalCodeTableDisplayName(const char* name)
{
    std::string out;
    if (name == NULL)
        return out;
    for (const char* s = name; *s != 0; s++)
    {
        if (*s == '&')
        {
            if (s[1] == '&')
            {
                out += '&';
                s++;
            }
            continue;
        }
        out += *s;
    }
    while (!out.empty() && out[out.size() - 1] == ' ')
        out.erase(out.size() - 1);
    return out;
}

// The next ('dir' > 0) or previous ('dir' < 0) of 'count' positions, wrapping;
// a 'pos' outside the list counts as 0.
inline int SalCodeTableCycle(int pos, int dir, int count)
{
    if (count <= 0)
        return 0;
    if (pos < 0 || pos >= count)
        pos = 0;
    int step = dir > 0 ? 1 : dir < 0 ? -1 : 0;
    return ((pos + step) % count + count) % count;
}

// The list position of an encoding (0..4) or a table (>= 0, then 'encoding' is
// ignored).
inline int SalCodeTableListPos(int encoding, int table)
{
    return table >= 0 ? SAL_CODETABLE_FIXED + table : encoding;
}

// A list position (a menu command minus its first id) -> the encoding and the
// table (-1 = none). FALSE for a position outside the list.
inline BOOL SalCodeTableFromPos(int pos, int tableCount, int* encoding, int* table)
{
    if (pos < 0 || tableCount < 0 || pos >= SAL_CODETABLE_FIXED + tableCount)
        return FALSE;
    if (pos < SAL_CODETABLE_FIXED)
    {
        *encoding = pos;
        *table = -1;
    }
    else
    {
        *encoding = SAL_CODETABLE_ANSI;
        *table = pos - SAL_CODETABLE_FIXED;
    }
    return TRUE;
}

// The table a file is read with when it turns out single-byte:
//   detect (forcedEncoding < 0)       -> the remembered table (or -1)
//   "System code page" forced          -> the forced table (-1 = the system code page)
//   UTF-8 / UTF-16 forced              -> -1 (not single-byte)
inline int SalCodeTableToUse(int forcedEncoding, int forcedTable, int remembered)
{
    if (forcedEncoding < 0)
        return remembered >= 0 ? remembered : -1;
    if (forcedEncoding == SAL_CODETABLE_ANSI)
        return forcedTable >= 0 ? forcedTable : -1;
    return -1;
}

// The index of 'name' among 'names' (NULL entries are skipped, not counted -
// they are separators), byte for byte; -1 when absent or 'name' is empty.
inline int SalCodeTableFindName(const char* const* names, int count, const char* name)
{
    if (names == NULL || name == NULL || *name == 0)
        return -1;
    int index = 0;
    for (int i = 0; i < count; i++)
    {
        if (names[i] == NULL)
            continue;
        if (strcmp(names[i], name) == 0)
            return index;
        index++;
    }
    return -1;
}
