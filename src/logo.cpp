// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later
// CommentsTranslationProject: TRANSLATED

#include "precomp.h"
#include "mainwnd.h"
#include "plugins.h"
#include "fileswnd.h"
#include "cfgdlg.h"
#include "dialogs.h"
#include "gui.h"
#include "md5.h"

#include <uxtheme.h>
#include <vssym32.h>
#include <ppl.h>

#include "svg.h"
#include "pngimage.h"
#include "themes.h"

#include "versinfo.rh2"
#include "brand.h"    // the brand palette and TCPaintBrandHeader
#include "updcheck.h" // feature 123: the About dialog shows what is known about a newer version
#include "upddlg.h"

// draws the "Tandem Commander" wordmark into 'r' (left-aligned, vertically centered);
// shrinks the font until both parts fit the rect width
static void TCDrawWordmark(HDC hDC, const RECT* r, COLORREF tandemClr, COLORREF commanderClr)
{
    const char* part1 = "Tandem ";
    const char* part2 = "Commander";
    int rectW = r->right - r->left;
    int rectH = r->bottom - r->top;

    LOGFONT lf;
    memset(&lf, 0, sizeof(lf));
    lf.lfWeight = FW_BOLD;
    lf.lfCharSet = DEFAULT_CHARSET;
    lf.lfQuality = CLEARTYPE_QUALITY;
    lf.lfPitchAndFamily = VARIABLE_PITCH | FF_SWISS;
    strcpy(lf.lfFaceName, "Segoe UI");

    int oldBkMode = SetBkMode(hDC, TRANSPARENT);
    SIZE s1, s2;
    HFONT hFont = NULL;
    HFONT hOldFont = NULL;
    int height = MulDiv(rectH, 55, 100);
    for (;;)
    {
        lf.lfHeight = -height;
        hFont = HANDLES(CreateFontIndirect(&lf));
        HFONT hPrev = (HFONT)SelectObject(hDC, hFont);
        if (hOldFont == NULL)
            hOldFont = hPrev;
        GetTextExtentPoint32(hDC, part1, (int)strlen(part1), &s1);
        GetTextExtentPoint32(hDC, part2, (int)strlen(part2), &s2);
        if (s1.cx + s2.cx <= rectW || height <= 10)
            break;
        SelectObject(hDC, hOldFont);
        HANDLES(DeleteObject(hFont));
        height = MulDiv(height, 9, 10);
    }

    int y = r->top + (rectH - s1.cy) / 2;
    COLORREF oldClr = SetTextColor(hDC, tandemClr);
    TextOut(hDC, r->left, y, part1, (int)strlen(part1));
    SetTextColor(hDC, commanderClr);
    TextOut(hDC, r->left + s1.cx, y, part2, (int)strlen(part2));

    SetTextColor(hDC, oldClr);
    SetBkMode(hDC, oldBkMode);
    SelectObject(hDC, hOldFont);
    HANDLES(DeleteObject(hFont));
}

// feature 123: the header band of the new-version notification - the same wordmark, artwork
// and accent line as the About dialog, laid out for a band instead of a whole window
int TCPaintBrandHeader(HDC hDC, const RECT* band, const RECT* wordmarkR, const RECT* logoR, int accentY)
{
    BOOL dark = IsDarkThemeActive();
    SetBkColor(hDC, dark ? TC_COLOR_NAVY : RGB(255, 255, 255));
    ExtTextOut(hDC, 0, 0, ETO_OPAQUE, band, "", 0, NULL);

    CSVGSprite svgGrad;
    CPngImage pngLogo; // hand-swappable PNG artwork (feature 035, src/res/logo.png)
    svgGrad.Load(IDB_ABOUT_GRAD, band->right - band->left, -1, SVGSTATE_ORIGINAL);
    pngLogo.Load(IDB_LOGO_IMAGE, logoR->right - logoR->left, logoR->bottom - logoR->top);

    SIZE gradSize, logoSize;
    svgGrad.GetSize(&gradSize);
    pngLogo.GetSize(&logoSize);
    int accentH = max(2, (int)gradSize.cy);
    svgGrad.AlphaBlend(hDC, band->left, accentY, gradSize.cx, accentH, SVGSTATE_ORIGINAL);
    pngLogo.AlphaBlend(hDC, logoR->left + (logoR->right - logoR->left - logoSize.cx) / 2,
                       logoR->top + (logoR->bottom - logoR->top - logoSize.cy) / 2, logoSize.cx, logoSize.cy);
    TCDrawWordmark(hDC, wordmarkR,
                   dark ? TC_COLOR_TEXT_DARKBG : TC_COLOR_TEXT_LIGHTBG,
                   dark ? TC_COLOR_ORANGE_DARKBG : TC_COLOR_ORANGE_LIGHTBG);
    return accentY + accentH;
}

