// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "array2.h"

#include "fdi.h"
#include "uncab.h"
#include "dialogs.h"
#include "splfiledlg.h" // feature 104: the Unicode folder picker

#include "uncab.rh"
#include "uncab.rh2"
#include "lang\lang.rh"

WNDPROC OrigTextControlProc;

// Shared theme handling for all raw dialog procs in this plugin: themes the
// dialog on WM_INITDIALOG (and lets the proc continue with its own init) and
// colors the WM_CTLCOLOR* family while the Dark theme is active (feature 036).
static BOOL CABThemeDlgMsg(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam, INT_PTR* result)
{
    if (uMsg == WM_INITDIALOG)
    {
        SalamanderGeneral->ThemeApplyToDialog(hDlg);
        return FALSE; // theming done, the dialog continues its own init
    }
    return SalamanderGeneral->ThemeHandleCtlColor(uMsg, wParam, lParam, result);
}

LRESULT CALLBACK TextControlProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("TextControlProc(, 0x%X, 0x%IX, 0x%IX)", uMsg, wParam,
                        lParam);
    switch (uMsg)
    {
    case WM_PAINT:
    {
        RECT r;
        PAINTSTRUCT ps;

        GetClientRect(hWnd, &r);
        BeginPaint(hWnd, &ps);
        HBRUSH DialogBrush = CreateSolidBrush(SalamanderGeneral->GetThemeSysColor(COLOR_BTNFACE)); // feature 036
        if (DialogBrush)
        {
            FillRect(ps.hdc, &r, DialogBrush);
            DeleteObject(DialogBrush);
        }
        HFONT hCurrentFont = (HFONT)SendMessage(hWnd, WM_GETFONT, 0, 0);
        HFONT hOldFont = (HFONT)SelectObject(ps.hdc, hCurrentFont);
        SetTextColor(ps.hdc, SalamanderGeneral->GetThemeSysColor(COLOR_BTNTEXT)); // feature 036
        int prevBkMode = SetBkMode(ps.hdc, TRANSPARENT);
        // feature 104: read and drawn as UTF-16 (GetWindowText A + DrawText A showed '?' or a
        // best-fit look-alike for every character outside the code page)
        SplDrawWindowTextW(hWnd, ps.hdc, &r, DT_SINGLELINE | /*DT_VCENTER*/ DT_BOTTOM | DT_NOPREFIX | DT_PATH_ELLIPSIS);
        SetBkMode(ps.hdc, prevBkMode);
        SelectObject(ps.hdc, hOldFont);
        EndPaint(hWnd, &ps);
        return 0;
    }
    }
    return CallWindowProcW(OrigTextControlProc, hWnd, uMsg, wParam, lParam); // feature 104: a Unicode subclass
}

// ****************************************************************************
//
// CDlgRoot
//

void CDlgRoot::CenterDlgToParent()
{
    CALL_STACK_MESSAGE1("CDlgRoot::CenterDlgToParent()");
    HWND hParent = GetParent(Dlg);
    if (hParent != NULL)
        SalamanderGeneral->MultiMonCenterWindow(Dlg, hParent, TRUE);
}

void CDlgRoot::SubClassStatic(DWORD wID, BOOL subclass)
{
    CALL_STACK_MESSAGE3("CDlgRoot::SubClassStatic(0x%X, %d)", wID, subclass);
    // feature 104: through the W entry points, so the label stays a Unicode window (a
    // code-page subclass stores every text set into it through the code page)
    if (subclass)
        OrigTextControlProc = (WNDPROC)SetWindowLongPtrW(GetDlgItem(Dlg, wID), GWLP_WNDPROC, (LONG_PTR)TextControlProc);
    else
        SetWindowLongPtrW(GetDlgItem(Dlg, wID), GWLP_WNDPROC, (LONG_PTR)OrigTextControlProc);
}

// ****************************************************************************
//
// CNextVolumeDialog
//

