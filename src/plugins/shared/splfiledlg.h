// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// splfiledlg.h (feature 104)
//
// Header-only file and folder pickers for plug-ins whose names are UTF-8
// (WTF-8), the program's encoding since plug-in interface 104.
//
// Why: the plug-in services SalamanderGeneral->SafeGetOpenFileName,
// SafeGetSaveFileName and GetTargetDirectory are code-page ("ANSI") calls and
// their contract is frozen (interface FR-009): the picked name comes back
// converted with WideCharToMultiByte(CP_ACP, 0), which uses BEST FIT -
// "voila<U+00E0>.txt" comes back as "voila.txt", fullwidth letters as ASCII
// ones, everything else as '?'. A plug-in that then opens, saves to or copies
// into that name works on a DIFFERENT EXISTING FILE OR FOLDER without a word
// (measured, specs/104-plugin-unicode-names/research.md). Widening the services
// would be a new plug-in interface; these helpers call the Unicode dialogs in
// the plug-in instead, as the File Comparator's Browse does since feature 102.
//
//   SplGetFileNameU8   - GetOpenFileNameW / GetSaveFileNameW for an OPENFILENAMEA
//                        whose NAMES are UTF-8 and whose TEXTS are code-page
//   SplBrowseForFolderU8 - SHBrowseForFolderW with UTF-8 in and out
//
// Never best fit: a picked name that does not fit the caller's buffer is
// refused with the system's "file name too long" text, never cut or converted.
// The result is byte-identical to the old one for every ASCII name.
//

#include <windows.h>
#include <commdlg.h>
#include <cderr.h> // FNERR_INVALIDFILENAME
#include <shlobj.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "splunicode.h"

namespace SplFileDlgDetail
{
// a code-page text (a resource string) as UTF-16; NULL in, NULL out; free() the result
inline WCHAR* CodePageToWAlloc(const char* s)
{
    if (s == NULL)
        return NULL;
    int len = MultiByteToWideChar(CP_ACP, 0, s, -1, NULL, 0);
    WCHAR* w = len > 0 ? (WCHAR*)malloc(len * sizeof(WCHAR)) : NULL;
    if (w != NULL && MultiByteToWideChar(CP_ACP, 0, s, -1, w, len) <= 0)
    {
        free(w);
        w = NULL;
    }
    return w;
}

// a double-null-terminated list of code-page texts (lpstrFilter) as UTF-16, the list
// form kept; NULL in, NULL out; free() the result
inline WCHAR* CodePageListToWAlloc(const char* list)
{
    if (list == NULL)
        return NULL;
    const char* end = list;
    while (*end != 0)
        end += strlen(end) + 1;
    int bytes = (int)(end - list) + 1; // every item with its terminator + the final one
    int len = MultiByteToWideChar(CP_ACP, 0, list, bytes, NULL, 0);
    WCHAR* w = len > 0 ? (WCHAR*)malloc((len + 1) * sizeof(WCHAR)) : NULL;
    if (w != NULL)
    {
        if (MultiByteToWideChar(CP_ACP, 0, list, bytes, w, len) <= 0)
        {
            free(w);
            return NULL;
        }
        w[len] = 0; // an empty list is "\0\0" after all
    }
    return w;
}

// OPENFILENAME's nFileOffset / nFileExtension for a UTF-8 full name, in BYTES: the
// offset of the name after the last backslash (or slash), and of the extension after
// the last dot of that name (the offset of the terminator when there is no dot, 0
// when the name ends with a dot - the documented meanings)
inline void NameOffsets(const char* u8, WORD* fileOffset, WORD* extOffset)
{
    size_t len = strlen(u8);
    size_t name = 0;
    for (size_t i = 0; i < len; i++)
        if (u8[i] == '\\' || u8[i] == '/')
            name = i + 1;
    size_t ext = len;
    for (size_t i = len; i > name; i--)
    {
        if (u8[i - 1] == '.')
        {
            ext = i == len ? 0 : i;
            break;
        }
    }
    if (fileOffset != NULL)
        *fileOffset = name > 0xFFFF ? 0 : (WORD)name;
    if (extOffset != NULL)
        *extOffset = ext > 0xFFFF ? 0 : (WORD)ext;
}

} // namespace SplFileDlgDetail

