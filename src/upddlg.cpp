// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "mainwnd.h"
#include "cfgdlg.h"
#include "dialogs.h"
#include "gui.h"
#include "brand.h"
#include "upddlg.h"

HWND UpdateAboutWindow = NULL;

static HWND UpdateNoticeWindow = NULL;     // this instance's notification
static CSalUpdVersion UpdateNoticeVersion; // the version it announces (valid while the window exists)
static BOOL UpdateManualWaiting = FALSE;
static BOOL UpdateNoticeAttached = FALSE; // the dialog object got its window (it then deletes itself)

// how long the wait dialog of a manual check stays hidden, and when the caller gives up
#define UPDATEMANUAL_QUIET_MS 500
#define UPDATEMANUAL_GIVEUP_MS 15000
#define IDT_UPDATECHECKING 1

//
// ****************************************************************************
// CUpdateLink
//

LRESULT
CUpdateLink::WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    if (uMsg == WM_GETDLGCODE)
    {
        LRESULT code = CHyperLink::WindowProc(uMsg, wParam, lParam);
        MSG* msg = (MSG*)lParam;
        if (msg != NULL && msg->message == WM_KEYDOWN && msg->wParam == VK_RETURN)
            code |= DLGC_WANTMESSAGE; // Enter is ours, not the default button's
        return code;
    }
    if (uMsg == WM_KEYDOWN && wParam == VK_RETURN)
    {
        ExecuteIt();
        return 0;
    }
    return CHyperLink::WindowProc(uMsg, wParam, lParam);
}

//
// ****************************************************************************
// opening an address
//

BOOL UpdateCheck_OpenUrl(HWND parent, const char* url)
{
    CALL_STACK_MESSAGE1("UpdateCheck_OpenUrl()");
    WCHAR urlW[SALUPD_URL_MAX];
    int i = 0;
    for (; url[i] != 0 && i < _countof(urlW) - 1; i++)
        urlW[i] = (WCHAR)(unsigned char)url[i]; // constructed addresses are ASCII
    urlW[i] = 0;

    BOOL ok;
#ifdef _DEBUG
    // test seam, Debug builds only: a probe records what would be opened instead of starting a browser
    WCHAR logName[MAX_PATH];
    DWORD len = GetEnvironmentVariableW(L"TC_UPDATECHECK_OPENLOG", logName, _countof(logName));
    if (len > 0 && len < _countof(logName))
    {
        HANDLE file = NOHANDLES(CreateFileW(logName, FILE_APPEND_DATA, FILE_SHARE_READ, NULL, OPEN_ALWAYS,
                                            FILE_ATTRIBUTE_NORMAL, NULL));
        ok = file != INVALID_HANDLE_VALUE;
        if (ok)
        {
            DWORD written;
            WriteFile(file, url, (DWORD)strlen(url), &written, NULL);
            WriteFile(file, "\r\n", 2, &written, NULL);
            NOHANDLES(CloseHandle(file));
        }
    }
    else
#endif // _DEBUG
        ok = (INT_PTR)ShellExecuteW(parent, L"open", urlW, NULL, NULL, SW_SHOWNORMAL) > 32;

    if (!ok)
    {
        char text[SALUPD_URL_MAX + 500];
        _snprintf_s(text, _TRUNCATE, LoadStrU8(IDS_UPDATE_ERR_BROWSER), url);
        char title[200];
        lstrcpyn(title, LoadStrU8(IDS_UPDATE_TITLE), _countof(title));
        if (SalMessageBox(parent, text, title, MB_YESNO | MB_ICONEXCLAMATION) == IDYES)
            CopyTextToClipboardU8Report(parent, url);
    }
    return ok;
}

//
// ****************************************************************************
// CUpdateNoticeDialog - the notification about a new version
//
// Modeless and owned by the main window: it does not block the program at
// start-up, an installer's close request finds the main window enabled, and
// it can be shown without taking the keyboard. It holds nothing to lose, so
// it declares itself closable for an unattended close (feature 088).
//

class CUpdateNoticeDialog : public CCommonDialog
{
public:
    CUpdateNoticeDialog(HWND parent, const CSalUpdRelease& release, BOOL activate);
    ~CUpdateNoticeDialog();

protected:
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    void PaintHeader();              // (re)paints the header band into HeaderBitmap
    void FitVersionFont(int ctrlID); // the largest of the three faces in which the control's text fits
    void DrawArrow(DRAWITEMSTRUCT* dis);