INT_PTR WINAPI NextVolumeDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (CABThemeDlgMsg(hDlg, uMsg, wParam, lParam, &themeResult))
        return themeResult;
    CALL_STACK_MESSAGE4("NextVolumeDlgProc(, 0x%X, 0x%IX, 0x%IX)", uMsg, wParam,
                        lParam);
    static CNextVolumeDialog* dlg = NULL;

    switch (uMsg)
    {
    case WM_INITDIALOG:
        // SalamanderGUI->ArrangeHorizontalLines(hDlg); // it should be called, but we ignore it here, there are no horizontal lines
        dlg = (CNextVolumeDialog*)lParam;
        dlg->Dlg = hDlg;
        return dlg->DialogProc(uMsg, wParam, lParam);

    default:
        if (dlg)
            return dlg->DialogProc(uMsg, wParam, lParam);
    }
    return FALSE;
}

INT_PTR
CNextVolumeDialog::Proceed()
{
    CALL_STACK_MESSAGE1("CNextVolumeDialog::Proceed()");
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_CHANGEDISK),
                          Parent, NextVolumeDlgProc, (LPARAM)this);
}

INT_PTR
CNextVolumeDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CNextVolumeDialog::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg,
                        wParam, lParam);
    switch (uMsg)
    {
    case WM_INITDIALOG:
        return OnInit(wParam, lParam);
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDOK:
            return OnOK(HIWORD(wParam), LOWORD(wParam), (HWND)lParam);

        case IDCANCEL:
            EndDialog(Dlg, IDCANCEL);
            return FALSE;

        case IDC_BROWSE:
            return OnBrowse(HIWORD(wParam), LOWORD(wParam), (HWND)lParam);
        }
        break;
    }
    return FALSE;
}

BOOL CNextVolumeDialog::OnInit(WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE3("CNextVolumeDialog::OnInit(0x%IX, 0x%IX)", wParam, lParam);
    char buf[1024];
    sprintf(buf, LoadStr(IDS_NEXTVOLTEXT), CabNumber);
    SendDlgItemMessage(Dlg, IDC_TEXT, WM_SETTEXT, 0, (LPARAM)buf);
    // VolumeName/VolumePath/DiskName are UTF-8 (interface 104). feature 104: the controls
    // are Unicode windows (comctl32 6, also in a dialog made by the -A API), so the names
    // are set as UTF-16 - the former round trip through the code page showed '?' or a
    // best-fit look-alike ("voila" for "voil<U+00E0>") and OnOK then read that look-alike
    // back as the folder of the next volume: another existing folder could be used
    SetDlgItemTextU8OrAcp(Dlg, IDC_DISKNAME, DiskName);
    SetDlgItemTextU8OrAcp(Dlg, IDC_CABNAME, VolumeName);
    SendDlgItemMessage(Dlg, IDC_FILENAME, EM_SETLIMITTEXT, MAX_PATH - 1, 0);
    SetDlgItemTextU8OrAcp(Dlg, IDC_FILENAME, VolumePath);

    CenterDlgToParent();
    return TRUE;
}

BOOL CNextVolumeDialog::OnBrowse(WORD wNotifyCode, WORD wID, HWND hwndCtl)
{
    CALL_STACK_MESSAGE3("CNextVolumeDialog::OnBrowse(0x%X, 0x%X, )", wNotifyCode,
                        wID);
    // feature 104: the field and the shell's folder picker are used as UTF-16 and the
    // folder goes on as UTF-8 - the former ANSI exchange (GetDlgItemText A, SHBrowseForFolder
    // A) converted with best fit, so a folder named outside the code page came back as '?' or
    // as a look-alike existing folder. Only the field is changed here; OnOK takes it from there
    // (before, a Browse also stored the code-page form in VolumePath directly).
    char initDir[MAX_PATH * 3];
    GetDlgItemTextU8(Dlg, IDC_FILENAME, initDir, sizeof(initDir));                   // empty when it does not fit
    WCHAR* fmtW = SplFileDlgDetail::CodePageToWAlloc(LoadStr(IDS_BROWSEFOLDERTEXT)); // "%s" = the cabinet's name
    WCHAR* nameW = SplU8ToWAlloc(VolumeName);
    WCHAR comment[1024];
    comment[0] = 0;
    if (fmtW != NULL)
        _snwprintf_s(comment, _TRUNCATE, fmtW, nameW != NULL ? nameW : L"");
    free(fmtW);
    free(nameW);
    WCHAR* titleW = SplFileDlgDetail::CodePageToWAlloc(LoadStr(IDS_BROWSEARCHIVETITLE));
    char picked[MAX_PATH * 3];
    if (SplBrowseForFolderU8(Dlg, NULL, titleW, comment, picked, sizeof(picked), FALSE, initDir))
        SetDlgItemTextU8OrAcp(Dlg, IDC_FILENAME, picked);
    free(titleW);
    return TRUE;
}

