// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcasetwins.h
//
// Does a listing hold "case twins" - two names of one folder that differ only
// in case (feature 252)? Header-only, for the core, saltests and plug-ins
// (needs salnameorder.h beside it).
//
// An archive listing without SALDIRFLAG_CASESENSITIVE is compared
// case-insensitively by the core: CSalamanderDirectory::SalDirStrCmp (StrICmp,
// the legacy byte fold) merges folders "D" and "d" while the tree is built, and
// the panel's name lists (CNames, SalNameCompareOrdinalCI) take "a.txt" and
// "A.txt" for one name - Paste, Reselect, Restore Selection and Hide Selected
// Names acted on the twin nobody selected, and a TAR folder merged from "D" and
// "d" was extracted only in part. The 7-Zip and TAR plug-ins therefore build
// their listing case-sensitively and keep the flag only when this check finds
// twins; without twins the case-sensitive tree is the case-insensitive one
// (every merge joins byte-identical names), so the flag is cleared and nothing
// changes for ordinary archives.
//
// Twins are byte-different names equal by either rule the core uses on them:
// SalNameOrderCompareCI (= SalNameCompareOrdinalCI) or the legacy byte fold
// (= StrICmpEx; in code page 1250 the UTF-8 names "E-circumflex" C3 8A and
// "U-acute" C3 9A fold equal). Both are total orders, so a list sorted by one
// holds each group of equal names in one run and neighbours find every pair.
// Low memory answers TRUE: the caller keeps the exact (case-sensitive) listing.
//
//*****************************************************************************

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include "salnameorder.h"

struct SalCaseTwinName
{
    const char* Name;
    int Len;
};

namespace SalCaseTwinsDetail
{
inline int __cdecl CompareOrdinal(const void* a, const void* b)
{
    const SalCaseTwinName* x = (const SalCaseTwinName*)a;
    const SalCaseTwinName* y = (const SalCaseTwinName*)b;
    return SalNameOrderCompareCI(x->Name, x->Len, y->Name, y->Len);
}

inline int __cdecl CompareLegacy(const void* a, const void* b)
{
    const SalCaseTwinName* x = (const SalCaseTwinName*)a;
    const SalCaseTwinName* y = (const SalCaseTwinName*)b;
    return SalNameOrderDetail::LegacyCompareCI(x->Name, x->Len, y->Name, y->Len);
}

inline BOOL SameBytes(const SalCaseTwinName& x, const SalCaseTwinName& y)
{
    return x.Len == y.Len && memcmp(x.Name, y.Name, x.Len) == 0;
}

// sorts 'names' in place by 'cmp' and looks for two neighbours equal by it with different bytes
inline BOOL RunHasTwins(SalCaseTwinName* names, int count, int(__cdecl* cmp)(const void*, const void*))
{
    qsort(names, count, sizeof(SalCaseTwinName), cmp);
    for (int i = 1; i < count; i++)
    {
        if (cmp(&names[i - 1], &names[i]) == 0 && !SameBytes(names[i - 1], names[i]))
            return TRUE;
    }
    return FALSE;
}

// one part of a flat path (feature 290): the folder it is in - the path's first 'Start' bytes,
// compared byte for byte as the case-sensitive tree tells its folders apart - and the part itself
struct PathPart
{
    const char* Path;
    int Start;
    SalCaseTwinName Part;
};

inline int CompareFolder(const PathPart* x, const PathPart* y)
{
    if (x->Start != y->Start)
        return x->Start < y->Start ? -1 : 1;
    return memcmp(x->Path, y->Path, x->Start);
}

inline int __cdecl ComparePartOrdinal(const void* a, const void* b)
{
    int c = CompareFolder((const PathPart*)a, (const PathPart*)b);
    return c != 0 ? c : CompareOrdinal(&((const PathPart*)a)->Part, &((const PathPart*)b)->Part);
}

inline int __cdecl ComparePartLegacy(const void* a, const void* b)
{
    int c = CompareFolder((const PathPart*)a, (const PathPart*)b);
    return c != 0 ? c : CompareLegacy(&((const PathPart*)a)->Part, &((const PathPart*)b)->Part);
}

// sorts 'parts' by folder, then by 'cmp' on the part; twins = neighbours of one folder whose parts are
// equal by it with different bytes
inline BOOL PartRunHasTwins(PathPart* parts, int count, int(__cdecl* cmp)(const void*, const void*))
{
    qsort(parts, count, sizeof(PathPart), cmp);
    for (int i = 1; i < count; i++)
    {
        if (cmp(&parts[i - 1], &parts[i]) == 0 && !SameBytes(parts[i - 1].Part, parts[i].Part))
            return TRUE;
    }
    return FALSE;
}

// the check on a copy the caller owns (it is reordered)
inline BOOL HaveTwinsInPlace(SalCaseTwinName* names, int count)
{
    if (count < 2)
        return FALSE;
    return RunHasTwins(names, count, CompareOrdinal) || RunHasTwins(names, count, CompareLegacy);
}
} // namespace SalCaseTwinsDetail