// the system's text for ERROR_FILENAME_EXCED_RANGE ("The filename or extension is too
// long.") in a message box - no plug-in string is needed, Windows translates it; for a
// picked or typed name whose UTF-8 form does not fit the plug-in's buffer (it is never
// cut). 'caption' is UTF-16 or NULL
inline void SplShowNameTooLongW(HWND owner, const WCHAR* caption)
{
    WCHAR text[512];
    if (FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL,
                       ERROR_FILENAME_EXCED_RANGE, 0, text, 512, NULL) == 0)
        lstrcpynW(text, L"The filename or extension is too long.", 512);
    MessageBoxW(owner, text, caption != NULL ? caption : L"", MB_OK | MB_ICONEXCLAMATION);
}

// the same with a code-page caption (a resource string) or NULL
inline void SplShowNameTooLong(HWND owner, const char* caption)
{
    WCHAR* cap = SplFileDlgDetail::CodePageToWAlloc(caption);
    SplShowNameTooLongW(owner, cap);
    free(cap);
}

namespace SplFileDlgDetail
{
struct CBrowseData
{
    const WCHAR* Title;
    const WCHAR* InitDir;
    HWND CenterWindow;
};

inline int CALLBACK BrowseCallback(HWND hwnd, UINT uMsg, LPARAM lParam, LPARAM lpData)
{
    CBrowseData* bd = (CBrowseData*)lpData;
    if (uMsg == BFFM_SELCHANGED) // feature 121: as the core's dialog - OK only for a folder with a path
    {
        WCHAR selPath[MAX_PATH];
        BOOL hasPath = lParam != 0 && SHGetPathFromIDListW((LPCITEMIDLIST)lParam, selPath);
        SendMessageW(hwnd, BFFM_ENABLEOK, 0, hasPath);
        return 0;
    }
    if (uMsg == BFFM_INITIALIZED && bd != NULL)
    {
        if (bd->CenterWindow != NULL) // the core's browse dialog is centred on this window too
        {
            RECT c, r;
            if (GetWindowRect(bd->CenterWindow, &c) && GetWindowRect(hwnd, &r))
            {
                MONITORINFO mi;
                mi.cbSize = sizeof(mi);
                int x = c.left + ((c.right - c.left) - (r.right - r.left)) / 2;
                int y = c.top + ((c.bottom - c.top) - (r.bottom - r.top)) / 2;
                if (GetMonitorInfoW(MonitorFromWindow(bd->CenterWindow, MONITOR_DEFAULTTONEAREST), &mi))
                {
                    if (x + (r.right - r.left) > mi.rcWork.right)
                        x = mi.rcWork.right - (r.right - r.left);
                    if (y + (r.bottom - r.top) > mi.rcWork.bottom)
                        y = mi.rcWork.bottom - (r.bottom - r.top);
                    if (x < mi.rcWork.left)
                        x = mi.rcWork.left;
                    if (y < mi.rcWork.top)
                        y = mi.rcWork.top;
                }
                SetWindowPos(hwnd, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
        }
        if (bd->Title != NULL)
            SplSetWindowTitleW(hwnd, bd->Title);
        if (bd->InitDir != NULL && bd->InitDir[0] != 0)
        {
            // the core's rule: no trailing backslash except for a root
            size_t len = wcslen(bd->InitDir);
            WCHAR* dir = (WCHAR*)malloc((len + 1) * sizeof(WCHAR));
            if (dir != NULL)
            {
                memcpy(dir, bd->InitDir, (len + 1) * sizeof(WCHAR));
                if (len > 3 && dir[len - 1] == L'\\')
                    dir[len - 1] = 0;
                SendMessageW(hwnd, BFFM_SETSELECTIONW, TRUE, (LPARAM)dir);
                free(dir);
            }
        }
    }
    return 0;
}

// feature 121: does the content of a desktop.ini name the "folder shortcut" class
// {0AFACED1-E828-11D1-9187-B532F1E9575D} (the folders in NetHood / "Network
// shortcuts" are such folders: a target.lnk inside points at the real place)?
// The core's ResolveNetHoodPath compared only as many characters as stood between
// the braces (a prefix match); this compares the whole class id.
inline BOOL IsFolderShortcutIni(const char* buf, int len)
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

// feature 121: the core's GetTargetDirectory resolved a picked NetHood folder shortcut to
// the folder it points at (ResolveNetHoodPath); SplBrowseForFolderU8 returned the shortcut
// folder itself - a folder holding desktop.ini and target.lnk, not the place the user
// meant (a plug-in then copied into it, or listed it). The same rule: only on a local fixed
// drive, only when desktop.ini names the folder shortcut class and target.lnk exists; the
// link's path (UNC preferred, as the core) without Resolve. 'path' is the picked folder;
// returns a malloc'ed target or NULL (no shortcut, or it cannot be read). COM must be
// initialised on the thread (it is for SHBrowseForFolderW).
inline WCHAR* ResolveNetHoodFolderW(const WCHAR* path)
{
    if (path == NULL || path[0] == 0 || path[0] == L'\\' || path[1] != L':')
        return NULL; // UNC (or not a drive path) - cannot be NetHood
    WCHAR root[4] = {path[0], L':', L'\\', 0};
    if (GetDriveTypeW(root) != DRIVE_FIXED)
        return NULL;
    size_t len = wcslen(path);
    WCHAR* name = (WCHAR*)malloc((len + 16) * sizeof(WCHAR));
    if (name == NULL)
        return NULL;
    memcpy(name, path, (len + 1) * sizeof(WCHAR));
    size_t dirLen = len;
    if (dirLen > 0 && name[dirLen - 1] != L'\\')
        name[dirLen++] = L'\\';
    wcscpy(name + dirLen, L"desktop.ini");
    BOOL tryTarget = FALSE;
    HANDLE hFile = CreateFileW(name, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING,
                               FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (hFile != INVALID_HANDLE_VALUE)
    {
        if (GetFileSize(hFile, NULL) <= 1000) // the core's bound (they are about 92 bytes)
        {
            char buf[1000];
            DWORD read;
            if (ReadFile(hFile, buf, sizeof(buf), &read, NULL) && read != 0)
                tryTarget = IsFolderShortcutIni(buf, (int)read);
        }
        CloseHandle(hFile);
    }
    WCHAR* result = NULL;
    if (tryTarget)
    {
        wcscpy(name + dirLen, L"target.lnk");
        DWORD attrs = GetFileAttributesW(name);
        if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0)
        {
            IShellLinkW* link;
            if (CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
            {
                IPersistFile* fileInt;
                if (link->QueryInterface(IID_IPersistFile, (LPVOID*)&fileInt) == S_OK)
                {
                    if (fileInt->Load(name, STGM_READ) == S_OK)
                    {
                        WCHAR tgt[MAX_PATH];
                        WIN32_FIND_DATAW data;
                        if (link->GetPath(tgt, MAX_PATH, &data, SLGP_UNCPRIORITY) == NOERROR && tgt[0] != 0)
                        {
                            size_t tgtLen = wcslen(tgt);
                            result = (WCHAR*)malloc((tgtLen + 1) * sizeof(WCHAR));
                            if (result != NULL)
                                memcpy(result, tgt, (tgtLen + 1) * sizeof(WCHAR));
                        }
                    }
                    fileInt->Release();
                }
                link->Release();
            }
        }
    }
    free(name);
    return result;
}

// feature 121 (found by 117's GUI run): a proposed file name WITHOUT a folder is put into the
// folder the dialog should open in. Windows uses lpstrInitialDir only on conditions of its own
// (since Windows 7 the dialog may open the folder the program used last - measured: Checksum's
// Save opened another program's folder instead of the panel's), while a path in lpstrFile always
// decides. 'file' (a buffer of 'units' WCHARs) is left alone when it is empty, already names a
// folder or a drive, or the whole does not fit. Returns the length of the prefix it put in
// front of the name (0 = unchanged), for BareNameBack.
inline size_t NameIntoInitialDir(WCHAR* file, size_t units, const WCHAR* initDir)
{
    if (file == NULL || file[0] == 0 || initDir == NULL || initDir[0] == 0)
        return 0;
    if (wcspbrk(file, L"\\/:") != NULL)
        return 0; // has a folder (or a drive) of its own
    size_t dl = wcslen(initDir);
    size_t fl = wcslen(file);
    size_t sep = (initDir[dl - 1] != L'\\' && initDir[dl - 1] != L'/') ? 1 : 0;
    if (dl + sep + fl + 1 > units)
        return 0;
    memmove(file + dl + sep, file, (fl + 1) * sizeof(WCHAR));
    memcpy(file, initDir, dl * sizeof(WCHAR));
    if (sep)
        file[dl] = L'\\';
    return dl + sep;
}

// feature 121 (review SF1): undoes NameIntoInitialDir - the bare name again. The dialogs refuse a
// name in a folder that is gone (a removed USB stick remembered as the save folder) or a whole
// that is too long (FNERR_INVALIDFILENAME); they retry with the bare name and the initial folder
// (what Windows was given before 121 - it ignored a bad folder and kept the name), and only then
// with neither. Returns TRUE when it changed 'file'.
inline BOOL BareNameBack(WCHAR* file, size_t prefixLen)
{
    if (file == NULL || prefixLen == 0 || wcslen(file) <= prefixLen)
        return FALSE;
    memmove(file, file + prefixLen, (wcslen(file + prefixLen) + 1) * sizeof(WCHAR));
    return TRUE;
}
} // namespace SplFileDlgDetail

// GetOpenFileNameW (save == FALSE) or GetSaveFileNameW (save == TRUE) for an
// OPENFILENAMEA filled the usual way, with these ENCODINGS:
//   lpstrFile (in/out, nMaxFile BYTES), lpstrInitialDir, lpstrFileTitle (out,
//     nMaxFileTitle bytes)                       UTF-8 (WTF-8) - names
//   lpstrFilter, lpstrTitle, lpstrDefExt        code-page text - resource strings
// nFilterIndex, nFileOffset and nFileExtension (in BYTES of the UTF-8 result) come
// back as from the A dialog. Not supported (returns FALSE without showing anything):
// OFN_ENABLEHOOK, OFN_ENABLETEMPLATE(HANDLE), OFN_ALLOWMULTISELECT, lpstrCustomFilter.
// Like the core's SafeGet*FileName, a refused initial name or folder
// (FNERR_INVALIDFILENAME) is retried with neither. A picked name whose UTF-8 form
// does not fit lpstrFile is refused with a message and FALSE (never cut, never
// converted to the code page). Returns TRUE when a name was picked.
inline BOOL SplGetFileNameU8(OPENFILENAMEA* ofn, BOOL save)
{
    if (ofn == NULL || ofn->lpstrFile == NULL || ofn->nMaxFile == 0 ||
        (ofn->Flags & (OFN_ENABLEHOOK | OFN_ENABLETEMPLATE | OFN_ENABLETEMPLATEHANDLE | OFN_ALLOWMULTISELECT)) != 0 ||
        ofn->lpstrCustomFilter != NULL)
    {
        return FALSE;
    }
    const DWORD fileUnits = 32768; // the longest path Windows has
    WCHAR* file = (WCHAR*)malloc(fileUnits * sizeof(WCHAR));
    if (file == NULL)
        return FALSE;
    file[0] = 0;
    if (ofn->lpstrFile[0] != 0 && SplU8ToW(ofn->lpstrFile, file, fileUnits) == 0)
        file[0] = 0; // not UTF-8 (or too long): start without a name rather than with a wrong one
    WCHAR* initDir = ofn->lpstrInitialDir != NULL ? SplU8ToWAlloc(ofn->lpstrInitialDir) : NULL;
    size_t prefixLen = SplFileDlgDetail::NameIntoInitialDir(file, fileUnits, initDir); // feature 121: open in initDir
    WCHAR* filter = SplFileDlgDetail::CodePageListToWAlloc(ofn->lpstrFilter);
    WCHAR* title = SplFileDlgDetail::CodePageToWAlloc(ofn->lpstrTitle);
    WCHAR* defExt = SplFileDlgDetail::CodePageToWAlloc(ofn->lpstrDefExt);

    OPENFILENAMEW w;
    memset(&w, 0, sizeof(w));
    w.lStructSize = sizeof(w);
    w.hwndOwner = ofn->hwndOwner;
    w.hInstance = ofn->hInstance;
    w.lpstrFilter = filter;
    w.nFilterIndex = ofn->nFilterIndex;
    w.lpstrFile = file;
    w.nMaxFile = fileUnits;
    w.lpstrInitialDir = initDir;
    w.lpstrTitle = title;
    w.Flags = ofn->Flags;
    w.lpstrDefExt = defExt;
    w.lCustData = ofn->lCustData;
#if (_WIN32_WINNT >= 0x0500)
    if (ofn->lStructSize >= sizeof(OPENFILENAMEA))
        w.FlagsEx = ofn->FlagsEx;
#endif

    BOOL ret = save ? GetSaveFileNameW(&w) : GetOpenFileNameW(&w);
    if (!ret && CommDlgExtendedError() == FNERR_INVALIDFILENAME && SplFileDlgDetail::BareNameBack(file, prefixLen))
        ret = save ? GetSaveFileNameW(&w) : GetOpenFileNameW(&w); // feature 121 (review SF1): the bare name as before
    if (!ret && CommDlgExtendedError() == FNERR_INVALIDFILENAME)
    { // the core's SafeGet*FileName rule: Windows refuses a name like "C:\" or a missing folder
        file[0] = 0;
        w.lpstrInitialDir = NULL;
        ret = save ? GetSaveFileNameW(&w) : GetOpenFileNameW(&w);
    }
    if (ret)
    {
        ofn->nFilterIndex = w.nFilterIndex;
        ofn->Flags = w.Flags; // OFN_READONLY / OFN_EXTENSIONDIFFERENT come back here
        char* u8 = SplWToU8Alloc(file);
        if (u8 == NULL || strlen(u8) >= ofn->nMaxFile)
        {
            if (u8 != NULL)
                SplShowNameTooLong(ofn->hwndOwner, ofn->lpstrTitle);
            ret = FALSE;
        }
        else
        {
            memcpy(ofn->lpstrFile, u8, strlen(u8) + 1);
            SplFileDlgDetail::NameOffsets(ofn->lpstrFile, &ofn->nFileOffset, &ofn->nFileExtension);
            if (ofn->lpstrFileTitle != NULL && ofn->nMaxFileTitle > 0)
                lstrcpynA(ofn->lpstrFileTitle, ofn->lpstrFile + ofn->nFileOffset, ofn->nMaxFileTitle);
        }
        free(u8);
    }
    free(file);
    free(initDir);
    free(filter);
    free(title);
    free(defExt);
    return ret;
}

// the folder picker (SHBrowseForFolderW, the same old-style dialog as the core's
// GetTargetDirectory): 'title' = the dialog's caption, 'comment' = the text above the
// tree (UTF-16, or NULL); 'initDir' UTF-8 or NULL; the picked folder goes to 'path'
// (UTF-8, 'pathSize' bytes). onlyNet: the tree starts at Network. A picked folder whose
// UTF-8 form does not fit is refused with a message. Call it on a thread with COM
// initialised (every plug-in's main thread is). Returns TRUE when a folder was picked.
inline BOOL SplBrowseForFolderU8(HWND parent, HWND centerWindow, const WCHAR* titleW,
                                 const WCHAR* commentW, char* path, int pathSize, BOOL onlyNet,
                                 const char* initDir)
{
    if (path == NULL || pathSize <= 0)
        return FALSE;
    WCHAR* initDirW = initDir != NULL && initDir[0] != 0 ? SplU8ToWAlloc(initDir) : NULL;

    LPITEMIDLIST root = NULL;
    if (onlyNet)
        SHGetSpecialFolderLocation(parent, CSIDL_NETWORK, &root);

    WCHAR display[MAX_PATH];
    BROWSEINFOW bi;
    memset(&bi, 0, sizeof(bi));
    bi.hwndOwner = parent;
    bi.pidlRoot = root;
    bi.pszDisplayName = display;
    bi.lpszTitle = commentW;
    bi.ulFlags = BIF_RETURNONLYFSDIRS;
    bi.lpfn = SplFileDlgDetail::BrowseCallback;
    SplFileDlgDetail::CBrowseData bd;
    bd.Title = titleW;
    bd.InitDir = initDirW;
    bd.CenterWindow = centerWindow;
    bi.lParam = (LPARAM)&bd;
    LPITEMIDLIST res = SHBrowseForFolderW(&bi);
    BOOL ret = FALSE;
    if (res != NULL)
    {
        WCHAR picked[MAX_PATH];
        if (SHGetPathFromIDListW(res, picked)) // a folder without a path cannot be confirmed (BFFM_ENABLEOK)
        {
            // feature 121: a NetHood folder shortcut means the folder it points at (the core's rule)
            WCHAR* target = SplFileDlgDetail::ResolveNetHoodFolderW(picked);
            char* u8 = SplWToU8Alloc(target != NULL ? target : picked);
            free(target);
            if (u8 != NULL && (int)strlen(u8) < pathSize)
            {
                memcpy(path, u8, strlen(u8) + 1);
                ret = TRUE;
            }
            else if (u8 != NULL)
                SplShowNameTooLongW(parent, titleW);
            free(u8);
        }
        CoTaskMemFree(res);
    }
    if (root != NULL)
        CoTaskMemFree(root);
    free(initDirW);
    return ret;
}

// the same with the caption and the comment as code-page text (resource strings)
inline BOOL SplBrowseForFolderU8(HWND parent, HWND centerWindow, const char* title,
                                 const char* comment, char* path, int pathSize, BOOL onlyNet,
                                 const char* initDir)
{
    WCHAR* titleW = SplFileDlgDetail::CodePageToWAlloc(title);
    WCHAR* commentW = SplFileDlgDetail::CodePageToWAlloc(comment);
    BOOL ret = SplBrowseForFolderU8(parent, centerWindow, titleW, commentW, path, pathSize, onlyNet, initDir);
    free(titleW);
    free(commentW);
    return ret;
}