    CSalUpdRelease Release;
    BOOL Activate; // FALSE: the window must not take the activation or the keyboard when it appears
    CBitmap* HeaderBitmap;
    RECT WordmarkR;
    RECT LogoR;
    int AccentY;
    int BandBottom; // first row below the header band
    HFONT HTitleFont;
    HFONT HVersionFont;
};

CUpdateNoticeDialog::CUpdateNoticeDialog(HWND parent, const CSalUpdRelease& release, BOOL activate)
    : CCommonDialog(HLanguage, IDD_UPDATENOTICE, parent, ooStandard)
{
    Release = release;
    Activate = activate;
    HeaderBitmap = NULL;
    memset(&WordmarkR, 0, sizeof(WordmarkR));
    memset(&LogoR, 0, sizeof(LogoR));
    AccentY = 0;
    BandBottom = 0;
    HTitleFont = NULL;
    HVersionFont = NULL;
}

CUpdateNoticeDialog::~CUpdateNoticeDialog()
{
    if (HeaderBitmap != NULL)
        delete HeaderBitmap;
    if (HTitleFont != NULL)
        HANDLES(DeleteObject(HTitleFont));
    if (HVersionFont != NULL)
        HANDLES(DeleteObject(HVersionFont));
}

void CUpdateNoticeDialog::PaintHeader()
{
    RECT client;
    GetClientRect(HWindow, &client);
    if (HeaderBitmap != NULL)
    {
        delete HeaderBitmap;
        HeaderBitmap = NULL;
    }
    // the accent line is a few pixels high; the bitmap is cut to the band once its height is known
    int maxBandH = AccentY + 40;
    CBitmap* bitmap = new CBitmap();
    HDC hDC = HANDLES(GetDC(NULL));
    BOOL ok = bitmap->CreateBmp(hDC, client.right, maxBandH);
    HANDLES(ReleaseDC(NULL, hDC));
    if (!ok)
    {
        delete bitmap;
        BandBottom = AccentY;
        return;
    }
    RECT band = {0, 0, client.right, maxBandH};
    BandBottom = TCPaintBrandHeader(bitmap->HMemDC, &band, &WordmarkR, &LogoR, AccentY);
    HeaderBitmap = bitmap;
}

void CUpdateNoticeDialog::FitVersionFont(int ctrlID)
{
    HWND hCtrl = GetDlgItem(HWindow, ctrlID);
    if (hCtrl == NULL)
        return;
    WCHAR text[SALUPD_VERSION_TEXT_MAX];
    int len = GetWindowTextW(hCtrl, text, _countof(text));
    RECT r;
    GetClientRect(hCtrl, &r);
    HFONT fonts[3] = {HVersionFont, HTitleFont, (HFONT)SendMessage(HWindow, WM_GETFONT, 0, 0)};
    HDC hDC = HANDLES(GetDC(hCtrl));
    for (int i = 0; i < 3; i++)
    {
        if (fonts[i] == NULL)
            continue;
        HFONT hOld = (HFONT)SelectObject(hDC, fonts[i]);
        SIZE size = {0, 0};
        GetTextExtentPoint32W(hDC, text, len, &size);
        SelectObject(hDC, hOld);
        if (size.cx <= r.right || i == 2)
        {
            SendMessage(hCtrl, WM_SETFONT, (WPARAM)fonts[i], FALSE);
            break;
        }
    }
    HANDLES(ReleaseDC(hCtrl, hDC));
}

void CUpdateNoticeDialog::DrawArrow(DRAWITEMSTRUCT* dis)
{
    // drawn, so that it does not depend on a glyph of the dialog font
    HDC hDC = dis->hDC;
    RECT r = dis->rcItem;
    FillRect(hDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));
    int h = r.bottom - r.top;
    int w = r.right - r.left;
    int midY = r.top + h / 2;
    int thick = max(1, h / 9);
    int head = max(3, h / 3);
    HPEN hPen = HANDLES(CreatePen(PS_SOLID, thick, ThemeSysColor(COLOR_GRAYTEXT)));
    HPEN hOldPen = (HPEN)SelectObject(hDC, hPen);
    int x1 = r.left + w / 8;
    int x2 = r.right - w / 8;
    MoveToEx(hDC, x1, midY, NULL);
    LineTo(hDC, x2, midY);
    MoveToEx(hDC, x2 - head, midY - head, NULL);
    LineTo(hDC, x2, midY);
    LineTo(hDC, x2 - head - 1, midY + head + 1);
    SelectObject(hDC, hOldPen);
    HANDLES(DeleteObject(hPen));
}