void GetDlgItemRectAndDestroy(HWND hWindow, int resID, RECT* r)
{
    HWND hItem = GetDlgItem(hWindow, resID);
    if (hItem == NULL)
    {
        r->left = r->top = r->right = r->bottom = 0;
        return;
    }
    GetWindowRect(hItem, r);
    MapWindowPoints(NULL, hWindow, (POINT*)r, 2);
    DestroyWindow(hItem);
}

//*****************************************************************************
//
// Splash Screen
//

#define SPLASH_WIDTH_DLGUNITS 270
#define SPLASH_HEIGHT_DLGUNITS 72

CSplashScreen::CSplashScreen()
    : CDialog(HInstance, IDD_SPLASH, NULL, ooStatic)
{
    Bitmap = NULL;
    OriginalBitmap = NULL;
    HNormalFont = NULL;
    HBoldFont = NULL;
    GradientY = 0;
    Width = 0;
    Height = 0;

    // create a font
    LOGFONT lf;
    //  GetSystemGUIFont(&lf);
    //  lf.lfWeight = FW_NORMAL;

    HDC hDC2 = HANDLES(GetDC(NULL));
    lf.lfHeight = -MulDiv(8, GetDeviceCaps(hDC2, LOGPIXELSY), 72);
    HANDLES(ReleaseDC(NULL, hDC2));
    lf.lfWidth = 0;
    lf.lfEscapement = 0;
    lf.lfOrientation = 0;
    lf.lfWeight = FW_NORMAL;
    lf.lfItalic = 0;
    lf.lfUnderline = 0;
    lf.lfStrikeOut = 0;
    lf.lfCharSet = DEFAULT_CHARSET;
    lf.lfOutPrecision = OUT_DEFAULT_PRECIS;
    lf.lfClipPrecision = CLIP_DEFAULT_PRECIS;
    lf.lfQuality = DEFAULT_QUALITY;
    lf.lfPitchAndFamily = VARIABLE_PITCH | FF_SWISS;
    strcpy(lf.lfFaceName, "MS Shell Dlg 2");

    HNormalFont = HANDLES(CreateFontIndirect(&lf));
    // create the bold variant
    lf.lfWeight = FW_BOLD;
    HBoldFont = HANDLES(CreateFontIndirect(&lf));
}

CSplashScreen::~CSplashScreen()
{
    // by this time the bitmap should be destroyed, but do it again just in case
    DestroyBitmap();
    if (HNormalFont != NULL)
        HANDLES(DeleteObject(HNormalFont));
    if (HBoldFont != NULL)
        HANDLES(DeleteObject(HBoldFont));
}

BOOL CSplashScreen::PaintText(const char* text, int x, int y, BOOL bold, COLORREF clr)
{
    HDC hDC = NULL;
    if (Bitmap != NULL)
        hDC = Bitmap->HMemDC;
    if (hDC != NULL)
    {
        RECT r;
        r.left = x;
        r.top = y;
        r.right = x + Width;
        r.bottom = y + Height;
        int oldBkMode = SetBkMode(hDC, TRANSPARENT);
        COLORREF oldTextColor = SetTextColor(hDC, clr);
        HFONT hOldFont = (HFONT)SelectObject(hDC, bold ? HBoldFont : HNormalFont);
        DrawText(hDC, text, -1, &r, DT_SINGLELINE | DT_NOPREFIX | DT_NOCLIP);
        SelectObject(hDC, hOldFont);
        SetTextColor(hDC, oldTextColor);
        SetBkMode(hDC, oldBkMode);
    }
    return TRUE;
}

