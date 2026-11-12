// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// darkmenu.cpp - owner-drawn dark rendering for the viewer's native menu bar
// and popups (feature 037). See darkmenu.h for the contract; design decisions
// in specs/037-mdview-dark-polish/research.md (R4).

#include "precomp.h"
#include "darkmenu.h"

// paint data attached to each owner-drawn item via dwItemData
struct DarkMenuItemData
{
    std::string text; // label incl. '&' mnemonic and optional "\tCtrl+X" accel
    bool isSeparator;
    bool isBarItem;
};

// One menu font per DPI (feature 424: the viewer windows are per-monitor aware, a window on a
// monitor of another scaling needs the font of that scaling). Every viewer window has its own
// thread, hence the lock. A font is never deleted while the module runs (a menu of another
// thread may be drawing with it); when the table is full the first font serves.
struct DarkMenuFontEntry
{
    UINT dpi;
    HFONT font;
};
static const int DARKMENU_FONT_SLOTS = 8;
static DarkMenuFontEntry DarkMenuFonts[DARKMENU_FONT_SLOTS];
static int DarkMenuFontCount = 0;
static SRWLOCK DarkMenuFontLock = SRWLOCK_INIT;

static UINT DarkMenuDpi(UINT dpi) { return dpi != 0 ? dpi : GetDpiForSystem(); }

static HFONT DarkMenuFont(UINT dpi)
{
    dpi = DarkMenuDpi(dpi);
    HFONT font = NULL;
    AcquireSRWLockExclusive(&DarkMenuFontLock);
    for (int i = 0; i < DarkMenuFontCount && font == NULL; i++)
        if (DarkMenuFonts[i].dpi == dpi)
            font = DarkMenuFonts[i].font;
    if (font == NULL && DarkMenuFontCount < DARKMENU_FONT_SLOTS)
    {
        NONCLIENTMETRICSW ncm;
        memset(&ncm, 0, sizeof(ncm));
        ncm.cbSize = sizeof(ncm);
        if (SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(ncm), &ncm, 0, dpi))
            font = CreateFontIndirectW(&ncm.lfMenuFont);
        if (font != NULL)
        {
            DarkMenuFonts[DarkMenuFontCount].dpi = dpi;
            DarkMenuFonts[DarkMenuFontCount].font = font;
            DarkMenuFontCount++;
        }
    }
    if (font == NULL && DarkMenuFontCount > 0)
        font = DarkMenuFonts[0].font;
    ReleaseSRWLockExclusive(&DarkMenuFontLock);
    return font != NULL ? font : (HFONT)GetStockObject(DEFAULT_GUI_FONT);
}

void DarkMenuReleaseFont()
{
    AcquireSRWLockExclusive(&DarkMenuFontLock);
    for (int i = 0; i < DarkMenuFontCount; i++)
        DeleteObject(DarkMenuFonts[i].font);
    DarkMenuFontCount = 0;
    ReleaseSRWLockExclusive(&DarkMenuFontLock);
}

static void SplitLabelAccel(const std::string& text, std::string& label, std::string& accel)
{
    size_t tab = text.find('\t');
    if (tab == std::string::npos)
    {
        label = text;
        accel.clear();
    }
    else
    {
        label = text.substr(0, tab);
        accel = text.substr(tab + 1);
    }
}