INT_PTR
CUpdateNoticeDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CUpdateNoticeDialog::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg, wParam, lParam);

    switch (uMsg)
    {
    case WM_INITDIALOG:
    {
        UpdateNoticeWindow = HWindow;
        UpdateNoticeVersion = Release.Version;
        UpdateNoticeAttached = TRUE;
        SetPropW(HWindow, UPDATENOTICE_WINDOW_PROP, (HANDLE)(INT_PTR)1);
        // nothing to lose here: an installer may close the program while this window is open
        SetPropA(HWindow, SALCLOSEAPP_WINDOW_PROP, (HANDLE)(INT_PTR)1);

        // the placeholders give the layout of the painted header band
        RECT accentR;
        GetDlgItemRectAndDestroy(HWindow, IDC_UPDN_WORDMARK, &WordmarkR);
        GetDlgItemRectAndDestroy(HWindow, IDC_UPDN_LOGO, &LogoR);
        GetDlgItemRectAndDestroy(HWindow, IDC_UPDN_ACCENT, &accentR);
        AccentY = accentR.top;
        PaintHeader();

        // the heading and the two versions use the dialog's own font, larger and bold
        HFONT hFont = (HFONT)SendMessage(HWindow, WM_GETFONT, 0, 0);
        LOGFONT lf;
        if (hFont != NULL && GetObject(hFont, sizeof(lf), &lf) != 0)
        {
            LONG baseHeight = lf.lfHeight;
            lf.lfWeight = FW_BOLD;
            lf.lfHeight = MulDiv(baseHeight, 14, 10);
            HTitleFont = HANDLES(CreateFontIndirect(&lf));
            lf.lfHeight = MulDiv(baseHeight, 21, 10);
            HVersionFont = HANDLES(CreateFontIndirect(&lf));
        }
        if (HTitleFont != NULL)
            SendDlgItemMessage(HWindow, IDC_UPDN_TITLE, WM_SETFONT, (WPARAM)HTitleFont, FALSE);
        if (HVersionFont != NULL)
        {
            SendDlgItemMessage(HWindow, IDC_UPDN_INSTVER, WM_SETFONT, (WPARAM)HVersionFont, FALSE);
            SendDlgItemMessage(HWindow, IDC_UPDN_NEWVER, WM_SETFONT, (WPARAM)HVersionFont, FALSE);
        }

        // both versions are printed from parsed numbers
        char version[SALUPD_VERSION_TEXT_MAX];
        CSalUpdVersion installed;
        UpdateCheck_GetInstalledVersion(&installed);
        SalUpdFormatVersion(installed, version, sizeof(version));
        SetDlgItemTextA(HWindow, IDC_UPDN_INSTVER, version);
        SalUpdFormatVersion(Release.Version, version, sizeof(version));
        SetDlgItemTextA(HWindow, IDC_UPDN_NEWVER, version);
        // a version number is never cut: one that does not fit its place in the large face
        // (up to "99999.99999.99999" is valid) is shown in the next smaller one
        FitVersionFont(IDC_UPDN_INSTVER);
        FitVersionFont(IDC_UPDN_NEWVER);

        WCHAR date[100];
        if (UpdateCheck_FormatDate(Release.PublishedUtc, date, _countof(date)))
        {
            WCHAR released[200];
            _snwprintf_s(released, _TRUNCATE, LoadStrW(IDS_UPDATE_RELEASED), date);
            SetDlgItemTextW(HWindow, IDC_UPDN_RELEASED, released);
        }

        CUpdateLink* notes = new CUpdateLink(HWindow, IDC_UPDN_NOTES);
        if (notes != NULL)
        {
            notes->SetText(LoadStrU8(IDS_UPDATE_NOTESLINK));
            notes->SetActionPostCommand(IDC_UPDN_NOTESCMD);
        }

        CUpdateState state;
        UpdateCheck_LoadState(&state);
        CheckDlgButton(HWindow, IDC_UPDN_ATSTARTUP, state.CheckAtStartup ? BST_CHECKED : BST_UNCHECKED);

        CCommonDialog::DialogProc(uMsg, wParam, lParam); // centres the window on its owner
        // TRUE lets the dialog manager give the keyboard focus to the first control - and with it
        // the activation, even for a window that is not visible yet. A notification that arrives
        // while the user works must take neither (contracts/ui.md, "Showing").
        return Activate;
    }

    case WM_ACTIVATE:
    {
        if (LOWORD(wParam) != WA_INACTIVE) // the option may have been changed in the configuration meanwhile
        {
            CUpdateState state;
            UpdateCheck_LoadState(&state);
            CheckDlgButton(HWindow, IDC_UPDN_ATSTARTUP, state.CheckAtStartup ? BST_CHECKED : BST_UNCHECKED);
        }
        break;
    }

    case WM_THEMECHANGED:
    case WM_SYSCOLORCHANGE:
    {
        PaintHeader(); // the band follows the application theme
        InvalidateRect(HWindow, NULL, TRUE);
        break;
    }

    case WM_ERASEBKGND:
    {
        HDC hDC = (HDC)wParam;
        RECT client;
        GetClientRect(HWindow, &client);
        RECT body = client;
        body.top = BandBottom;
        FillRect(hDC, &body, ThemeSysColorBrush(COLOR_BTNFACE));
        if (HeaderBitmap != NULL)
            BitBlt(hDC, 0, 0, client.right, BandBottom, HeaderBitmap->HMemDC, 0, 0, SRCCOPY);
        else
        {
            RECT band = client;
            band.bottom = BandBottom;
            FillRect(hDC, &band, ThemeSysColorBrush(COLOR_BTNFACE));
        }
        SetWindowLongPtr(HWindow, DWLP_MSGRESULT, TRUE);
        return TRUE;
    }

    case WM_CTLCOLORSTATIC:
    {
        HDC hDC = (HDC)wParam;
        BOOL dark = IsDarkThemeActive();
        int id = GetWindowLong((HWND)lParam, GWL_ID);
        if (id == IDC_UPDN_TITLE) // stands on the painted band
        {
            SetTextColor(hDC, dark ? TC_COLOR_TEXT_DARKBG : TC_COLOR_TEXT_LIGHTBG);
            SetBkMode(hDC, TRANSPARENT);
            return (INT_PTR)GetStockObject(NULL_BRUSH);
        }
        COLORREF text = ThemeSysColor(COLOR_BTNTEXT);
        switch (id)
        {
        case IDC_UPDN_NEWVER: // the dominant element
            text = dark ? TC_COLOR_ORANGE_DARKBG : TC_COLOR_ORANGE_LIGHTBG;
            break;
        case IDC_UPDN_INSTVER:
        case IDC_UPDN_INSTLABEL:
        case IDC_UPDN_NEWLABEL:
            text = ThemeSysColor(COLOR_GRAYTEXT);
            break;
        }
        SetTextColor(hDC, text);
        SetBkColor(hDC, ThemeSysColor(COLOR_BTNFACE));
        return (INT_PTR)ThemeSysColorBrush(COLOR_BTNFACE);
    }

    case WM_DRAWITEM:
    {
        DRAWITEMSTRUCT* dis = (DRAWITEMSTRUCT*)lParam;
        if (dis != NULL && dis->CtlID == IDC_UPDN_ARROW)
        {
            DrawArrow(dis);
            SetWindowLongPtr(HWindow, DWLP_MSGRESULT, TRUE);
            return TRUE;
        }
        break;
    }

    case WM_COMMAND:
    {
        switch (LOWORD(wParam))
        {
        case IDOK: // Download: the installer of the new version, in the default browser
        {
            char url[SALUPD_URL_MAX];
            if (SalUpdInstallerUrl(Release.Version, url, sizeof(url)) && UpdateCheck_OpenUrl(HWindow, url))
                DestroyWindow(HWindow);
            return TRUE; // on failure the window stays (the user was told and offered the address)
        }

        case IDC_UPDN_NOTESCMD: // the link: the release notes of that version
        {
            char url[SALUPD_URL_MAX];
            if (SalUpdReleaseNotesUrl(Release.Version, url, sizeof(url)))
                UpdateCheck_OpenUrl(HWindow, url);
            return TRUE;
        }

        case IDC_UPDN_SKIP: // this version is not offered at start-up any more; a newer one is
        {
            UpdateCheck_SetSkippedVersion(Release.Version);
            DestroyWindow(HWindow);
            return TRUE;
        }

        case IDC_UPDN_ATSTARTUP: // the same setting as Configuration > General, written at once
        {
            if (HIWORD(wParam) == BN_CLICKED)
                UpdateCheck_SetCheckAtStartup(IsDlgButtonChecked(HWindow, IDC_UPDN_ATSTARTUP) == BST_CHECKED);
            return TRUE;
        }

            // IDCANCEL (Remind Me Later, Esc, the close button): CDialog destroys the window
        }
        break;
    }

    case WM_DESTROY:
    {
        RemovePropW(HWindow, UPDATENOTICE_WINDOW_PROP);
        RemovePropA(HWindow, SALCLOSEAPP_WINDOW_PROP);
        if (UpdateNoticeWindow == HWindow)
            UpdateNoticeWindow = NULL;
        break;
    }
    }
    return CCommonDialog::DialogProc(uMsg, wParam, lParam);
}