BOOL CSplashScreen::PrepareBitmap()
{
    Bitmap = new CBitmap();
    OriginalBitmap = new CBitmap();
    if (Bitmap != NULL && OriginalBitmap != NULL)
    {
        HDC hDC = HANDLES(GetDC(NULL));
        if (!Bitmap->CreateBmp(hDC, Width, Height))
        {
            delete Bitmap;
            Bitmap = NULL;
        }
        if (!OriginalBitmap->CreateBmp(hDC, Width, Height))
        {
            delete OriginalBitmap;
            OriginalBitmap = NULL;
        }
        HANDLES(ReleaseDC(NULL, hDC));
    }
    else
        return FALSE;

    HDC hDC = Bitmap->HMemDC;

    RECT r;
    r.left = 0;
    r.top = 0;
    r.right = Width;
    r.bottom = Height;

    // the splash always uses the brand dark look (theme configuration may not be
    // loaded yet this early during startup)
    SetBkColor(hDC, TC_COLOR_NAVY);
    ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &r, "", 0, NULL);

    CSVGSprite svgGrad;
    CPngImage pngLogo; // hand-swappable PNG artwork (feature 035, src/res/logo.png)
    concurrency::parallel_invoke(
        [&]
        { svgGrad.Load(IDB_LOGO_GRAD, Width, -1, SVGSTATE_ORIGINAL); },
        [&]
        // the artwork sits above the accent line so the texts below stay clear of it
        { pngLogo.Load(IDB_LOGO_IMAGE, -1, GradientY - 12); });

    SIZE gradSize, logoSize;
    svgGrad.GetSize(&gradSize);
    pngLogo.GetSize(&logoSize);

    // thin brand accent line (blue -> orange) instead of the old full gradient area
    svgGrad.AlphaBlend(hDC, 0, GradientY, gradSize.cx, max(2, gradSize.cy), SVGSTATE_ORIGINAL);
    pngLogo.AlphaBlend(hDC, Width - logoSize.cx - 8, 6, logoSize.cx, logoSize.cy);

    // product wordmark drawn with GDI (no font dependency, see TCDrawWordmark)
    TCDrawWordmark(hDC, &OpenSalR, TC_COLOR_TEXT_DARKBG, TC_COLOR_ORANGE_DARKBG);

    // fixed texts
    PaintText(SALAMANDER_TEXT_VERSION,
              VersionR.left,
              VersionR.top,
              FALSE, TC_COLOR_MUTED_DARKBG);

    // the copyright has two authorship parts; a single line does not fit the
    // splash width, so each part gets its own line (feature 035). Order is
    // fixed: the current product first, the predecessor below it -- the About
    // dialog shows the same two lines in the same order (feature 040)
    PaintText(VERSINFO_COPYRIGHT_TANDEM,
              CopyrightR.left,
              CopyrightR.top,
              TRUE, TC_COLOR_TEXT_DARKBG);

    PaintText(VERSINFO_COPYRIGHT_OPENSAL,
              Copyright2R.left,
              Copyright2R.top,
              TRUE, TC_COLOR_TEXT_DARKBG);

    // backup of the bitmap without text
    BitBlt(OriginalBitmap->HMemDC, 0, 0, Width, Height, Bitmap->HMemDC, 0, 0, SRCCOPY);

    return TRUE;
}

void CSplashScreen::SetText(const char* text)
{
    if (Bitmap != NULL && OriginalBitmap != NULL)
    {
        // restore the background
        BitBlt(Bitmap->HMemDC, StatusR.left, StatusR.top, StatusR.right - StatusR.left, StatusR.bottom - StatusR.top, OriginalBitmap->HMemDC, StatusR.left, StatusR.top, SRCCOPY);
        PaintText(text,
                  StatusR.left, StatusR.top,
                  FALSE, RGB(255, 255, 255));

        // if visible, update the display with the change
        if (HWindow != NULL)
        {
            HDC hDC = HANDLES(GetDC(HWindow));
            BitBlt(hDC, StatusR.left, StatusR.top, StatusR.right - StatusR.left, StatusR.bottom - StatusR.top, Bitmap->HMemDC, StatusR.left, StatusR.top, SRCCOPY);
            HANDLES(ReleaseDC(HWindow, hDC));
        }
    }
}