BOOL CNextVolumeDialog::OnOK(WORD wNotifyCode, WORD wID, HWND hwndCtl)
{
    CALL_STACK_MESSAGE3("CNextVolumeDialog::OnOK(0x%X, 0x%X, )", wNotifyCode, wID);
    // feature 104: the field is read as UTF-16 and stored as UTF-8 for the core calls below
    // and for FDI (VolumePath is FDI's CB_MAX_CAB_PATH cabinet-path buffer; interface 104).
    // The former GetDlgItemText A converted with best fit: a folder named outside the code
    // page became '?' or a look-alike existing folder. A path that does not fit (with room
    // for the backslash added below) is refused, never cut.
    char path[CB_MAX_CAB_PATH];
    if (GetDlgItemTextU8(Dlg, IDC_FILENAME, path, CB_MAX_CAB_PATH - 1) == 0)
    {
        SplShowNameTooLong(Dlg, LoadStr(IDS_ERROR));
        return TRUE;
    }
    lstrcpyn(VolumePath, path, CB_MAX_CAB_PATH);
    SalamanderGeneral->SalPathAddBackslash(VolumePath, CB_MAX_CAB_PATH);

    char fullName[CB_MAX_CAB_PATH + CB_MAX_CABINET_NAME + 1];
    strcpy(fullName, VolumePath);
    SalamanderGeneral->SalPathAppend(fullName, VolumeName, sizeof(fullName));

    SalamanderGeneral->SalUpdateDefaultDir(TRUE);
    int err;
    if (!SalamanderGeneral->SalGetFullName(fullName, &err, CurrentPath))
    {
        char buffer[100];
        SalamanderGeneral->SalMessageBox(Dlg, SalamanderGeneral->GetGFNErrorText(err, buffer, 100),
                                         LoadStr(IDS_ERROR), MB_OK | MB_ICONERROR);
        return TRUE;
    }

    DWORD attr = SalamanderGeneral->SalGetFileAttributes(fullName);
    if (attr == 0xFFFFFFFF || (attr & FILE_ATTRIBUTE_DIRECTORY))
    {
        SalamanderGeneral->SalMessageBox(Dlg, LoadStr(IDS_NOTFOUND),
                                         LoadStr(IDS_ERROR), MB_OK | MB_ICONERROR);
        return TRUE;
    }

    EndDialog(Dlg, IDOK);
    return TRUE;
}

INT_PTR NextVolumeDialog(HWND parent, char* volumeName, char* volumePath, char* diskName, int cabNumber)
{
    CALL_STACK_MESSAGE1("NextVolumeDialog(, )");
    CNextVolumeDialog dlg(parent, volumeName, volumePath, diskName, cabNumber);
    HWND mainWnd = SalamanderGeneral->GetWndToFlash(parent);
    INT_PTR ret = dlg.Proceed();
    if (mainWnd != NULL)
        FlashWindow(mainWnd, FALSE);
    return ret;
}

// ****************************************************************************
//
// CContinuedFileDialog
//

INT_PTR WINAPI ContinuedFileDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (CABThemeDlgMsg(hDlg, uMsg, wParam, lParam, &themeResult))
        return themeResult;
    CALL_STACK_MESSAGE4("ContinuedFileDlgProc(, 0x%X, 0x%IX, 0x%IX)", uMsg, wParam,
                        lParam);
    static CContinuedFileDialog* dlg = NULL;

    switch (uMsg)
    {
    case WM_INITDIALOG:
        // SalamanderGUI->ArrangeHorizontalLines(hDlg); // it should be called, but we ignore it here, there are no horizontal lines
        dlg = (CContinuedFileDialog*)lParam;
        dlg->Dlg = hDlg;
        return dlg->DialogProc(uMsg, wParam, lParam);

    default:
        if (dlg)
            return dlg->DialogProc(uMsg, wParam, lParam);
    }
    return FALSE;
}

INT_PTR
CContinuedFileDialog::Proceed()
{
    CALL_STACK_MESSAGE1("CContinuedFileDialog::Proceed()");
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_ERROR),
                          Parent, ContinuedFileDlgProc, (LPARAM)this);
}