HWND UpdateNotice_GetWindow()
{
    return UpdateNoticeWindow;
}

static BOOL CALLBACK UpdateNoticeEnumProc(HWND hwnd, LPARAM lParam)
{
    if (GetPropW(hwnd, UPDATENOTICE_WINDOW_PROP) != NULL)
    {
        *(HWND*)lParam = hwnd;
        return FALSE;
    }
    return TRUE;
}

HWND UpdateNotice_FindAny()
{
    if (UpdateNoticeWindow != NULL && IsWindow(UpdateNoticeWindow))
        return UpdateNoticeWindow;
    HWND found = NULL;
    EnumWindows(UpdateNoticeEnumProc, (LPARAM)&found);
    return found;
}

void UpdateNotice_Show(HWND mainWindow, const CSalUpdRelease& release, BOOL activate)
{
    CALL_STACK_MESSAGE2("UpdateNotice_Show(, , %d)", activate);
    // our own window announcing another version than the one just found is replaced (a check on
    // demand found a newer release while the notification was open)
    if (UpdateNoticeWindow != NULL && IsWindow(UpdateNoticeWindow) &&
        SalUpdVersionCompare(UpdateNoticeVersion, release.Version) != 0)
        UpdateNotice_Close();

    HWND existing = UpdateNotice_FindAny();
    if (existing != NULL) // one notification per user
    {
        if (activate)
        {
            if (IsIconic(existing))
                ShowWindow(existing, SW_RESTORE);
            SetForegroundWindow(existing);
        }
        return;
    }

    CUpdateNoticeDialog* dlg = new CUpdateNoticeDialog(mainWindow, release, activate);
    if (dlg == NULL)
        return;
    UpdateNoticeAttached = FALSE;
    HWND hDlg = dlg->Create(); // the object is released when the window is destroyed
    if (hDlg == NULL)
    {
        TRACE_E("UpdateNotice_Show(): unable to create the notification window.");
        if (!UpdateNoticeAttached)
            delete dlg; // the window was never created, so nobody else releases the object
        return;
    }
    ShowWindow(hDlg, activate ? SW_SHOW : SW_SHOWNOACTIVATE);
    if (activate)
        SetForegroundWindow(hDlg);
}

