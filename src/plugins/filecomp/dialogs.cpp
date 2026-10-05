// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <shlobj.h> // feature 102: SHGetFolderPathW for the Browse retry
#include <cderr.h>  // feature 102: FNERR_INVALIDFILENAME

UINT_PTR CALLBACK
ComDlgHookProc(HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("ComDlgHookProc(, 0x%X, 0x%IX, 0x%IX)", uiMsg, wParam,
                        lParam);
    if (uiMsg == WM_INITDIALOG)
    {
        // SalamanderGUI->ArrangeHorizontalLines(hdlg);  // we do not do this for Windows common dialogs
        CenterWindow(hdlg);
        return 1;
    }
    return 0;
}

// ****************************************************************************
//
// CCompareFilesDialog
//

// history for combo boxes

// feature 102: UTF-8 (WTF-8) names of any length; the zero-filled array costs memory only
// for the pages the names really use
char CBHistory[MAX_HISTORY_ENTRIES][FC_NAME_SIZE];
int CBHistoryEntries;
// feature 102: the history is used by every comparator thread (each has its own dialog) and by
// the main thread (load, save, clear); copies of a string being rewritten could run past it
SRWLOCK HistoryLock = SRWLOCK_INIT;

void AddToHistory(LPCTSTR path)
{
    CALL_STACK_MESSAGE2(_T("AddToHistory(%s)"), path);
    if (strlen(path) >= FC_NAME_SIZE)
        return; // feature 102: never stored cut (cannot happen: every name buffer has this size)
    CHistoryLock lock(TRUE);
    int toMove = __min(CBHistoryEntries, MAX_HISTORY_ENTRIES - 1);
    int enlarge = 1;
    // check whether the same path is already in the history
    int i;
    for (i = 0; i < CBHistoryEntries; i++)
    {
        if (SG->IsTheSamePath(CBHistory[i], path))
        {
            toMove = i;
            enlarge = 0;
            break;
        }
    }
    // create space for the path we are going to store
    int j;
    for (j = toMove; j > 0; j--)
        _tcscpy(CBHistory[j], CBHistory[j - 1]);
    // And store the path...
    _tcscpy(CBHistory[0], path);
    CBHistoryEntries = __min(CBHistoryEntries + enlarge, MAX_HISTORY_ENTRIES);
}

CCompareFilesDialog::CCompareFilesDialog(HWND parent, LPTSTR path1, LPTSTR path2,
                                         BOOL& succes, CCompareOptions* options)
    : CCommonDialog(IDD_COMPAREFILES, parent), Succes(succes)
{
    CALL_STACK_MESSAGE_NONE
    Path1 = path1;
    Path2 = path2;
    Succes = succes;
    Options = options;
    CountedOpen = FALSE;
}

BOOL FileExists(LPCTSTR path)
{
    CALL_STACK_MESSAGE2(_T("FileExists(%s)"), path);
    DWORD attr = SG->SalGetFileAttributes(path);
    int i = GetLastError();
    // An error other than "not found" counts as "exists" on purpose: the file may be there and
    // only its attributes unreadable (a sharing violation on pagefile.sys, access denied on a
    // share); the comparison then reports the real error.  feature 102: except the errors
    // that say the name cannot name any file at all - a name with '?' (what a code-page
    // conversion left of a character outside the code page) gives ERROR_INVALID_NAME, the
    // dialog accepted it and the comparison failed with "syntax is incorrect".
    return ((attr != 0xffffffff) && (attr & FILE_ATTRIBUTE_DIRECTORY) == 0) ||
           ((attr == 0xffffffff) && ((i != ERROR_FILE_NOT_FOUND) && (i != ERROR_PATH_NOT_FOUND) &&
                                     (i != ERROR_INVALID_NAME) && (i != ERROR_BAD_PATHNAME) &&
                                     (i != ERROR_INVALID_DRIVE)));
}

// feature 102: the path fields as UTF-16 <-> the plug-in's UTF-8 (WTF-8: a lone surrogate
// survives, winliblt's EditLine would send it through the code page)

// the text of a field as malloc'ed UTF-8; NULL on low memory
static char* GetFieldTextU8Alloc(HWND field)
{
    int len = GetWindowTextLengthW(field);
    WCHAR* w = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
    if (w == NULL)
        return NULL;
    w[0] = 0;
    GetWindowTextW(field, w, len + 1);
    char* u8 = SplWToU8Alloc(w);
    free(w);
    return u8;
}

static void SetFieldTextU8(HWND field, const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w == NULL) // not UTF-8: code-page text of an older source, shown as such
    {
        int len = MultiByteToWideChar(CP_ACP, 0, text, -1, NULL, 0);
        w = len > 0 ? (WCHAR*)malloc((size_t)len * sizeof(WCHAR)) : NULL;
        if (w != NULL)
            MultiByteToWideChar(CP_ACP, 0, text, -1, w, len);
    }
    SetWindowTextW(field, w != NULL ? w : L"");
    free(w);
}

