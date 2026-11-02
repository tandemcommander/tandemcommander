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
// SalRegKeyIdBelow  - the path of 'key' below 'outer' (the part after 'outer'
//                     and its '\') when 'key' lies strictly inside 'outer';
//                     NULL when it is 'outer' itself or not inside (feature
//                     294: a Copy / Move into a key that holds the source
//                     writes target\P for each subkey path P of the source -
//                     into the source itself when P begins with this path).
//
// SalRegHkcrDeleteHalf - feature 390: where a Move deletes a source key of
//                     HKEY_CLASSES_ROOT. The copy may create the user's half of
//                     the very path it copies (a machine-only key moved into
//                     HKCU\Software\Classes\), and a delete through the merged
//                     view reaches the user's half first - the copy, not the
//                     source (the Move did nothing and reported success). So the
//                     halves holding the key are noted before that key is
//                     copied: exactly one = delete that half by its real path;
//                     both or none = through HKEY_CLASSES_ROOT as before.
// SalRegJoinClassesPath - "Software\Classes\" + key into 'out' (the path of an
//                     HKCR key in either half); FALSE (out = "") when 'key' is
//                     empty or the result does not fit 'outUnits' - never cut.
//
// Header-only (the plug-ins cannot compile a .cpp from src\common); needs
// <windows.h>; checked by saltests.
//

#define SAL_REGKEYID_MAX 1280 // units incl. the terminator: \REGISTRY\... + a 512-unit path + a 512-unit name
#define SAL_REGKEYIDS_MAX 6   // the Registry Editor needs at most 2 (a key of HKCR in both halves)

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

inline const WCHAR* SalRegKeyIdBelow(const WCHAR* key, const WCHAR* outer)
{
    int lk = SalRegKeyIdLen(key), lo = SalRegKeyIdLen(outer);
    if (lk == 0 || lo == 0 || lk <= lo + 1)
        return NULL;
    if (key[lo] != L'\\' || CompareStringOrdinal(key, lo, outer, lo, TRUE) != CSTR_EQUAL)
        return NULL;
    return key + lo + 1;
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

enum CSalHkcrDeleteHalf
{
    SAL_HKCR_DELETE_VIEW,    // through HKEY_CLASSES_ROOT (as before)
    SAL_HKCR_DELETE_MACHINE, // HKEY_LOCAL_MACHINE\Software\Classes\<key>
    SAL_HKCR_DELETE_USER,    // HKEY_CURRENT_USER\Software\Classes\<key>
};

inline CSalHkcrDeleteHalf SalRegHkcrDeleteHalf(BOOL machineHeld, BOOL userHeld)
{
    if (machineHeld && !userHeld)
        return SAL_HKCR_DELETE_MACHINE;
    if (userHeld && !machineHeld)
        return SAL_HKCR_DELETE_USER;
    return SAL_HKCR_DELETE_VIEW;
}

inline BOOL SalRegJoinClassesPath(WCHAR* out, int outUnits, const WCHAR* key)
{
    static const WCHAR prefix[] = L"Software\\Classes\\";
    const int lp = (int)(sizeof(prefix) / sizeof(WCHAR)) - 1;
    if (out == NULL || outUnits <= 0)
        return FALSE;
    out[0] = 0;
    int lk = SalRegKeyIdLen(key);
    if (lk == 0 || lp + lk >= outUnits)
        return FALSE;
    memcpy(out, prefix, lp * sizeof(WCHAR));
    memcpy(out + lp, key, lk * sizeof(WCHAR));
    out[lp + lk] = 0;
    return TRUE;
}