void UpdateNotice_Close()
{
    if (UpdateNoticeWindow != NULL && IsWindow(UpdateNoticeWindow))
        DestroyWindow(UpdateNoticeWindow);
    UpdateNoticeWindow = NULL;
}

//
// ****************************************************************************
// CUpdateCheckingDialog - shown while a check the user asked for takes longer
// than a moment; Cancel aborts the request
//

class CUpdateCheckingDialog : public CCommonDialog
{
public:
    CUpdateCheckingDialog(HWND parent, DWORD startTick)
        : CCommonDialog(HLanguage, IDD_UPDATECHECKING, parent)
    {
        StartTick = startTick;
        GaveUp = FALSE;
    }

protected:
    virtual INT_PTR DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    DWORD StartTick;
    BOOL GaveUp;
};

INT_PTR
CUpdateCheckingDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
    case WM_INITDIALOG:
    {
        SetTimer(HWindow, IDT_UPDATECHECKING, 50, NULL);
        break;
    }

    case WM_TIMER:
    {
        if (wParam == IDT_UPDATECHECKING)
        {
            if (!UpdateCheck_IsRunning())
            {
                KillTimer(HWindow, IDT_UPDATECHECKING);
                EndDialog(HWindow, IDOK);
            }
            else if (!GaveUp && GetTickCount() - StartTick >= UPDATEMANUAL_GIVEUP_MS)
            {
                GaveUp = TRUE; // the answer of a manual check is bounded (SC-006)
                UpdateCheck_Cancel(TRUE);
            }
            return TRUE;
        }
        break;
    }

    case WM_COMMAND:
    {
        if (LOWORD(wParam) == IDCANCEL)
        {
            UpdateCheck_Cancel(FALSE); // returns at once; the check is no longer "running"
            KillTimer(HWindow, IDT_UPDATECHECKING);
            EndDialog(HWindow, IDCANCEL);
            return TRUE;
        }
        break;
    }

    case WM_DESTROY:
    {
        KillTimer(HWindow, IDT_UPDATECHECKING);
        break;
    }
    }
    return CCommonDialog::DialogProc(uMsg, wParam, lParam);
}