// TRUE when two of the 'count' names are byte-different but the same name by
// SalNameOrderCompareCI or by the legacy byte fold. 'Len' < 0 = up to the
// terminator; a NULL 'Name' is "". Low memory: TRUE.
inline BOOL SalNamesHaveCaseTwins(const SalCaseTwinName* names, int count)
{
    if (names == NULL || count < 2)
        return FALSE;
    SalCaseTwinName* copy = (SalCaseTwinName*)malloc(sizeof(SalCaseTwinName) * (size_t)count);
    if (copy == NULL)
        return TRUE;
    for (int i = 0; i < count; i++)
    {
        copy[i].Name = names[i].Name != NULL ? names[i].Name : "";
        copy[i].Len = names[i].Name == NULL ? 0 : (names[i].Len < 0 ? (int)strlen(names[i].Name) : names[i].Len);
    }
    BOOL ret = SalCaseTwinsDetail::HaveTwinsInPlace(copy, count);
    free(copy);
    return ret;
}

// The same question for flat paths - the names of an archive's members, '\' or
// '/' separated (feature 290: the ZIP plug-in's add has the central directory,
// not a tree). Every part of every path is one name in the folder the path's
// bytes before it make (up to the end of the previous part; empty parts of
// doubled, leading or trailing separators are none), and names of one folder
// are compared as SalNamesHaveCaseTwins compares them - part by part, as
// SalDirTreeHasCaseTwins does on the case-sensitive tree the paths make (whose
// folders are told apart by their bytes). Comparing whole prefixes instead
// would miss twins below a folder whose name is not valid WTF-8 (review of 290).
// 'Len' < 0 = up to the terminator; a NULL 'Name' is "". Low memory: TRUE and
// '*lowMemory' (may be NULL) TRUE; otherwise '*lowMemory' FALSE.
inline BOOL SalPathsHaveCaseTwins(const SalCaseTwinName* paths, int count, BOOL* lowMemory)
{
    if (lowMemory != NULL)
        *lowMemory = FALSE;
    if (paths == NULL || count < 2)
        return FALSE;
    size_t total = 0;
    for (int i = 0; i < count; i++)
    {
        const char* s = paths[i].Name != NULL ? paths[i].Name : "";
        int len = paths[i].Name == NULL ? 0 : (paths[i].Len < 0 ? (int)strlen(s) : paths[i].Len);
        for (int k = 0; k < len; k++)
        {
            if (s[k] == '\\' || s[k] == '/')
                total++;
        }
        total++;
    }
    SalCaseTwinsDetail::PathPart* parts = (SalCaseTwinsDetail::PathPart*)malloc(sizeof(SalCaseTwinsDetail::PathPart) * total);
    if (parts == NULL)
    {
        if (lowMemory != NULL)
            *lowMemory = TRUE;
        return TRUE;
    }
    int n = 0;
    for (int i = 0; i < count; i++)
    {
        const char* s = paths[i].Name != NULL ? paths[i].Name : "";
        int len = paths[i].Name == NULL ? 0 : (paths[i].Len < 0 ? (int)strlen(s) : paths[i].Len);
        int folderLen = 0; // the end of the previous part
        int k = 0;
        while (k < len)
        {
            while (k < len && (s[k] == '\\' || s[k] == '/'))
                k++;
            int start = k;
            while (k < len && s[k] != '\\' && s[k] != '/')
                k++;
            if (k > start)
            {
                parts[n].Path = s;
                parts[n].Start = folderLen;
                parts[n].Part.Name = s + start;
                parts[n].Part.Len = k - start;
                n++;
                folderLen = k;
            }
        }
    }
    BOOL ret = FALSE;
    if (n >= 2)
    {
        ret = SalCaseTwinsDetail::PartRunHasTwins(parts, n, SalCaseTwinsDetail::ComparePartOrdinal) ||
              SalCaseTwinsDetail::PartRunHasTwins(parts, n, SalCaseTwinsDetail::ComparePartLegacy);
    }
    free(parts);
    return ret;
}