INT_PTR
CContinuedFileDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CContinuedFileDialog::DialogProc(0x%X, 0x%IX, 0x%IX)",
                        uMsg, wParam, lParam);
    switch (uMsg)
    {
    case WM_INITDIALOG:
        return OnInit(wParam, lParam);
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDSKIP:
            if (SendDlgItemMessage(Dlg, IDC_DONTSHOW, BM_GETCHECK, 0, 0) == BST_CHECKED)
                Options |= OP_SKIPCONTINUED;
            EndDialog(Dlg, IDSKIP);
            return FALSE;

        case IDALL:
            if (SendDlgItemMessage(Dlg, IDC_DONTSHOW, BM_GETCHECK, 0, 0) == BST_CHECKED)
                Options |= OP_SKIPCONTINUED;
            EndDialog(Dlg, IDALL);
            return FALSE;

        case IDCANCEL:
            EndDialog(Dlg, IDCANCEL);
            return FALSE;
        }
        break;

    case WM_DESTROY:
        SubClassStatic(IDS_FILENAME, FALSE);
        return TRUE;
    }
    return FALSE;
}

BOOL CContinuedFileDialog::OnInit(WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE3("CContinuedFileDialog::OnInit(0x%IX, 0x%IX)", wParam, lParam);
    SubClassStatic(IDS_FILENAME, TRUE);
    // 'File' is a UTF-8 name from the cabinet (interface 104); feature 104: set as UTF-16
    // (the label is a Unicode window again, see SubClassStatic)
    SetDlgItemTextU8OrAcp(Dlg, IDS_FILENAME, File);

    CenterDlgToParent();
    return TRUE;
}

/*
BOOL 
CContinuedFileDialog::OnOK(WORD wNotifyCode, WORD wID, HWND hwndCtl)
{
  if (SendDlgItemMessage(Dlg, IDC_DONTSHOW, BM_GETCHECK, 0, 0) == BST_CHECKED)
    Options |= OP_SKIPCONTINUED;
  
  EndDialog(Dlg, IDOK);
  return TRUE;
}
*/

INT_PTR ContinuedFileDialog(HWND parent, const char* file)
{
    CALL_STACK_MESSAGE2("ContinuedFileDialog(, %s)", file);
    CContinuedFileDialog dlg(parent, file);
    HWND mainWnd = SalamanderGeneral->GetWndToFlash(parent);
    INT_PTR ret = dlg.Proceed();
    if (mainWnd != NULL)
        FlashWindow(mainWnd, FALSE);
    return ret;
}

// ****************************************************************************
//
// CConfigDialog
//

INT_PTR WINAPI ConfigDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (CABThemeDlgMsg(hDlg, uMsg, wParam, lParam, &themeResult))
        return themeResult;
    CALL_STACK_MESSAGE4("ConfigDlgProc(, 0x%X, 0x%IX, 0x%IX)", uMsg, wParam, lParam);
    static CConfigDialog* dlg = NULL;

    switch (uMsg)
    {
    case WM_INITDIALOG:
        // SalamanderGUI->ArrangeHorizontalLines(hDlg); // it should be called, but we ignore it here, there are no horizontal lines
        dlg = (CConfigDialog*)lParam;
        dlg->Dlg = hDlg;
        return dlg->DialogProc(uMsg, wParam, lParam);

    default:
        if (dlg)
            return dlg->DialogProc(uMsg, wParam, lParam);
    }
    return FALSE;
}

INT_PTR
CConfigDialog::Proceed()
{
    CALL_STACK_MESSAGE1("CConfigDialog::Proceed()");
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_CONFIG),
                          Parent, ConfigDlgProc, (LPARAM)this);
}

INT_PTR
CConfigDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CConfigDialog::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg,
                        wParam, lParam);
    switch (uMsg)
    {
    case WM_INITDIALOG:
        return OnInit(wParam, lParam);
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDOK:
            return OnOK(HIWORD(wParam), LOWORD(wParam), (HWND)lParam);

        case IDCANCEL:
            EndDialog(Dlg, IDCANCEL);
            return FALSE;
        }
        break;
    }
    return FALSE;
}