// adds a history entry (UTF-8) to a combo box as UTF-16
static void AddHistoryItemW(HWND combo, const char* text)
{
    WCHAR* w = SplU8ToWAlloc(text);
    if (w == NULL) // not UTF-8 (see SetFieldTextU8)
    {
        int len = MultiByteToWideChar(CP_ACP, 0, text, -1, NULL, 0);
        w = len > 0 ? (WCHAR*)malloc((size_t)len * sizeof(WCHAR)) : NULL;
        if (w != NULL)
            MultiByteToWideChar(CP_ACP, 0, text, -1, w, len);
    }
    if (w != NULL)
    {
        SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)w);
        free(w);
    }
}

void CCompareFilesDialog::Validate(CTransferInfo& ti)
{
    CALL_STACK_MESSAGE1("CCompareFilesDialog::Validate()");

    int i;
    for (i = 0; i < 2; i++)
    {
        char* buffer = GetFieldTextU8Alloc(GetDlgItem(HWindow, IDE_PATH1 + i));
        if (buffer == NULL)
        {
            Error(HWindow, IDS_LOWMEM);
            ti.ErrorOn(IDE_PATH1 + i);
            return;
        }
        if (!*buffer)
        {
            free(buffer);
            SG->SalMessageBox(HWindow, LoadStr(IDS_MISSINGPATH), LoadStr(IDS_ERROR), MB_ICONERROR);
            ti.ErrorOn(IDE_PATH1 + i);
            return;
        }
        // a name longer than any Windows path cannot exist (and would not fit Path1/Path2)
        if (strlen(buffer) >= FC_NAME_SIZE || !FileExists(buffer))
        {
            char* text = SprintfAlloc(LoadStrU8(IDS_FILEDOESNOTEXIST), buffer); // feature 102: UTF-8 template and name
            SG->SalMessageBox(HWindow, text != NULL ? text : LoadStrU8(IDS_LOWMEM), LoadStr(IDS_ERROR), MB_ICONERROR);
            free(text);
            free(buffer);
            ti.ErrorOn(IDE_PATH1 + i);
            return;
        }
        free(buffer);
    }
}

void CCompareFilesDialog::Transfer(CTransferInfo& ti)
{
    CALL_STACK_MESSAGE1("CCompareFilesDialog::Transfer()");
    if (ti.Type == ttDataToWindow)
    {
        SetFieldTextU8(GetDlgItem(HWindow, IDE_PATH1), Path1);
        SetFieldTextU8(GetDlgItem(HWindow, IDE_PATH2), Path2);
    }
    else
    {
        // Validate() has checked that both names exist and fit
        char* text1 = GetFieldTextU8Alloc(GetDlgItem(HWindow, IDE_PATH1));
        char* text2 = GetFieldTextU8Alloc(GetDlgItem(HWindow, IDE_PATH2));
        if (text1 == NULL || text2 == NULL)
        {
            free(text1);
            free(text2);
            Error(HWindow, IDS_LOWMEM);
            return; // Succes stays FALSE
        }
        CopyU8Truncated(Path1, FC_NAME_SIZE, text1);
        CopyU8Truncated(Path2, FC_NAME_SIZE, text2);
        free(text1);
        free(text2);
        AddToHistory(Path2);
        AddToHistory(Path1);
        Succes = TRUE;
    }
}

/*
UINT CALLBACK 
OFNHookProc(HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
{
  CALL_STACK_MESSAGE4("OFNHookProc(, 0x%X, 0x%IX, 0x%IX)", uiMsg, wParam, lParam);
  if (uiMsg == WM_INITDIALOG)
  {
    // SalamanderGUI->ArrangeHorizontalLines(hdlg);  // we do not do this for Windows common dialogs
    HWND hwnd = GetParent(hdlg);
    CenterWindow(hdlg);
    return 1;
  }
  return 0;
}
*/

// feature 102: the original window procedure of a path field (a window property, so the
// subclass works without the dialog object - before, every message after the dialog object
// was detached was swallowed)
static const WCHAR* FC_OLDPROC_PROP = L"TandemFcOldPathProc";