static void ApplyToMenu(HMENU menu, bool barLevel)
{
    int count = GetMenuItemCount(menu);
    int i;
    for (i = 0; i < count; i++)
    {
        char buf[200];
        buf[0] = 0;
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU | MIIM_STRING;
        mii.dwTypeData = buf;
        mii.cch = sizeof(buf) - 1;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;

        DarkMenuItemData* d = new DarkMenuItemData;
        d->text = buf;
        d->isSeparator = (mii.fType & MFT_SEPARATOR) != 0;
        d->isBarItem = barLevel;

        MENUITEMINFOA set;
        memset(&set, 0, sizeof(set));
        set.cbSize = sizeof(set);
        set.fMask = MIIM_FTYPE | MIIM_DATA;
        set.fType = mii.fType | MFT_OWNERDRAW;
        set.dwItemData = (ULONG_PTR)d;
        if (!SetMenuItemInfoA(menu, i, TRUE, &set))
        {
            delete d;
            continue;
        }

        if (mii.hSubMenu != NULL)
            ApplyToMenu(mii.hSubMenu, false);
    }

    // dark background for the menu surface itself (gutter, margins, bar strip);
    // engine-owned brush - never deleted here
    MENUINFO mi;
    memset(&mi, 0, sizeof(mi));
    mi.cbSize = sizeof(mi);
    mi.fMask = MIM_BACKGROUND;
    mi.hbrBack = SalamanderGeneral->GetThemeSysColorBrush(barLevel ? COLOR_MENUBAR : COLOR_MENU);
    SetMenuInfo(menu, &mi);
}

void DarkMenuApply(HMENU bar)
{
    if (bar != NULL)
        ApplyToMenu(bar, true);
}

static void ReleaseMenu(HMENU menu)
{
    int count = GetMenuItemCount(menu);
    int i;
    for (i = 0; i < count; i++)
    {
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU | MIIM_DATA;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) != 0 && mii.dwItemData != 0)
        {
            delete (DarkMenuItemData*)mii.dwItemData;
            MENUITEMINFOA clr;
            memset(&clr, 0, sizeof(clr));
            clr.cbSize = sizeof(clr);
            clr.fMask = MIIM_DATA;
            SetMenuItemInfoA(menu, i, TRUE, &clr);
        }
        if (mii.hSubMenu != NULL)
            ReleaseMenu(mii.hSubMenu);
    }
}

// feature 424: owner-drawn items keep the size measured at the DPI they were first shown at.
// Re-setting an item's bitmap (its own value back; the viewers' items have none) makes
// Windows measure it again (WM_MEASUREITEM) the next time the bar is drawn or the popup
// shown; re-setting the unchanged type, its data, or toggling MFT_OWNERDRAW does NOT, nor
// does this for an item with a real bitmap (measured by the 424 reviews 2 and 3 on Windows 11,
// specs/424-webview-dpi-awareness/probe/menutest; undocumented - at worst a dark menu keeps
// the old DPI's sizes).
static void RemeasureMenu(HMENU menu)
{
    int count = GetMenuItemCount(menu);
    for (int i = 0; i < count; i++)
    {
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_SUBMENU | MIIM_BITMAP;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) != 0)
        {
            MENUITEMINFOA set;
            memset(&set, 0, sizeof(set));
            set.cbSize = sizeof(set);
            set.fMask = MIIM_BITMAP;
            set.hbmpItem = mii.hbmpItem;
            SetMenuItemInfoA(menu, i, TRUE, &set);
        }
        if (mii.hSubMenu != NULL)
            RemeasureMenu(mii.hSubMenu);
    }
}

void DarkMenuRemeasure(HMENU bar)
{
    if (bar != NULL)
        RemeasureMenu(bar);
}

void DarkMenuRelease(HMENU bar)
{
    if (bar != NULL)
        ReleaseMenu(bar);
}

BOOL DarkMenuMeasureItem(MEASUREITEMSTRUCT* mis, UINT dpi)
{
    if (mis->CtlType != ODT_MENU || mis->itemData == 0)
        return FALSE;
    DarkMenuItemData* d = (DarkMenuItemData*)mis->itemData;

    if (d->isSeparator)
    {
        mis->itemWidth = 40;
        mis->itemHeight = 5;
        return TRUE;
    }

    std::string label, accel;
    SplitLabelAccel(d->text, label, accel);

    HDC dc = GetDC(NULL);
    HFONT old = (HFONT)SelectObject(dc, DarkMenuFont(dpi));
    SIZE szLabel = {0, 0};
    SIZE szAccel = {0, 0};
    GetTextExtentPoint32A(dc, label.c_str(), (int)label.size(), &szLabel);
    if (!accel.empty())
        GetTextExtentPoint32A(dc, accel.c_str(), (int)accel.size(), &szAccel);
    SelectObject(dc, old);
    ReleaseDC(NULL, dc);

    if (d->isBarItem)
    {
        mis->itemWidth = szLabel.cx;
        mis->itemHeight = GetSystemMetricsForDpi(SM_CYMENU, DarkMenuDpi(dpi));
    }
    else
    {
        int gutter = GetSystemMetricsForDpi(SM_CXMENUCHECK, DarkMenuDpi(dpi)) + 6;
        mis->itemWidth = gutter + szLabel.cx + (accel.empty() ? 0 : 24 + szAccel.cx) + 14;
        int h = szLabel.cy + 8;
        int minH = GetSystemMetricsForDpi(SM_CYMENU, DarkMenuDpi(dpi));
        mis->itemHeight = h > minH ? h : minH;
    }
    return TRUE;
}

