// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The Registry Editor's "is it the same key?" (feature 292)
//
// One registry key has several names: HKEY_CURRENT_USER\X is also
// HKEY_USERS\<the user's SID>\X, HKEY_CLASSES_ROOT\X is HKCU\Software\Classes\X
// or HKLM\Software\Classes\X, HKEY_CURRENT_CONFIG and CurrentControlSet are
// registry links. Copy / Move decided "onto itself" by the root and the path
// text, so a Move of a key into its own parent written under another root name
// "moved" the key onto itself and then deleted it - the only copy.
//
// The identity of a key is the full internal name the registry reports for the
// opened key (\REGISTRY\USER\<SID>\X, \REGISTRY\MACHINE\...). A key path may
// have several identities (a set): HKEY_CLASSES_ROOT is a merged view, and a
// key that does not exist yet has its parent's identities joined with its name.
//
// SalRegKeyIdSame   - two identities are one key: equal, case ignored
//                     (CompareStringOrdinal(..., TRUE); the registry ignores
//                     case). An empty identity is never the same as anything.
// SalRegKeyIdWithin - 'key' is 'outer' or lies inside it: 'outer' is a prefix
//                     of 'key' (case ignored) ending at a whole path element.
// SalRegKeyIdsAdd   - appends 'parent' or 'parent\name' to a set; FALSE (the
//                     set unchanged) when 'parent' is empty, the set is full or
//                     the text does not fit SAL_REGKEYID_MAX - never cut.
// SalRegKeyIdsAnySame / SalRegKeyIdsAnyWithin - some pair of the two sets.
//
// Header-only (the plug-ins cannot compile a .cpp from src\common); needs
// <windows.h>; checked by saltests.
//

#define SAL_REGKEYID_MAX 1280 // units incl. the terminator: \REGISTRY\... + a 512-unit path + a 512-unit name
#define SAL_REGKEYIDS_MAX 6 // the Registry Editor needs at most 2 (the HKCR root: both halves)

struct CSalRegKeyIds
{
    int Count;
    WCHAR Id[SAL_REGKEYIDS_MAX][SAL_REGKEYID_MAX];
};

inline int SalRegKeyIdLen(const WCHAR* s)
{
    int n = 0;
    if (s != NULL)
        while (s[n] != 0)
            n++;
    return n;
}

inline BOOL SalRegKeyIdSame(const WCHAR* a, const WCHAR* b)
{
    int la = SalRegKeyIdLen(a), lb = SalRegKeyIdLen(b);
    if (la == 0 || lb == 0)
        return FALSE;
    return CompareStringOrdinal(a, la, b, lb, TRUE) == CSTR_EQUAL;
}

inline BOOL SalRegKeyIdWithin(const WCHAR* key, const WCHAR* outer)
{
    int lk = SalRegKeyIdLen(key), lo = SalRegKeyIdLen(outer);
    if (lk == 0 || lo == 0 || lk < lo)
        return FALSE;
    if (CompareStringOrdinal(key, lo, outer, lo, TRUE) != CSTR_EQUAL)
        return FALSE;
    return lk == lo || key[lo] == L'\\';
}

inline BOOL SalRegKeyIdsAdd(CSalRegKeyIds& set, const WCHAR* parent, const WCHAR* name)
{
    int lp = SalRegKeyIdLen(parent), ln = SalRegKeyIdLen(name);
    if (lp == 0 || set.Count < 0 || set.Count >= SAL_REGKEYIDS_MAX)
        return FALSE;
    int total = lp + (ln > 0 ? 1 + ln : 0);
    if (total >= SAL_REGKEYID_MAX)
        return FALSE;
    WCHAR* out = set.Id[set.Count];
    memcpy(out, parent, lp * sizeof(WCHAR));
    if (ln > 0)
    {
        out[lp] = L'\\';
        memcpy(out + lp + 1, name, ln * sizeof(WCHAR));
    }
    out[total] = 0;
    set.Count++;
    return TRUE;
}

inline BOOL SalRegKeyIdsAnySame(const CSalRegKeyIds& a, const CSalRegKeyIds& b)
{
    for (int i = 0; i < a.Count; i++)
        for (int j = 0; j < b.Count; j++)
            if (SalRegKeyIdSame(a.Id[i], b.Id[j]))
                return TRUE;
    return FALSE;
}

inline BOOL SalRegKeyIdsAnyWithin(const CSalRegKeyIds& inner, const CSalRegKeyIds& outer)
{
    for (int i = 0; i < inner.Count; i++)
        for (int j = 0; j < outer.Count; j++)
            if (SalRegKeyIdWithin(inner.Id[i], outer.Id[j]))
                return TRUE;
    return FALSE;
}