// TRUE when any folder of the tree - the root and every sub-folder - holds case
// twins among its folders and files together. TDir provides GetFilesCount(),
// GetDirsCount(), GetFile(i) and GetDir(i) (items with Name and NameLen) and
// GetSalDir(i) (a const TDir*, NULL allowed) - CSalamanderDirectoryAbstract
// does. Walks with a heap stack (no recursion: archive paths can be deep).
// Low memory: TRUE.
template <class TDir>
BOOL SalDirTreeHasCaseTwins(const TDir* root)
{
    if (root == NULL)
        return FALSE;
    int stackSize = 64;
    int stackCount = 0;
    const TDir** stack = (const TDir**)malloc(sizeof(const TDir*) * (size_t)stackSize);
    if (stack == NULL)
        return TRUE;
    stack[stackCount++] = root;
    SalCaseTwinName* names = NULL;
    int namesSize = 0;
    BOOL twins = FALSE;
    while (stackCount > 0 && !twins)
    {
        const TDir* dir = stack[--stackCount];
        int dirs = dir->GetDirsCount();
        int files = dir->GetFilesCount();
        int count = dirs + files;
        if (count > namesSize)
        {
            SalCaseTwinName* n = (SalCaseTwinName*)realloc(names, sizeof(SalCaseTwinName) * (size_t)count);
            if (n == NULL)
            {
                twins = TRUE;
                break;
            }
            names = n;
            namesSize = count;
        }
        int k = 0;
        for (int i = 0; i < dirs; i++)
        {
            names[k].Name = dir->GetDir(i)->Name;
            names[k].Len = (int)dir->GetDir(i)->NameLen;
            k++;
        }
        for (int i = 0; i < files; i++)
        {
            names[k].Name = dir->GetFile(i)->Name;
            names[k].Len = (int)dir->GetFile(i)->NameLen;
            k++;
        }
        if (SalCaseTwinsDetail::HaveTwinsInPlace(names, count))
        {
            twins = TRUE;
            break;
        }
        for (int i = 0; i < dirs; i++)
        {
            const TDir* sub = dir->GetSalDir(i);
            if (sub == NULL)
                continue;
            if (stackCount == stackSize)
            {
                const TDir** s = (const TDir**)realloc((void*)stack, sizeof(const TDir*) * (size_t)stackSize * 2);
                if (s == NULL)
                {
                    twins = TRUE;
                    break;
                }
                stack = s;
                stackSize *= 2;
            }
            stack[stackCount++] = sub;
        }
    }
    free(names);
    free((void*)stack);
    return twins;
}
