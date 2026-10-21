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

// Feature 286: does the text of a desktop.ini name the folder-shortcut class
// {0AFACED1-E828-11D1-9187-B532F1E9575D} - the whole id between braces, ASCII letter case ignored?
// The core's old test compared only as many letters as stood between the braces ("{}" matched);
// the plug-in twin is SplFileDlgDetail::IsFolderShortcutIni (splfiledlg.h, feature 121).
inline BOOL SalIsFolderShortcutIni(const char* buf, int len)
{
    static const char clsid[] = "0AFACED1-E828-11D1-9187-B532F1E9575D";
    const int clsidLen = (int)(sizeof(clsid) - 1);
    if (buf == NULL)
        return FALSE;
    int i = 0;
    while (i < len)
    {
        if (buf[i] == '{')
        {
            int beg = ++i;
            while (i < len && buf[i] != '}')
                i++;
            if (i < len && i - beg == clsidLen && _strnicmp(buf + beg, clsid, clsidLen) == 0)
                return TRUE;
        }
        else
            i++;
    }
    return FALSE;
}

// Feature 286: the target of the folder shortcut 'folderU8' (a path of the core, any length) - a
// folder holding desktop.ini that names the folder-shortcut class and target.lnk (the network
// locations under This PC / Network are such folders). The target is read whole (UNC preferred,
// no Resolve) and handed back only when it fits 'targetSize' bytes. The core had the names in
// MAX_PATH bytes and followed a target only below MAX_PATH bytes: a longer one silently left the
// shortcut folder itself as the Browse result. COM must be initialised on the thread.
// Returns NOERROR: 'target' holds the target; S_FALSE: not a folder shortcut, or its target.lnk is
// missing, unreadable or names no file-system path ('target' is ""); ERROR_FILENAME_EXCED_RANGE (as
// an HRESULT): a folder shortcut whose target does not fit - refuse it, never cut ('target' is "");
// E_INVALIDARG / E_OUTOFMEMORY.
inline HRESULT SalFolderShortcutTargetU8(const char* folderU8, char* target, int targetSize)
{
    if (target == NULL || targetSize <= 0)
        return E_INVALIDARG;
    target[0] = 0;
    if (folderU8 == NULL || folderU8[0] == 0)
        return E_INVALIDARG;
    size_t len = strlen(folderU8);
    char* name = (char*)malloc(len + 16); // + "\target.lnk" / "\desktop.ini"
    if (name == NULL)
        return E_OUTOFMEMORY;
    memcpy(name, folderU8, len + 1);
    size_t dirLen = len;
    if (name[dirLen - 1] != '\\')
        name[dirLen++] = '\\';
    strcpy(name + dirLen, "desktop.ini");
    BOOL isShortcut = FALSE;
    WCHAR* nameW = SalPathToWExtAlloc(name);
    if (nameW != NULL)
    {
        HANDLE hFile = CreateFileW(nameW, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                                   OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, NULL);
        if (hFile != INVALID_HANDLE_VALUE)
        {
            if (GetFileSize(hFile, NULL) <= 1000) // so far all had about 92 bytes
            {
                char buf[1000];
                DWORD read;
                if (ReadFile(hFile, buf, sizeof(buf), &read, NULL) && read != 0)
                    isShortcut = SalIsFolderShortcutIni(buf, (int)read);
            }
            CloseHandle(hFile);
        }
        free(nameW);
    }
    HRESULT res = S_FALSE;
    if (isShortcut)
    {
        strcpy(name + dirLen, "target.lnk");
        WCHAR* lnkW = SalShellLinkLoadNameAlloc(name); // \\?\ from MAX_PATH characters (feature 181)
        if (lnkW != NULL)
        {
            DWORD attrs = GetFileAttributesW(lnkW);
            IShellLinkW* link;
            if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0 &&
                CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW,
                                 (LPVOID*)&link) == S_OK)
            {
                IPersistFile* fileInt;
                if (link->QueryInterface(IID_IPersistFile, (LPVOID*)&fileInt) == S_OK)
                {
                    if (fileInt->Load(lnkW, STGM_READ) == S_OK)
                    {
                        char* whole = (char*)malloc(SAL_MAX_PATH_UTF8); // any target Windows knows
                        if (whole == NULL)
                            res = E_OUTOFMEMORY;
                        else
                        {
                            if (SalShellLinkGetPathU8(link, whole, SAL_MAX_PATH_UTF8, SLGP_UNCPRIORITY) == NOERROR)
                            {
                                if (strlen(whole) < (size_t)targetSize)
                                {
                                    strcpy(target, whole);
                                    res = NOERROR;
                                }
                                else
                                    res = HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE);
                            }
                            free(whole);
                        }
                    }
                    fileInt->Release();
                }
                link->Release();
            }
            free(lnkW);
        }
    }
    free(name);
    return res;
}