// Draws a check/radio glyph: DrawFrameControl renders black-on-white into a
// mono bitmap; the mono->color BitBlt maps black to the DC text color and
// white to the DC background color.
static void DrawMenuGlyph(HDC dc, int x, int y, UINT dfcs, COLORREF fg, COLORREF bk, UINT dpi)
{
    int cx = GetSystemMetricsForDpi(SM_CXMENUCHECK, DarkMenuDpi(dpi));
    int cy = GetSystemMetricsForDpi(SM_CYMENUCHECK, DarkMenuDpi(dpi));
    HDC mem = CreateCompatibleDC(dc);
    if (mem == NULL)
        return;
    HBITMAP bmp = CreateBitmap(cx, cy, 1, 1, NULL);
    if (bmp != NULL)
    {
        HBITMAP oldBmp = (HBITMAP)SelectObject(mem, bmp);
        RECT r = {0, 0, cx, cy};
        DrawFrameControl(mem, &r, DFC_MENU, dfcs);
        COLORREF oldTxt = SetTextColor(dc, fg);
        COLORREF oldBk = SetBkColor(dc, bk);
        BitBlt(dc, x, y, cx, cy, mem, 0, 0, SRCCOPY);
        SetTextColor(dc, oldTxt);
        SetBkColor(dc, oldBk);
        SelectObject(mem, oldBmp);
        DeleteObject(bmp);
    }
    DeleteDC(mem);
}