void CSplashScreen::DestroyBitmap()
{
    if (Bitmap != NULL)
    {
        delete Bitmap;
        Bitmap = NULL;
    }
    if (OriginalBitmap != NULL)
    {
        delete OriginalBitmap;
        OriginalBitmap = NULL;
    }
}

INT_PTR
CSplashScreen::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CSplashScreen::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg, wParam, lParam);
    switch (uMsg)
    {
    case WM_INITDIALOG:
    {
        RECT r;
        GetClientRect(HWindow, &r);
        Width = r.right - r.left;
        Height = r.bottom - r.top;

        GetDlgItemRectAndDestroy(HWindow, IDC_SPLASH_OPENSAL, &OpenSalR);
        GetDlgItemRectAndDestroy(HWindow, IDC_SPLASH_VERSION, &VersionR);
        GetDlgItemRectAndDestroy(HWindow, IDC_SPLASH_COPYRIGHT, &CopyrightR);
        GetDlgItemRectAndDestroy(HWindow, IDC_SPLASH_COPYRIGHT2, &Copyright2R);
        GetDlgItemRectAndDestroy(HWindow, IDC_SPLASH_STATUS, &StatusR);

        GradientY = VersionR.bottom + 5;

        TRACE_I("!!!!!!!!!!!!! BEG ");
        PrepareBitmap();
        TRACE_I("!!!!!!!!!!!!! END ");
        break;
    }

    case WM_PAINT:
    {
        PAINTSTRUCT ps;
        HANDLES(BeginPaint(HWindow, &ps));
        BitBlt(ps.hdc, 0, 0, Width, Height, Bitmap->HMemDC, 0, 0, SRCCOPY);
        HANDLES(EndPaint(HWindow, &ps));
        return FALSE;
    }

    case WM_ERASEBKGND:
    {
        return TRUE;
    }
    }

    return CDialog::DialogProc(uMsg, wParam, lParam);
}

CSplashScreen SplashScreen;

BOOL SplashScreenOpen()
{
    if (SplashScreen.HWindow != NULL)
    {
        TRACE_E("SplashScreenOpen(): splash screen already exists!");
        return FALSE;
    }

    SplashScreen.Create();

    if (SplashScreen.HWindow != NULL)
    {
        MultiMonCenterWindow(SplashScreen.HWindow, NULL, FALSE);
        ShowWindow(SplashScreen.HWindow, SW_SHOWNOACTIVATE);
        UpdateWindow(SplashScreen.HWindow);
        return TRUE;
    }
    else
    {
        SplashScreen.DestroyBitmap();
        return FALSE;
    }
}

void SplashScreenCloseIfExist()
{
    if (SplashScreen.HWindow != NULL)
    {
        DestroyWindow(SplashScreen.HWindow);
        SplashScreen.DestroyBitmap();
    }
}

BOOL ExistSplashScreen()
{
    return (SplashScreen.HWindow != NULL);
}

void IfExistSetSplashScreenText(const char* text)
{
    if (SplashScreen.HWindow != NULL)
        SplashScreen.SetText(text);
}

HWND GetSplashScreenHandle()
{
    return SplashScreen.HWindow;
}

//
// ****************************************************************************
// CAboutDialog
//

CAboutDialog::CAboutDialog(HWND parent)
    : CCommonDialog(HLanguage, IDD_ABOUT, parent)
{
    // must match the dialog background painted in AboutAndEvalDlgCreateBkgnd
    HGradientBkBrush = HANDLES(CreateSolidBrush(IsDarkThemeActive() ? TC_COLOR_NAVY : RGB(255, 255, 255)));
    BackgroundBitmap = NULL;
    UpdateLink = NULL;
}