LRESULT CCompareFilesDialog::DragDropEditProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    // feature 102: installed with SetWindowLongPtrW, so every message arrives as UTF-16 and is
    // forwarded with CallWindowProcW - the field (a Unicode combo box under comctl32 6) stays
    // Unicode.  The code-page subclass before turned it into a code-page window, and every
    // text set into it or read from it lost the characters outside the code page.
    WNDPROC oldProc = (WNDPROC)GetPropW(hWnd, FC_OLDPROC_PROP);
    if (oldProc == NULL)
        return DefWindowProcW(hWnd, uMsg, wParam, lParam); // cannot happen

    if (WM_DROPFILES == uMsg)
    {
        // feature 102: the dropped name as UTF-16 of any length - DragQueryFileA best-fit
        // mapped it (voil<U+00E0>.txt became voila.txt on code page 1250), so a different
        // existing file could be compared
        HDROP hDrop = (HDROP)wParam;
        UINT len = DragQueryFileW(hDrop, 0, NULL, 0);
        if (len > 0)
        {
            WCHAR* name = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
            if (name != NULL)
            {
                if (DragQueryFileW(hDrop, 0, name, len + 1) > 0)
                    SetWindowTextW(hWnd, name);
                free(name);
            }
        }
        DragFinish(hDrop);
        return 0;
    }

    if (uMsg == WM_NCDESTROY)
    {
        RemovePropW(hWnd, FC_OLDPROC_PROP);
        SetWindowLongPtrW(hWnd, GWLP_WNDPROC, (LONG_PTR)oldProc);
    }
    return CallWindowProcW(oldProc, hWnd, uMsg, wParam, lParam);
}

// feature 102: the Browse button's open dialog as UTF-16 (the plug-in service
// SafeGetOpenFileName is code-page only); returns TRUE and sets the field when a file was
// chosen.  The retry mirrors the core's SafeGetOpenFileName: Windows refuses to open the
// dialog for some initial names ("C:\", a path that does not exist) - then Documents (or the
// Desktop) is the initial folder and the name is empty.
static BOOL BrowseForFileW(HWND dialog, HWND field, int titleID)
{
    const DWORD maxFile = 32768; // the longest path Windows has
    WCHAR* path = (WCHAR*)malloc(maxFile * sizeof(WCHAR));
    WCHAR* dir = NULL;
    if (path == NULL)
        return FALSE;
    path[0] = 0;
    GetWindowTextW(field, path, maxFile);

    OPENFILENAMEW ofn;
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = dialog;

    // "All Files (*.*)" \0 "*.*" \0 \0
    WCHAR filter[200];
    lstrcpynW(filter, SG->LoadStrW(HLanguage, IDS_ALLFILES), 190);
    size_t flen = wcslen(filter);
    memcpy(filter + flen + 1, L"*.*\0", 5 * sizeof(WCHAR));
    ofn.lpstrFilter = filter;

    if (path[0] == 0)
    {
        // an empty field: the folder of the first history entry of this field
        LRESULT len = SendMessageW(field, CB_GETLBTEXTLEN, 0, 0);
        if (len != CB_ERR && len > 0)
        {
            dir = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
            if (dir != NULL && SendMessageW(field, CB_GETLBTEXT, 0, (LPARAM)dir) != CB_ERR)
            {
                // cut the name; keep the backslash of a root ("C:\")
                WCHAR* cut = wcsrchr(dir, L'\\');
                if (cut != NULL)
                {
                    if (cut == dir + 2 && dir[1] == L':')
                        cut[1] = 0;
                    else
                        *cut = 0;
                    ofn.lpstrInitialDir = dir;
                }
            }
        }
    }
    ofn.lpstrFile = path;
    ofn.nMaxFile = maxFile;
    WCHAR title[200];
    lstrcpynW(title, SG->LoadStrW(HLanguage, titleID), _countof(title));
    ofn.lpstrTitle = title;
    ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR;

    BOOL ret = GetOpenFileNameW(&ofn);
    if (!ret && CommDlgExtendedError() == FNERR_INVALIDFILENAME)
    {
        WCHAR initDir[MAX_PATH];
        if (SHGetFolderPathW(NULL, CSIDL_PERSONAL, NULL, SHGFP_TYPE_CURRENT, initDir) != S_OK &&
            SHGetFolderPathW(NULL, CSIDL_DESKTOPDIRECTORY, NULL, SHGFP_TYPE_CURRENT, initDir) != S_OK)
        {
            initDir[0] = 0;
        }
        ofn.lpstrInitialDir = initDir;
        path[0] = 0;
        ret = GetOpenFileNameW(&ofn);
    }
    if (!ret && CommDlgExtendedError() != 0) // not Cancel
        TRACE_E("Cannot open OpenFile dialog box. CommDlgExtendedError()=" << CommDlgExtendedError());
    if (ret)
        SetWindowTextW(field, path);
    free(dir);
    free(path);
    return ret;
}

