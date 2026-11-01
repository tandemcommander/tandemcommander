// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salarcpathspell.h
//
// The path inside an archive spelled as the archive's listing spells it
// (feature 273). Header-only, for the core and saltests.
//
// A listing without SALDIRFLAG_CASESENSITIVE finds its folders ignoring case,
// so a path typed in another case ("t.tar\DOCS" for the folder "Docs") opens
// the folder. The panel kept the typed spelling as its path inside the archive
// and passed it to the archive plug-ins as the root of the selected names; the
// TAR plug-in matches the names it extracts byte for byte and extracted
// nothing, silently. The core therefore stores the path as listed: each
// component is replaced by the name of the folder the listing's own lookup
// finds for it - the FIRST sub-folder its comparison takes as equal, exactly
// what CSalamanderDirectory::GetFiles / GetDirs do - so the re-spelled path
// names the very folder the panel lists, for a case-insensitive or a
// case-sensitive listing alike.
//
// The listing's comparisons (StrICmpEx, a byte fold; StrCmpEx) take only names
// of equal byte length as equal, so the result has the typed path's length;
// the output size is still checked and a result that does not fit is refused
// (TOOLONG) - the caller keeps the typed path, a path is never cut.
//
// 'root' is a pointer to a folder of the listing (TDirPtr); the accessor 'acc' gives:
//   int acc.Count(TDirPtr d)                         - number of sub-folders
//   const char* acc.Name(TDirPtr d, int i, int* len) - sub-folder i's name
//   TDirPtr acc.Sub(TDirPtr d, int i)                - its contents (NULL = empty)
//   bool acc.Equal(TDirPtr d, const char* name, int nameLen,
//                  const char* comp, int compLen)    - the listing's comparison
//
//*****************************************************************************

#define SAL_ARCRESPELL_OK 0       // 'out' holds the re-spelled path
#define SAL_ARCRESPELL_NOTFOUND 1 // a component (also an empty one) names no folder
#define SAL_ARCRESPELL_TOOLONG 2  // 'out' is too small (nothing usable written)

// 'path': components separated by '\\', an optional leading and trailing '\\';
// "" (or "\\") is the archive's root. 'out' receives the path without a leading
// or trailing '\\'; 'outSize' includes the terminating NUL.
template <class TDirPtr, class TAccess>
int SalArcPathRespell(TDirPtr root, const char* path, char* out, int outSize, const TAccess& acc)
{
    if (out == NULL || outSize <= 0)
        return SAL_ARCRESPELL_TOOLONG;
    out[0] = 0;
    if (*path == '\\')
        path++;
    int pathLen = 0;
    while (path[pathLen] != 0)
        pathLen++;
    if (pathLen > 0 && path[pathLen - 1] == '\\')
        pathLen--;
    TDirPtr dir = root;
    int outLen = 0;
    int pos = 0;
    while (pos < pathLen)
    {
        int end = pos;
        while (end < pathLen && path[end] != '\\')
            end++;
        int compLen = end - pos;
        if (compLen == 0 || dir == NULL) // an empty component, or a component inside an empty folder
            return SAL_ARCRESPELL_NOTFOUND;
        int count = acc.Count(dir);
        int found = -1;
        for (int i = 0; i < count; i++)
        {
            int nameLen = 0;
            const char* name = acc.Name(dir, i, &nameLen);
            if (acc.Equal(dir, name, nameLen, path + pos, compLen))
            {
                found = i;
                break;
            }
        }
        if (found < 0)
            return SAL_ARCRESPELL_NOTFOUND;
        int nameLen = 0;
        const char* name = acc.Name(dir, found, &nameLen);
        int need = outLen + (outLen > 0 ? 1 : 0) + nameLen + 1; // separator, name, NUL
        if (need > outSize)
        {
            out[0] = 0;
            return SAL_ARCRESPELL_TOOLONG;
        }
        if (outLen > 0)
            out[outLen++] = '\\';
        for (int k = 0; k < nameLen; k++)
            out[outLen++] = name[k];
        out[outLen] = 0;
        dir = acc.Sub(dir, found);
        pos = end + 1; // past the '\\' (or past the end)
    }
    return SAL_ARCRESPELL_OK;
}