// feature 123: the line under the version - what the program last learned about newer
// versions, from the stored state alone. Opening the dialog sends nothing; the two links act
// only when the user chooses them.
void CAboutDialog::RefreshUpdateLine()
{
    CUpdateState state;
    CSalUpdKnownState known = UpdateCheck_GetKnownState(&state);
    WCHAR text[300];
    text[0] = 0;
    const char* linkText = NULL;
    WORD linkCommand = 0;
    switch (known)
    {
    case suksNewer:
    {
        WCHAR version[SALUPD_VERSION_TEXT_MAX];
        char versionA[SALUPD_VERSION_TEXT_MAX];
        SalUpdFormatVersion(state.Latest, versionA, sizeof(versionA));
        int i = 0;
        for (; versionA[i] != 0; i++)
            version[i] = versionA[i];
        version[i] = 0;
        _snwprintf_s(text, _TRUNCATE, LoadStrW(IDS_UPDATE_ABOUT_NEWER), version);
        linkText = LoadStrU8(IDS_UPDATE_DOWNLOADLINK);
        linkCommand = IDC_ABOUT_UPDATECMD; // download the installer of that version
        break;
    }

    case suksUpToDate:
    {
        WCHAR date[100];
        if (state.HasLastSuccess && UpdateCheck_FormatDate(state.LastSuccess, date, _countof(date)))
            _snwprintf_s(text, _TRUNCATE, LoadStrW(IDS_UPDATE_ABOUT_LATEST), date);
        else
            lstrcpynW(text, LoadStrW(IDS_UPDATE_ABOUT_LATEST_NODATE), _countof(text));
        break;
    }

    default: // suksNotChecked
    {
        lstrcpynW(text, LoadStrW(IDS_UPDATE_ABOUT_NOTCHECKED), _countof(text));
        linkText = LoadStrU8(IDS_UPDATE_CHECKNOWLINK);
        linkCommand = CM_HELP_CHECKVERSION;
        break;
    }
    }

    HWND hText = GetDlgItem(HWindow, IDC_ABOUT_UPDATE);
    HWND hLink = GetDlgItem(HWindow, IDC_ABOUT_UPDATELINK);
    if (hText == NULL || hLink == NULL)
        return;
    SetWindowTextW(hText, text);

    // the link stands right behind the text: both are measured with the dialog font
    RECT textR;
    GetWindowRect(hText, &textR);
    MapWindowPoints(NULL, HWindow, (POINT*)&textR, 2);
    RECT clientR;
    GetClientRect(HWindow, &clientR);
    HFONT hFont = (HFONT)SendMessage(hText, WM_GETFONT, 0, 0);
    HDC hDC = HANDLES(GetDC(HWindow));
    HFONT hOldFont = (HFONT)SelectObject(hDC, hFont);
    SIZE textSize = {0, 0};
    GetTextExtentPoint32W(hDC, text, (int)wcslen(text), &textSize);
    SIZE spaceSize = {0, 0};
    GetTextExtentPoint32W(hDC, L" ", 1, &spaceSize);
    SIZE linkSize = {0, 0};
    WCHAR* linkW = linkText != NULL ? SalU8ToWAlloc(linkText, -1) : NULL;
    if (linkW != NULL)
        GetTextExtentPoint32W(hDC, linkW, (int)wcslen(linkW), &linkSize);
    SelectObject(hDC, hOldFont);
    HANDLES(ReleaseDC(HWindow, hDC));
    if (linkW != NULL)
        free(linkW);

    int textW = textSize.cx + 2;
    SetWindowPos(hText, NULL, 0, 0, textW, textR.bottom - textR.top, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    if (linkText != NULL && UpdateLink != NULL)
    {
        int linkX = textR.left + textW + spaceSize.cx;
        int linkW2 = min((int)linkSize.cx + 6, (int)(clientR.right - linkX - 4));
        SetWindowPos(hLink, NULL, linkX, textR.top, max(linkW2, 10), textR.bottom - textR.top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
        UpdateLink->SetText(linkText);
        UpdateLink->SetActionPostCommand(linkCommand);
        ShowWindow(hLink, SW_SHOWNA);
    }
    else
        ShowWindow(hLink, SW_HIDE);
    InvalidateRect(HWindow, NULL, TRUE);
}

CAboutDialog::~CAboutDialog()
{
    if (BackgroundBitmap != NULL)
        delete BackgroundBitmap;
    HANDLES(DeleteObject(HGradientBkBrush));
}

HDWP OffsetControl(HWND hWindow, HDWP hdwp, int id, int yOffset)
{
    HWND hCtrl = GetDlgItem(hWindow, id);
    RECT r;
    GetWindowRect(hCtrl, &r);
    ScreenToClient(hWindow, (LPPOINT)&r);

    hdwp = HANDLES(DeferWindowPos(hdwp, hCtrl, NULL, r.left, r.top + yOffset, 0, 0, SWP_NOSIZE | SWP_NOZORDER));
    return hdwp;
}

CBitmap*
AboutAndEvalDlgCreateBkgnd(HWND hWindow)
{
    RECT opensalR;
    RECT logoR;
    RECT gradR;
    GetDlgItemRectAndDestroy(hWindow, IDC_ABOUT_OPENSAL, &opensalR);
    GetDlgItemRectAndDestroy(hWindow, IDC_ABOUT_LOGO, &logoR);
    GetDlgItemRectAndDestroy(hWindow, IDC_ABOUT_BOTTOM, &gradR);

    RECT r;
    GetClientRect(hWindow, &r);

    CBitmap* bitmap = new CBitmap();
    HDC hDC = HANDLES(GetDC(NULL));
    if (!bitmap->CreateBmp(hDC, r.right - r.left, r.bottom - r.top))
    {
        delete bitmap;
        bitmap = NULL;
    }
    HANDLES(ReleaseDC(NULL, hDC));
    if (bitmap == NULL)
        return NULL;

    hDC = bitmap->HMemDC;

    // theme-aware background (feature 032: About follows the application theme)
    BOOL dark = IsDarkThemeActive();
    SetBkColor(hDC, dark ? TC_COLOR_NAVY : RGB(255, 255, 255));
    ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &r, "", 0, NULL);

    CSVGSprite svgGrad;
    CPngImage pngLogo; // hand-swappable PNG artwork (feature 035, src/res/logo.png)
    concurrency::parallel_invoke(
        [&]
        { svgGrad.Load(IDB_ABOUT_GRAD, r.right - r.left, -1, SVGSTATE_ORIGINAL); },
        [&]
        { pngLogo.Load(IDB_LOGO_IMAGE, logoR.right - logoR.left, logoR.bottom - logoR.top); });

    SIZE gradSize, logoSize;
    svgGrad.GetSize(&gradSize);
    pngLogo.GetSize(&logoSize);

    // thin brand accent line (blue -> orange) at the position of the old gradient area
    svgGrad.AlphaBlend(hDC, 0, gradR.top, gradSize.cx, max(2, gradSize.cy), SVGSTATE_ORIGINAL);
    pngLogo.AlphaBlend(hDC, r.right - r.left - logoSize.cx, 0, logoSize.cx, logoSize.cy);

    // product wordmark drawn with GDI (no font dependency)
    TCDrawWordmark(hDC, &opensalR,
                   dark ? TC_COLOR_TEXT_DARKBG : TC_COLOR_TEXT_LIGHTBG,
                   dark ? TC_COLOR_ORANGE_DARKBG : TC_COLOR_ORANGE_LIGHTBG);

    return bitmap;
}

void AboutAndEvalDlgPaintBkgnd(HWND hWindow, HDC hDC, CBitmap* bitmap)
{
    BitBlt(hDC, 0, 0, bitmap->GetWidth(), bitmap->GetHeight(), bitmap->HMemDC, 0, 0, SRCCOPY);
}

INT_PTR
CAboutDialog::DialogProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    CALL_STACK_MESSAGE4("CAboutDialog::DialogProc(0x%X, 0x%IX, 0x%IX)", uMsg, wParam, lParam);

    switch (uMsg)
    {
    case WM_INITDIALOG:
    {
        CHyperLink* hl;

        SetDlgItemText(HWindow, IDS_ABOUT_SALAMANDER, SALAMANDER_TEXT_VERSION);
        new CStaticText(HWindow, IDS_ABOUT_SALAMANDER, STF_BOLD);
        //      new CStaticText(HWindow, IDS_ABOUT_FIRM, STF_BOLD);

        hl = new CHyperLink(HWindow, IDC_ABOUT_WWW);
        if (hl != NULL)
        {
            const char* url = "https://tandemcommander.org";
            SetDlgItemText(HWindow, IDC_ABOUT_WWW, url + 8);
            hl->SetActionOpen(url);
        }

        // The copyright notice is a legal attribution, not translatable UI text:
        // both controls carry an empty caption in lang.rc (and therefore in every
        // .slg) and are filled here from versinfo.rh2, so the notice is always
        // English no matter which language module is loaded. Machine translation
        // had rewritten the predecessor's attribution and the year in all eleven
        // languages -- that is what this prevents (feature 040).
        SetDlgItemText(HWindow, IDC_STATIC_1, VERSINFO_COPYRIGHT_TANDEM);
        SetDlgItemText(HWindow, IDC_STATIC_2, VERSINFO_COPYRIGHT_OPENSAL);

        // feature 123: what is known about a newer version; a check that finishes while the
        // dialog is open refreshes the line (WM_USER_UPDATECHECK_DONE from the main window)
        UpdateLink = new CUpdateLink(HWindow, IDC_ABOUT_UPDATELINK); // takes Enter itself
        RefreshUpdateLine();
        UpdateAboutWindow = HWindow;

        BackgroundBitmap = AboutAndEvalDlgCreateBkgnd(HWindow);
        break;
    }

    case WM_CTLCOLORSTATIC:
    {
        HDC hdcStatic = (HDC)wParam;
        HWND hwndStatic = (HWND)lParam;
        int resID = GetWindowLong(hwndStatic, GWL_ID);
        BOOL dark = IsDarkThemeActive();
        COLORREF textClr = dark ? TC_COLOR_TEXT_DARKBG : RGB(70, 70, 70);
        switch (resID)
        {
        case IDC_STATIC_6:
        case IDC_STATIC_7:
        case IDC_STATIC_8:
            textClr = dark ? TC_COLOR_MUTED_DARKBG : RGB(128, 128, 128);
            break;
        }
        SetTextColor(hdcStatic, textClr);
        SetBkColor(hdcStatic, dark ? TC_COLOR_NAVY : RGB(255, 255, 255));
        return (BOOL)(UINT_PTR)GetStockObject(NULL_BRUSH);
    }

    case WM_CTLCOLORBTN:
    {
        if (IsAppThemed())
        {
            // without this workaround there's a gray frame around the OK button
            if (WindowsVistaAndLater)
                return (BOOL)(UINT_PTR)HGradientBkBrush;
            else
                return (BOOL)(UINT_PTR)GetStockObject(NULL_BRUSH); // under XP this still worked fine
        }
        break;
    }

    case WM_ERASEBKGND:
    {
        HDC hDC = (HDC)wParam;
        AboutAndEvalDlgPaintBkgnd(HWindow, hDC, BackgroundBitmap);
        return TRUE;
    }

    case WM_NCHITTEST:
    {
        SetWindowLongPtr(HWindow, DWLP_MSGRESULT, HTCAPTION);
        return HTCAPTION;
    }

    case WM_USER_UPDATECHECK_DONE: // feature 123: the stored state changed
    {
        RefreshUpdateLine();
        return TRUE;
    }

    case WM_COMMAND:
    {
        if (LOWORD(wParam) == CM_HELP_CHECKVERSION) // the link "Check now"
        {
            CUpdateCheckDone done;
            UpdateCheck_RunManualUI(HWindow, &done); // answers by itself, except "newer": the line shows it
            RefreshUpdateLine();
            return TRUE;
        }
        if (LOWORD(wParam) == IDC_ABOUT_UPDATECMD) // the link "Download"
        {
            CUpdateState state;
            char url[SALUPD_URL_MAX];
            if (UpdateCheck_GetKnownState(&state) == suksNewer && SalUpdInstallerUrl(state.Latest, url, sizeof(url)))
                UpdateCheck_OpenUrl(HWindow, url);
            return TRUE;
        }
        break;
    }

    case WM_DESTROY:
    {
        if (UpdateAboutWindow == HWindow)
            UpdateAboutWindow = NULL;
        break;
    }
    }
    return CCommonDialog::DialogProc(uMsg, wParam, lParam);
}