INT_PTR
CCompareFilesDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CCompareFilesDialog::DialogProc(0x%X, 0x%IX, 0x%IX)",
                        uMsg, wParam, lParam);
    UINT idCB;
    UINT idTitle;

    switch (uMsg)
    {
    case WM_INITDIALOG:
    {
        HWND hWnd1 = GetDlgItem(HWindow, IDE_PATH1), hWnd2 = GetDlgItem(HWindow, IDE_PATH2);

        SG->InstallWordBreakProc(hWnd1); // install WordBreakProc into the combo box
        SG->InstallWordBreakProc(hWnd2); // install WordBreakProc into the combo box

        // feature 102: a Unicode subclass (W get/set, see DragDropEditProc); the original
        // procedure is read with GetWindowLongPtrW, so it is the real UTF-16 procedure
        HWND fields[2] = {hWnd1, hWnd2};
        int f;
        for (f = 0; f < 2; f++)
        {
            WNDPROC oldProc = (WNDPROC)GetWindowLongPtrW(fields[f], GWLP_WNDPROC);
            if (oldProc != NULL && SetPropW(fields[f], FC_OLDPROC_PROP, (HANDLE)oldProc))
            {
                SetWindowLongPtrW(fields[f], GWLP_WNDPROC, (LONG_PTR)DragDropEditProc);
                DragAcceptFiles(fields[f], TRUE);
            }
        }

        SetWindowPos(HWindow, AlwaysOnTop ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);

        // initialize the history (feature 102: UTF-16 items from the UTF-8 history - the
        // code-page CB_ADDSTRING showed every non-ASCII name garbled, e.g. U+0159 as U+0139 U+2122)
        {
            CHistoryLock lock(FALSE);
            int i = 0;
            if (CBHistoryEntries > 1)
            {
                // store the first two paths in the second combo box in reverse order
                for (; i < 2; i++)
                {
                    AddHistoryItemW(hWnd1, CBHistory[i]);
                    AddHistoryItemW(hWnd2, CBHistory[1 - i]);
                }
            }
            for (; i < CBHistoryEntries; i++)
            {
                AddHistoryItemW(hWnd1, CBHistory[i]);
                AddHistoryItemW(hWnd2, CBHistory[i]);
            }
        }

        SendMessage(HWindow, WM_SETICON, ICON_BIG, (LPARAM)LoadIcon(DLLInstance, MAKEINTRESOURCE(IDI_FCICO)));

        InterlockedIncrement(&CompareDialogsOpen); // feature 118: holds typed names, see Release()
        CountedOpen = TRUE;
        break;
    }

    case WM_COMMAND:
    {
        switch (LOWORD(wParam))
        {
        case IDADVANCED:
        {
            BOOL setDefault = FALSE;
            CAdvancedOptionsDialog dlg(HWindow, Options, &setDefault);
            if (dlg.Execute() == IDOK && setDefault)
            {
                if (memcmp(Options, &DefCompareOptions, sizeof(*Options)) != 0)
                {
                    DefCompareOptions = *Options;
                    MainWindowQueue.BroadcastMessage(WM_USER_CFGCHNG, CC_DEFOPTIONS | CC_HAVEHWND, (LPARAM)GetParent(HWindow));
                }
            }
            return 0;
        }

        case IDB_BROWSE1:
        case IDB_BROWSE2:
        {
            if (IDB_BROWSE1 == LOWORD(wParam))
            {
                idCB = IDE_PATH1;
                idTitle = IDS_SELECTFIRST;
            }
            else
            {
                idCB = IDE_PATH2;
                idTitle = IDS_SELECTSECOND;
            }
            BrowseForFileW(HWindow, GetDlgItem(HWindow, idCB), idTitle); // feature 102: UTF-16
            return 0;
        }
        }
        break;
    }

    case WM_USER_CLEARHISTORY:
    {
        // feature 102: keep the typed text as UTF-16 of any length while the list is emptied
        int f;
        for (f = 0; f < 2; f++)
        {
            HWND cb = GetDlgItem(HWindow, IDE_PATH1 + f);
            int len = GetWindowTextLengthW(cb);
            WCHAR* buffer = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
            if (buffer != NULL)
            {
                buffer[0] = 0;
                GetWindowTextW(cb, buffer, len + 1);
            }
            SendMessageW(cb, CB_RESETCONTENT, 0, 0);
            if (buffer != NULL)
            {
                SetWindowTextW(cb, buffer);
                free(buffer);
            }
        }
        break;
    }

    case WM_DESTROY:
        DragAcceptFiles(GetDlgItem(HWindow, IDE_PATH1), FALSE);
        DragAcceptFiles(GetDlgItem(HWindow, IDE_PATH2), FALSE);
        if (CountedOpen)
        {
            InterlockedDecrement(&CompareDialogsOpen); // feature 118
            CountedOpen = FALSE;
        }
        break;
    }

    return CCommonDialog::DialogProc(uMsg, wParam, lParam);
}

// ****************************************************************************
//
// CCommonPropSheetPage
//

void CCommonPropSheetPage::NotifDlgJustCreated()
{
    SalGUI->ArrangeHorizontalLines(HWindow);
}