BOOL UpdateCheck_ManualUIWaiting()
{
    return UpdateManualWaiting;
}

static void UpdateCheck_ShowAnswer(HWND parent, int textID, UINT icon, const char* arg)
{
    char text[1000];
    if (arg != NULL)
        _snprintf_s(text, _TRUNCATE, LoadStrU8(textID), arg);
    else
        lstrcpyn(text, LoadStrU8(textID), _countof(text));
    char title[200];
    lstrcpyn(title, LoadStrU8(IDS_UPDATE_TITLE), _countof(title));
    SalMessageBox(parent, text, title, MB_OK | icon);
}

BOOL UpdateCheck_RunManualUI(HWND parent, CUpdateCheckDone* done)
{
    CALL_STACK_MESSAGE1("UpdateCheck_RunManualUI()");
    if (UpdateManualWaiting)
        return FALSE; // already asked (the command came twice)

    HWND mainWnd = MainWindow != NULL ? MainWindow->HWindow : parent;
    DWORD startTick = GetTickCount();
    if (!UpdateCheck_StartManual(mainWnd))
    {
        UpdateCheck_ShowAnswer(parent, IDS_UPDATE_ERR_START, MB_ICONEXCLAMATION, NULL);
        return FALSE;
    }

    UpdateManualWaiting = TRUE;
    // most answers arrive within a moment: no dialog flashes for them
    while (UpdateCheck_IsRunning() && GetTickCount() - startTick < UPDATEMANUAL_QUIET_MS)
        Sleep(15);
    if (UpdateCheck_IsRunning())
        CUpdateCheckingDialog(parent, startTick).Execute();
    // the result is announced in the same step in which the check stops being "running"
    BOOL has = UpdateCheck_TakeResult(done);
    UpdateManualWaiting = FALSE;
    if (!has)
        return FALSE; // taken elsewhere, or the program is closing

    // the About dialog (when it is not the caller) shows the new state too
    if (UpdateAboutWindow != NULL && UpdateAboutWindow != parent)
        PostMessage(UpdateAboutWindow, WM_USER_UPDATECHECK_DONE, 0, 0);

    switch (done->Result)
    {
    case surNewer:
        return TRUE;

    case surUpToDate:
    {
        // the installed version, printed from numbers
        char version[SALUPD_VERSION_TEXT_MAX];
        CSalUpdVersion installed;
        UpdateCheck_GetInstalledVersion(&installed);
        SalUpdFormatVersion(installed, version, sizeof(version));
        UpdateCheck_ShowAnswer(parent, IDS_UPDATE_UPTODATE, MB_ICONINFORMATION, version);
        break;
    }

    case surUnreachable:
        UpdateCheck_ShowAnswer(parent, IDS_UPDATE_ERR_UNREACHABLE, MB_ICONEXCLAMATION, NULL);
        break;

    case surRefused:
        UpdateCheck_ShowAnswer(parent, IDS_UPDATE_ERR_REFUSED, MB_ICONEXCLAMATION, NULL);
        break;

    case surUnexpected:
        UpdateCheck_ShowAnswer(parent, IDS_UPDATE_ERR_UNEXPECTED, MB_ICONEXCLAMATION, NULL);
        break;

    case surCancelled:
        break; // the user cancelled: nothing is shown
    }
    return FALSE;
}
