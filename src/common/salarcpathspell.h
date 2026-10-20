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
