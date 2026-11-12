// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "lib\\pvw32dll.h"
#include "renderer.h"
#include "pictview.h"
#include "pictview.rh"
#include "pictview.rh2"
#include "lang\lang.rh"
#include "../../common/themes_bitmap.h" // feature 427: ThemeDarkAdaptIcon

//****************************************************************************
//
// CStatusBar
//

CStatusBar::CStatusBar()
    : CWindow(ooAllocated)
{
    HCursor = HAnchor = HSize = HPipette = NULL;
    LoadIcons();
    hProgBar = NULL;
}

// feature 427: a part icon for the current theme - in Dark the legacy black glyph adapted (the 028
// rule and the 3:1 lift, as the toolbar glyphs; review 4, S5: ~1.5:1 on the Dark face before)
static HICON LoadStatusIcon427(int id)
{
    HICON icon = (HICON)LoadImage(DLLInstance, MAKEINTRESOURCE(id), IMAGE_ICON, 16, 16, SalamanderGeneral->GetIconLRFlags());
    if (icon != NULL && SalamanderGeneral->IsDarkThemeActive())
    {
        HICON dark = ThemeDarkAdaptIcon(icon, SalamanderGeneral->GetThemeSysColor(COLOR_BTNFACE));
        if (dark != NULL)
        {
            DestroyIcon(icon);
            icon = dark;
        }
    }
    return icon;
}

void CStatusBar::LoadIcons()
{
    HICON* slots[4] = {&HCursor, &HAnchor, &HSize, &HPipette};
    const int ids[4] = {IDI_SB_CURSOR, IDI_SB_ANCHOR, IDI_SB_SIZE, IDI_SB_PIPETTE};
    HICON old[4], fresh[4];
    int i;
    for (i = 0; i < 4; i++)
    {
        old[i] = *slots[i];
        fresh[i] = LoadStatusIcon427(ids[i]);
        *slots[i] = fresh[i];
    }
    // the parts that showed an old icon show the new one before the old one is destroyed
    if (HWindow != NULL)
    {
        int parts = (int)SendMessage(HWindow, SB_GETPARTS, 0, 0);
        for (int part = 0; part < parts; part++)
        {
            HICON shown = (HICON)SendMessage(HWindow, SB_GETICON, part, 0);
            for (i = 0; i < 4; i++)
                if (shown != NULL && shown == old[i])
                    SendMessage(HWindow, SB_SETICON, part, (LPARAM)fresh[i]);
        }
    }
    for (i = 0; i < 4; i++)
        if (old[i] != NULL)
            DestroyIcon(old[i]);
}

CStatusBar::~CStatusBar()
{
    DestroyIcon(HCursor);
    DestroyIcon(HAnchor);
    DestroyIcon(HSize);
    DestroyIcon(HPipette);
    if (hProgBar)
    {
        DestroyWindow(hProgBar);
    }
}

#define ICON_MARGIN 32 // space for the icon and margins

void CViewerWindow::SetupStatusBarItems()
{
    if (StatusBar == NULL)
        return;
    HWND hStatusBar = StatusBar->HWindow;

    HFONT hFont = (HFONT)SendMessage(hStatusBar, WM_GETFONT, 0, 0);

    // measure the widths of the items
    int whSize, rgbSize;
    SIZE sz;
    HDC hDC = GetDC(hStatusBar);
    HFONT hOldFont = (HFONT)SelectObject(hDC, hFont);
    TCHAR buff[255];
    _stprintf(buff, LoadStr(IDS_SB_WH), Renderer.pvii.Width, Renderer.pvii.Height);
    GetTextExtentPoint32(hDC, buff, (int)_tcslen(buff), &sz);
    whSize = sz.cx + ICON_MARGIN;
    _stprintf(buff, LoadStr(IDS_SB_RGB), 255, 255, 255);
    GetTextExtentPoint32(hDC, buff, (int)_tcslen(buff), &sz);
    rgbSize = max(whSize, sz.cx) + ICON_MARGIN + 10; // the bottom-right corner overwrites us
    SelectObject(hDC, hOldFont);
    ReleaseDC(hStatusBar, hDC);

    RECT r;
    GetClientRect(hStatusBar, &r);
    int width = r.right - r.left;

    // 0: text
    // 1: cursor
    // 2: size
    // 3: anchor/rgb
    INT parts[4];
    parts[3] = -1;
    parts[2] = width - rgbSize;
    parts[1] = parts[2] - whSize;
    parts[0] = parts[1] - whSize;
    SendMessage(hStatusBar, SB_SETPARTS, 4, (LPARAM)&parts);
}

void SafeSetStatusBarText(HWND hStatusBar, int part, LPCTSTR text)
{
    // if there is already text in the status bar, do not blink unnecessarily
    TCHAR buff[500];
    LRESULT ret = SendMessage(hStatusBar, SB_GETTEXT, part & 0xff, (LPARAM)buff);
    if (_tcscmp(buff, text) != NULL || HIWORD(ret) != (part & 0xffffff00))
    {
        lstrcpyn(buff, text, 500);
        SendMessage(hStatusBar, SB_SETTEXT, part, (LPARAM)buff);
    }
}

void SafeSetStatusBarIcon(HWND hStatusBar, int part, HICON hIcon)
{
    // if there is already an icon in the status bar, do not blink unnecessarily
    HICON hOldIcon = (HICON)SendMessage(hStatusBar, SB_GETICON, part, 0);
    if (hOldIcon != hIcon)
        SendMessage(hStatusBar, SB_SETICON, part, (LPARAM)hIcon);
}

