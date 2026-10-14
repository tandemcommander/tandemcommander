// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salshelllink.h (feature 128)
//
// The target of a shortcut (.lnk) as a path of the core.
//
// Paths in the core are UTF-8. IShellLinkA::GetPath returns the target in the
// system code page (letters outside it become '?'), so a shortcut to
// "D:\Účetnictví" gave bytes that are not valid UTF-8; the path check then
// answered ERROR_INVALID_NAME - "(123) The filename, directory name, or volume
// label syntax is incorrect" - for every shortcut whose target has a letter
// outside ASCII (GitHub issue #8). The drop-target code was moved to the wide
// interface by feature 069 (shellsup.cpp); Enter on a shortcut and "Go to
// Shortcut Target" were not.
//
// SalShellLinkGetPathU8 asks the WIDE interface and converts to UTF-8 (WTF-8).
// The path is returned whole or not at all: when it does not fit 'pathSize'
// bytes the function fails (E_FAIL) and 'path' is "" - a cut path would be
// another folder (CLAUDE.md: a path or name is never cut).
//
// Header-only: saltests checks it against real shortcuts.
//
//*****************************************************************************

#include <shlobj.h>
#include "salunicode.h"
#include "salpath.h"

// Returns NOERROR when 'path' holds the target path; S_FALSE when the shortcut
// has no path (a target that is not a file system object, e.g. a server - the
// caller may then ask for the ID list); a failure code otherwise. 'flags' are
// the SLGP_xxx flags of IShellLink::GetPath.
inline HRESULT SalShellLinkGetPathU8(IShellLinkW* link, char* path, int pathSize, DWORD flags)
{
    if (path == NULL || pathSize <= 0)
        return E_INVALIDARG;
    path[0] = 0;
    if (link == NULL)
        return E_INVALIDARG;
    const int wideSize = 32768; // the longest path Windows knows
    WCHAR* pathW = (WCHAR*)malloc(wideSize * sizeof(WCHAR));
    if (pathW == NULL)
        return E_OUTOFMEMORY;
    pathW[0] = 0;
    HRESULT res = link->GetPath(pathW, wideSize, NULL, flags);
    if (res == NOERROR)
    {
        if (pathW[0] == 0)
            res = S_FALSE; // "no path" is reported as success with an empty string by some targets
        else if (SalWToU8(pathW, -1, path, pathSize) == 0)
        {
            path[0] = 0;
            res = E_FAIL; // does not fit: refused, never cut
        }
    }
    free(pathW);
    return res;
}

// Feature 181: the name IPersistFile::Load is given for the shortcut file 'u8path' (a path of the
// core): the whole path as UTF-16, in the \\?\ form when it has MAX_PATH characters or more (Load
// opens the file through CreateFileW). A path that is not valid UTF-8 (unexpected) is widened through
// the code page, as before. The callers had it in OLECHAR[MAX_PATH]: a shortcut in a folder of
// MAX_PATH characters or more was "not a valid shortcut". malloc'ed (free it); NULL on low memory.
inline WCHAR* SalShellLinkLoadNameAlloc(const char* u8path)
{
    if (u8path == NULL)
        return NULL;
    WCHAR* w = SalU8ToWAlloc(u8path);
    if (w != NULL)
    {
        if (wcslen(w) < MAX_PATH)
            return w;
        free(w);
        return SalPathToWExtAlloc(u8path); // NULL: longer than any path Windows knows
    }
    int n = MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, u8path, -1, NULL, 0);
    w = n > 0 ? (WCHAR*)malloc(n * sizeof(WCHAR)) : NULL;
    if (w != NULL && MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, u8path, -1, w, n) == 0)
    {
        free(w);
        w = NULL;
    }
    return w;
}