//*****************************************************************************
//
// Feature 382: a typed path resolved in a case-sensitive listing.
//
// The 7-Zip and TAR plug-ins keep SALDIRFLAG_CASESENSITIVE for the whole listing
// when any folder holds case twins (feature 252); the listing's lookup then
// compares every component exactly and "t.tar\DOCS" for the folder "Docs" named
// nothing - the panel shortened the path to the archive's root, silently, and a
// following Select All + Copy took the whole root. SalArcPathResolveCase resolves
// the typed path before the panel looks it up:
//   1. a sub-folder equal by the listing's comparison (acc.Equal) - the first one,
//      as GetFiles; an exact name always wins, also beside its twin;
//   2. else, only in a case-sensitive folder (acc.CaseSensitive): the ONE
//      sub-folder equal ignoring case - accepted by acc.FoldEqual (the legacy byte
//      fold a listing without twins uses, so the folder is the one the same
//      archive without twins opens, feature 273), counted by acc.AnyCaseEqual
//      (either rule that makes twins, salcasetwins.h); two or more such folders,
//      or any FILE of the folder with that name (exactly or ignoring case - the
//      caller focuses a file named by the last component) = ambiguous, never guessed;
//   3. else the component does not resolve: it and the rest of the path are kept
//      as typed (the caller's shortening and file focusing handle them as before).
// Fold-equal names have the typed component's byte length, so the result has the
// typed path's length; the output size is still checked and a result that does
// not fit is refused (TOOLONG, the caller keeps the typed path) - never cut.
//
// The accessor adds to the one of SalArcPathRespell:
//   bool acc.CaseSensitive(TDirPtr d)                    - the folder compares exactly
//   int acc.FileCount(TDirPtr d)                         - number of files
//   const char* acc.FileName(TDirPtr d, int i, int* len) - file i's name
//   bool acc.FoldEqual(const char* name, int nameLen,
//                      const char* comp, int compLen)    - equal by the legacy fold
//   bool acc.AnyCaseEqual(const char* name, int nameLen,
//                         const char* comp, int compLen) - equal by any case rule
//
// 'path' as for SalArcPathRespell; 'out' receives it without a leading or
// trailing '\\'. Returns SAL_ARCRESPELL_OK or SAL_ARCRESPELL_TOOLONG.
//
//*****************************************************************************

template <class TDirPtr, class TAccess>
int SalArcPathResolveCase(TDirPtr root, const char* path, char* out, int outSize, const TAccess& acc)
{
    if (out == NULL || outSize <= 0)
        return SAL_ARCRESPELL_TOOLONG;
    out[0] = 0;
    if (*path == '\\')
        path++;
    int pathLen = 0;
    while (path[pathLen] != 0)
        pathLen++;
    if (pathLen > 0 && path[pathLen - 1] == '\\')
        pathLen--;
    if (pathLen + 1 > outSize)
        return SAL_ARCRESPELL_TOOLONG;
    TDirPtr dir = root;
    bool resolving = true;
    int pos = 0;
    int outLen = 0;
    while (pos < pathLen)
    {
        int end = pos;
        while (end < pathLen && path[end] != '\\')
            end++;
        int compLen = end - pos;
        const char* name = NULL;
        int nameLen = 0;
        int found = -1;
        if (resolving && compLen > 0 && dir != NULL)
        {
            int count = acc.Count(dir);
            for (int i = 0; i < count; i++) // 1. the listing's own comparison, the first match
            {
                const char* n = acc.Name(dir, i, &nameLen);
                if (acc.Equal(dir, n, nameLen, path + pos, compLen))
                {
                    found = i;
                    name = n;
                    break;
                }
            }
            if (found < 0 && acc.CaseSensitive(dir)) // 2. the only folder equal ignoring case
            {
                int equalCount = 0;
                int foldIndex = -1;
                for (int i = 0; i < count; i++)
                {
                    int l = 0;
                    const char* n = acc.Name(dir, i, &l);
                    if (acc.AnyCaseEqual(n, l, path + pos, compLen))
                    {
                        equalCount++;
                        if (acc.FoldEqual(n, l, path + pos, compLen))
                            foldIndex = i;
                    }
                }
                // files of the folder take part (review of 382): a file with the typed name - exactly
                // or ignoring case - is what the caller focuses when the path is shortened, so the
                // folder is not taken in its place (the typed name is then ambiguous, not resolved)
                int files = acc.FileCount(dir);
                for (int i = 0; i < files && equalCount < 2; i++)
                {
                    int l = 0;
                    const char* n = acc.FileName(dir, i, &l);
                    if (acc.AnyCaseEqual(n, l, path + pos, compLen) ||
                        acc.Equal(dir, n, l, path + pos, compLen))
                        equalCount = 2;
                }
                if (equalCount == 1 && foldIndex >= 0)
                {
                    found = foldIndex;
                    name = acc.Name(dir, found, &nameLen);
                }
            }
        }
        if (found < 0 || nameLen != compLen) // 3. kept as typed from here on
        {
            resolving = false;
            name = path + pos;
            nameLen = compLen;
        }
        int need = outLen + (outLen > 0 || pos > 0 ? 1 : 0) + nameLen + 1; // separator, name, NUL
        if (need > outSize)
        {
            out[0] = 0;
            return SAL_ARCRESPELL_TOOLONG;
        }
        if (outLen > 0 || pos > 0)
            out[outLen++] = '\\';
        for (int k = 0; k < nameLen; k++)
            out[outLen++] = name[k];
        out[outLen] = 0;
        if (resolving)
            dir = acc.Sub(dir, found);
        pos = end + 1; // past the '\\' (or past the end)
    }
    return SAL_ARCRESPELL_OK;
}