void CViewerWindow::SetStatusBarTexts(int ID)
{
    if (StatusBar == NULL)
        return;
    HWND hStatusBar = StatusBar->HWindow;

    TCHAR buff[255];

    int imageWidth = Renderer.pvii.Width;
    int imageHeight = Renderer.pvii.Height;

    // tip
    buff[0] = 0;
    if (ID)
    {
        _tcscpy(buff, LoadStr(ID));
    }
    else
    {
        if (Renderer.CurrTool == RT_SELECT)
            _tcscpy(buff, LoadStr(IDS_SB_CAGE));
        if (Renderer.CurrTool == RT_ZOOM)
            _tcscpy(buff, LoadStr(IDS_SB_ZOOM));
        if (Renderer.CurrTool == RT_HAND)
            _tcscpy(buff, LoadStr(IDS_SB_HAND));
    }
    SafeSetStatusBarText(hStatusBar, 0 | SBT_NOBORDERS, buff);

    // cursor
    SafeSetStatusBarIcon(hStatusBar, 1, StatusBar->HCursor);
    DWORD newMousePos = GetMessagePos();
    POINT pt;
    pt.x = GET_X_LPARAM(newMousePos);
    pt.y = GET_Y_LPARAM(newMousePos);
    ScreenToClient(Renderer.HWindow, &pt);
    POINT clientPt = pt;
    BOOL validCursor = FALSE;

    if (Renderer.ImageLoaded)
    {
        Renderer.ClientToPicture(&pt); // convert pt into image coordinates
        if (pt.x >= 0 && pt.x < imageWidth && pt.y >= 0 && pt.y < imageHeight)
            validCursor = TRUE;
        if (validCursor)
            _stprintf(buff, LoadStr(IDS_SB_XY), pt.x, pt.y);
        else
            buff[0] = 0;
        SafeSetStatusBarText(hStatusBar, 1, buff);
    }

    // size
    SafeSetStatusBarIcon(hStatusBar, 2, StatusBar->HSize);
    int sizeWidth, sizeHeight;
    if (IsCageValid(&Renderer.TmpCageRect))
    {
        // the dragged cage has priority
        sizeWidth = abs(Renderer.TmpCageRect.right - Renderer.TmpCageRect.left) + 1;
        sizeHeight = abs(Renderer.TmpCageRect.bottom - Renderer.TmpCageRect.top) + 1;
    }
    else if (IsCageValid(&Renderer.SelectRect))
    {
        // otherwise an existing selection
        sizeWidth = abs(Renderer.SelectRect.right - Renderer.SelectRect.left) + 1;
        sizeHeight = abs(Renderer.SelectRect.bottom - Renderer.SelectRect.top) + 1;
    }
    else
    {
        // otherwise the image size
        sizeWidth = imageWidth;
        sizeHeight = imageHeight;
    }
    _stprintf(buff, LoadStr(IDS_SB_WH), sizeWidth, sizeHeight);
    SafeSetStatusBarText(hStatusBar, 2, buff);

    // anchor
    if (IsCageValid(&Renderer.TmpCageRect))
    {
        SafeSetStatusBarIcon(hStatusBar, 3, StatusBar->HAnchor);
        _stprintf(buff, LoadStr(IDS_SB_XY), Renderer.TmpCageRect.left, Renderer.TmpCageRect.top);
        SafeSetStatusBarText(hStatusBar, 3, buff);
    }
    else
    {
        SafeSetStatusBarIcon(hStatusBar, 3, StatusBar->HPipette);
        if (validCursor)
        {
            int ind;
            RGBQUAD rgb;

            Renderer.ClientToPicture(&clientPt);
            if (Renderer.GetRGBAtCursor(clientPt.x, clientPt.y, &rgb, &ind)) // feature 120: nothing when unread
                _stprintf(buff, LoadStr(IDS_SB_RGB), rgb.rgbRed, rgb.rgbGreen, rgb.rgbBlue);
            else
                buff[0] = 0;
        }
        else
            buff[0] = 0;
    }
    SafeSetStatusBarText(hStatusBar, 3, buff);
}

void CViewerWindow::InitProgressBar()
{
    RECT r;

    if (StatusBar == NULL)
    {
        return;
    }
    SendMessage(StatusBar->HWindow, SB_GETRECT, 1, (LPARAM)&r);
    StatusBar->hProgBar = CreateWindowEx(0, PROGRESS_CLASS, NULL,
                                         PBS_SMOOTH | WS_CHILD | WS_VISIBLE, r.left, r.top,
                                         r.right - r.left, r.bottom - r.top,
                                         StatusBar->HWindow, NULL, DLLInstance, NULL);

    SendMessage(StatusBar->hProgBar, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
    SendMessage(StatusBar->hProgBar, PBM_SETPOS, 0, 0);
}

void CViewerWindow::KillProgressBar()
{
    if (StatusBar == NULL)
    {
        return;
    }
    if (StatusBar->hProgBar)
    {
        DestroyWindow(StatusBar->hProgBar);
        StatusBar->hProgBar = NULL;
    }
}

void CViewerWindow::SetProgress(int done)
{
    if (StatusBar && StatusBar->hProgBar)
    {
        SendMessage(StatusBar->hProgBar, PBM_SETPOS, done, 0);
    }
}