BOOL CConfigDialog::OnInit(WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE3("CConfigDialog::OnInit(0x%IX, 0x%IX)", wParam, lParam);
    SendDlgItemMessage(Dlg, IDC_SKIPCONTINUED, BM_SETCHECK, Options & OP_SKIPCONTINUED ? BST_CHECKED : BST_UNCHECKED, 0);
    SendDlgItemMessage(Dlg, IDC_NOVOLATTENTION, BM_SETCHECK, Options & OP_NO_VOL_ATTENTION ? BST_CHECKED : BST_UNCHECKED, 0);

    CenterDlgToParent();
    return TRUE;
}

BOOL CConfigDialog::OnOK(WORD wNotifyCode, WORD wID, HWND hwndCtl)
{
    CALL_STACK_MESSAGE3("CConfigDialog::OnOK(0x%X, 0x%X, )", wNotifyCode, wID);
    if (SendDlgItemMessage(Dlg, IDC_SKIPCONTINUED, BM_GETCHECK, 0, 0) == BST_CHECKED)
        Options |= OP_SKIPCONTINUED;
    else
        Options &= ~OP_SKIPCONTINUED;
    if (SendDlgItemMessage(Dlg, IDC_NOVOLATTENTION, BM_GETCHECK, 0, 0) == BST_CHECKED)
        Options |= OP_NO_VOL_ATTENTION;
    else
        Options &= ~OP_NO_VOL_ATTENTION;

    EndDialog(Dlg, IDOK);
    return TRUE;
}

INT_PTR ConfigDialog(HWND parent)
{
    CALL_STACK_MESSAGE1("ConfigDialog()");
    CConfigDialog dlg(parent);
    return dlg.Proceed();
}

// ****************************************************************************
//
// CAttentionDialog
//

INT_PTR WINAPI AttentionDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

    INT_PTR themeResult; // feature 036: dark-theme touchpoints
    if (CABThemeDlgMsg(hDlg, uMsg, wParam, lParam, &themeResult))
        return themeResult;
    CALL_STACK_MESSAGE4("AttentionDlgProc(, 0x%X, 0x%IX, 0x%IX)", uMsg, wParam,
                        lParam);
    static CAttentionDialog* dlg = NULL;

    switch (uMsg)
    {
    case WM_INITDIALOG:
        // SalamanderGUI->ArrangeHorizontalLines(hDlg); // it should be called, but we ignore it here, there are no horizontal lines
        dlg = (CAttentionDialog*)lParam;
        dlg->Dlg = hDlg;
        return dlg->DialogProc(uMsg, wParam, lParam);

    default:
        if (dlg)
            return dlg->DialogProc(uMsg, wParam, lParam);
    }
    return FALSE;
}

INT_PTR
CAttentionDialog::Proceed()
{
    CALL_STACK_MESSAGE1("CAttentionDialog::Proceed()");
    return DialogBoxParam(HLanguage, MAKEINTRESOURCE(IDD_WARNING),
                          Parent, AttentionDlgProc, (LPARAM)this);
}

INT_PTR
CAttentionDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CAttentionDialog::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg,
                        wParam, lParam);
    switch (uMsg)
    {
    case WM_INITDIALOG:
        CenterDlgToParent();
        break;

    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDOK:
            return OnOK(HIWORD(wParam), LOWORD(wParam), (HWND)lParam);

        case IDCANCEL:
            EndDialog(Dlg, IDCANCEL);
            return FALSE;
        }
        break;
    }
    return FALSE;
}

BOOL CAttentionDialog::OnOK(WORD wNotifyCode, WORD wID, HWND hwndCtl)
{
    CALL_STACK_MESSAGE3("CAttentionDialog::OnOK(0x%X, 0x%X, )", wNotifyCode, wID);
    if (SendDlgItemMessage(Dlg, IDC_DONTSHOW, BM_GETCHECK, 0, 0) == BST_CHECKED)
        Options |= OP_NO_VOL_ATTENTION;

    EndDialog(Dlg, IDOK);
    return TRUE;
}

INT_PTR AttentionDialog(HWND parent)
{
    CALL_STACK_MESSAGE1("AttentionDialog()");
    CAttentionDialog dlg(parent);
    HWND mainWnd = SalamanderGeneral->GetWndToFlash(parent);
    INT_PTR ret = dlg.Proceed();
    if (mainWnd != NULL)
        FlashWindow(mainWnd, FALSE);
    return ret;
}