BOOL DarkMenuDrawItem(const DRAWITEMSTRUCT* dis, UINT dpi)
{
    if (dis->CtlType != ODT_MENU || dis->itemData == 0)
        return FALSE;
    DarkMenuItemData* d = (DarkMenuItemData*)dis->itemData;
    HDC dc = dis->hDC;
    RECT rc = dis->rcItem;
    BOOL selected = (dis->itemState & (ODS_SELECTED | ODS_HOTLIGHT)) != 0 &&
                    (dis->itemState & (ODS_GRAYED | ODS_DISABLED)) == 0;

    int bkIndex;
    if (selected)
        bkIndex = d->isBarItem ? COLOR_MENUHILIGHT : COLOR_HIGHLIGHT;
    else
        bkIndex = d->isBarItem ? COLOR_MENUBAR : COLOR_MENU;
    COLORREF bkColor = SalamanderGeneral->GetThemeSysColor(bkIndex);
    FillRect(dc, &rc, SalamanderGeneral->GetThemeSysColorBrush(bkIndex));

    if (d->isSeparator)
    {
        int y = (rc.top + rc.bottom) / 2;
        RECT line = {rc.left + 8, y, rc.right - 8, y + 1};
        FillRect(dc, &line, SalamanderGeneral->GetThemeSysColorBrush(COLOR_3DLIGHT));
        return TRUE;
    }

    COLORREF txtColor;
    if ((dis->itemState & (ODS_GRAYED | ODS_DISABLED)) != 0)
        txtColor = SalamanderGeneral->GetThemeSysColor(COLOR_GRAYTEXT);
    else if (selected)
        txtColor = SalamanderGeneral->GetThemeSysColor(COLOR_HIGHLIGHTTEXT);
    else
        txtColor = SalamanderGeneral->GetThemeSysColor(COLOR_MENUTEXT);

    std::string label, accel;
    SplitLabelAccel(d->text, label, accel);

    SetTextColor(dc, txtColor);
    SetBkMode(dc, TRANSPARENT);
    HFONT oldFont = (HFONT)SelectObject(dc, DarkMenuFont(dpi));
    UINT dt = DT_SINGLELINE | DT_VCENTER | DT_NOCLIP;
    if ((dis->itemState & ODS_NOACCEL) != 0)
        dt |= DT_HIDEPREFIX;

    if (d->isBarItem)
    {
        DrawTextA(dc, label.c_str(), (int)label.size(), &rc, dt | DT_CENTER);
    }
    else
    {
        int gutter = GetSystemMetricsForDpi(SM_CXMENUCHECK, DarkMenuDpi(dpi)) + 6;
        RECT tr = rc;
        tr.left += gutter + 2;
        DrawTextA(dc, label.c_str(), (int)label.size(), &tr, dt | DT_LEFT);
        if (!accel.empty())
        {
            RECT ar = rc;
            ar.right -= 10;
            DrawTextA(dc, accel.c_str(), (int)accel.size(), &ar, dt | DT_RIGHT);
        }
        if ((dis->itemState & ODS_CHECKED) != 0)
        {
            // radio vs check read live from the menu (CheckMenuRadioItem sets
            // MFT_RADIOCHECK after DarkMenuApply converted the items)
            UINT dfcs = DFCS_MENUCHECK;
            MENUITEMINFOA mii;
            memset(&mii, 0, sizeof(mii));
            mii.cbSize = sizeof(mii);
            mii.fMask = MIIM_FTYPE;
            if (GetMenuItemInfoA((HMENU)dis->hwndItem, dis->itemID, FALSE, &mii) &&
                (mii.fType & MFT_RADIOCHECK) != 0)
                dfcs = DFCS_MENUBULLET;
            int gy = rc.top + ((rc.bottom - rc.top) - GetSystemMetricsForDpi(SM_CYMENUCHECK, DarkMenuDpi(dpi))) / 2;
            DrawMenuGlyph(dc, rc.left + 3, gy, dfcs, txtColor, bkColor, dpi);
        }
    }
    SelectObject(dc, oldFont);
    return TRUE;
}

LRESULT DarkMenuHandleMenuChar(HMENU menu, WPARAM wParam)
{
    if (menu == NULL)
        return MAKELRESULT(0, MNC_IGNORE);
    char ch = (char)tolower((unsigned char)LOWORD(wParam));
    int count = GetMenuItemCount(menu);
    int first = -1;
    int matches = 0;
    int i;
    for (i = 0; i < count; i++)
    {
        MENUITEMINFOA mii;
        memset(&mii, 0, sizeof(mii));
        mii.cbSize = sizeof(mii);
        mii.fMask = MIIM_FTYPE | MIIM_DATA | MIIM_STATE;
        if (!GetMenuItemInfoA(menu, i, TRUE, &mii))
            continue;
        if ((mii.fType & MFT_OWNERDRAW) == 0 || mii.dwItemData == 0)
            continue;
        if ((mii.fState & (MFS_GRAYED | MFS_DISABLED)) != 0)
            continue;
        DarkMenuItemData* d = (DarkMenuItemData*)mii.dwItemData;
        size_t amp = d->text.find('&');
        while (amp != std::string::npos && amp + 1 < d->text.size() && d->text[amp + 1] == '&')
            amp = d->text.find('&', amp + 2); // skip literal "&&"
        if (amp == std::string::npos || amp + 1 >= d->text.size())
            continue;
        if ((char)tolower((unsigned char)d->text[amp + 1]) == ch)
        {
            if (first < 0)
                first = i;
            matches++;
        }
    }
    if (matches == 1)
        return MAKELRESULT(first, MNC_EXECUTE);
    if (matches > 1)
        return MAKELRESULT(first, MNC_SELECT);
    return MAKELRESULT(0, MNC_IGNORE);
}
