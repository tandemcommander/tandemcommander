// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <dwmapi.h>
#include <uxtheme.h>
#include <vssym32.h> // HP_HEADERITEM/HIS_* for the header label repaint (049)

#include "cfgdlg.h"
#include "usermenu.h"
#include "execute.h"
#include "plugins.h"
#include "fileswnd.h"
#include "mainwnd.h"
#include "themes.h"
#include "themes_palette.h"
#include "themes_bitmap.h" // feature 427: ThemeDarkAdaptBitmap
#include "salsortarrow.h" // feature 407: the sort arrow of a dark header

// theme-aware checkbox state glyphs for listviews (declared in gui.h, which
// carries heavy include-order dependencies - forward-declare instead)
HIMAGELIST CreateCheckboxImagelist(int itemSize);

#pragma comment(lib, "Dwmapi.lib")

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

// window property marking windows we have dark-themed; lets the Default
// theme stay a pure no-op for windows that were never touched
static const char* THEME_DARKENED_PROP = "SalThemeDark";

// window property marking listviews whose LVS_EX_CHECKBOXES state image
// list was replaced with the theme-aware generated pair (feature 049)
static const char* THEME_DARKCHK_PROP = "SalThemeDarkChk";

//
// ****************************************************************************
// High Contrast state
//

static BOOL ThemeHighContrast = FALSE;
static BOOL ThemeHighContrastValid = FALSE;

static void InitThemeDarkSysColors();

void RefreshThemeHighContrastState()
{
    HIGHCONTRAST hc;
    memset(&hc, 0, sizeof(hc));
    hc.cbSize = sizeof(hc);
    ThemeHighContrast = SystemParametersInfo(SPI_GETHIGHCONTRAST, sizeof(hc), &hc, 0) &&
                        (hc.dwFlags & HCF_HIGHCONTRASTON) != 0;
    ThemeHighContrastValid = TRUE;
    InitThemeDarkSysColors(); // eager init: the viewer thread reads the LUT
}

BOOL IsThemeHighContrast()
{
    if (!ThemeHighContrastValid)
        RefreshThemeHighContrastState();
    return ThemeHighContrast;
}

BOOL IsDarkThemeActive()
{
    if (Configuration.ThemeMode != THEME_MODE_DARK)
        return FALSE;
    if (!ThemeHighContrastValid)
        RefreshThemeHighContrastState();
    return !ThemeHighContrast; // High Contrast wins over the application theme
}

//
// ****************************************************************************
// Dark chrome palette (specs/028-visual-themes/data-model.md, section 5)
//

#define THEME_SYSCOLOR_COUNT 31 // COLOR_3DDKSHADOW(21)..COLOR_MENUBAR(30) fit below 31

static COLORREF ThemeDarkSysColors[THEME_SYSCOLOR_COUNT];
static BOOL ThemeDarkSysColorsValid = FALSE;

static void InitThemeDarkSysColors()
{
    int i;
    for (i = 0; i < THEME_SYSCOLOR_COUNT; i++)
        ThemeDarkSysColors[i] = CLR_INVALID; // unmapped -> GetSysColor fallback

#define THEME_SET_ENTRY(idx, r, g, b) ThemeDarkSysColors[idx] = RGB(r, g, b);
    THEME_DARK_SYSCOLORS(THEME_SET_ENTRY)
#undef THEME_SET_ENTRY

    ThemeDarkSysColorsValid = TRUE;
}

COLORREF ThemeSysColor(int index)
{
    if (!IsDarkThemeActive())
        return GetSysColor(index);
    if (!ThemeDarkSysColorsValid)
        InitThemeDarkSysColors();
    if (index >= 0 && index < THEME_SYSCOLOR_COUNT && ThemeDarkSysColors[index] != CLR_INVALID)
        return ThemeDarkSysColors[index];
    return GetSysColor(index);
}

//
// ****************************************************************************
// Brush cache (engine-owned solid brushes for the dark palette)
//

static HBRUSH ThemeDarkBrushes[THEME_SYSCOLOR_COUNT] = {0};

HBRUSH ThemeSysColorBrush(int index)
{
    if (!IsDarkThemeActive())
        return GetSysColorBrush(index);
    if (index < 0 || index >= THEME_SYSCOLOR_COUNT)
        return GetSysColorBrush(index);
    if (ThemeDarkBrushes[index] == NULL)
        ThemeDarkBrushes[index] = HANDLES(CreateSolidBrush(ThemeSysColor(index)));
    if (ThemeDarkBrushes[index] == NULL) // out of GDI resources: never return NULL
        return GetSysColorBrush(index);
    return ThemeDarkBrushes[index];
}

void ReleaseThemeGraphics()
{
    int i;
    for (i = 0; i < THEME_SYSCOLOR_COUNT; i++)
    {
        if (ThemeDarkBrushes[i] != NULL)
        {
            HANDLES(DeleteObject(ThemeDarkBrushes[i]));
            ThemeDarkBrushes[i] = NULL;
        }
    }
}

//
// ****************************************************************************
// ThemeDrawEdge
//

BOOL ThemeDrawEdge(HDC hDC, RECT* rc, UINT edge, UINT flags)
{
    if (!IsDarkThemeActive())
        return DrawEdge(hDC, rc, edge, flags);

    // flat single-pixel bevel in the dark theme; raised edges get the light
    // color top/left, sunken edges get it bottom/right
    BOOL sunken = (edge & (BDR_SUNKENOUTER | BDR_SUNKENINNER)) != 0;
    COLORREF tl = sunken ? ThemeSysColor(COLOR_3DDKSHADOW) : ThemeSysColor(COLOR_3DLIGHT);
    COLORREF br = sunken ? ThemeSysColor(COLOR_3DLIGHT) : ThemeSysColor(COLOR_3DDKSHADOW);

    if (flags & BF_MIDDLE)
        FillRect(hDC, rc, ThemeSysColorBrush(COLOR_BTNFACE));

    RECT r = *rc;
    COLORREF oldBk = SetBkColor(hDC, tl);
    RECT line;
    if (flags & BF_TOP)
    {
        line = r;
        line.bottom = line.top + 1;
        ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &line, NULL, 0, NULL);
    }
    if (flags & BF_LEFT)
    {
        line = r;
        line.right = line.left + 1;
        ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &line, NULL, 0, NULL);
    }
    SetBkColor(hDC, br);
    if (flags & BF_BOTTOM)
    {
        line = r;
        line.top = line.bottom - 1;
        ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &line, NULL, 0, NULL);
    }
    if (flags & BF_RIGHT)
    {
        line = r;
        line.left = line.right - 1;
        ExtTextOut(hDC, 0, 0, ETO_OPAQUE, &line, NULL, 0, NULL);
    }
    SetBkColor(hDC, oldBk);

    if (flags & BF_ADJUST)
    {
        if (flags & BF_LEFT)
            rc->left++;
        if (flags & BF_TOP)
            rc->top++;
        if (flags & BF_RIGHT)
            rc->right--;
        if (flags & BF_BOTTOM)
            rc->bottom--;
    }
    return TRUE;
}

//
// ****************************************************************************
// Palette repointing + theme switch
//

void UpdateCurrentColorsForTheme()
{
    if (IsDarkThemeActive())
    {
        CurrentColors = DarkColors;
        CurrentViewerColors = DarkViewerColors;
        // pre-create every mapped brush on the main thread: other threads
        // (viewer) may ask for arbitrary indices and the lazy
        // CreateSolidBrush in ThemeSysColorBrush must never race (049, G3)
        if (!ThemeDarkSysColorsValid)
            InitThemeDarkSysColors();
        int i;
        for (i = 0; i < THEME_SYSCOLOR_COUNT; i++)
            if (ThemeDarkSysColors[i] != CLR_INVALID)
                ThemeSysColorBrush(i);
    }
    else
    {
        CurrentColors = SchemeColors;
        CurrentViewerColors = ViewerColors;
    }
}

void ThemeApplyToTopLevel(HWND hWindow)
{
    if (hWindow == NULL)
        return;
    BOOL dark = IsDarkThemeActive();
    if (!dark && GetPropA(hWindow, THEME_DARKENED_PROP) == NULL)
        return; // never touched by us: keep the Default theme a pure no-op

    BOOL value = dark;
    DwmSetWindowAttribute(hWindow, DWMWA_USE_IMMERSIVE_DARK_MODE, &value, sizeof(value));
    if (dark)
        SetPropA(hWindow, THEME_DARKENED_PROP, (HANDLE)1);
    else
        RemovePropA(hWindow, THEME_DARKENED_PROP);
}

void ThemeUpdateWindowClassBackground(HWND hWindow, int lightSysColor)
{
    if (hWindow == NULL)
        return;
    if (IsDarkThemeActive())
        SetClassLongPtr(hWindow, GCLP_HBRBACKGROUND, (LONG_PTR)ThemeSysColorBrush(lightSysColor));
    else
        SetClassLongPtr(hWindow, GCLP_HBRBACKGROUND, (LONG_PTR)(HBRUSH)(UINT_PTR)(lightSysColor + 1));
}

void ThemeUpdateRebarStyle(HWND hRebar)
{
    if (hRebar == NULL)
        return;
    // feature 418: the etched border and the band borders stay in both themes, so the toolbar area -
    // and the panel tab strip below it - has the same rows in Dark as in the default theme (without
    // them the Dark rebar was 8 px shorter and the strip lost its frame: "the tabs look lower").
    // Feature 028 removed them in Dark only because the rebar drew them in the light system colours;
    // its colour scheme makes it draw them in the Dark palette's shadow / highlight instead (the
    // default theme keeps CLR_DEFAULT, i.e. the system colours - pixel-identical to before).
    DWORD style = (DWORD)GetWindowLongPtr(hRebar, GWL_STYLE);
    DWORD newStyle = style | WS_BORDER | RBS_BANDBORDERS;
    BOOL dark = IsDarkThemeActive();
    COLORSCHEME cs;
    cs.dwSize = sizeof(cs);
    cs.clrBtnHighlight = dark ? ThemeSysColor(COLOR_BTNHIGHLIGHT) : CLR_DEFAULT;
    cs.clrBtnShadow = dark ? ThemeSysColor(COLOR_BTNSHADOW) : CLR_DEFAULT;
    COLORSCHEME old;
    old.dwSize = sizeof(old);
    BOOL schemeChanged = !SendMessage(hRebar, RB_GETCOLORSCHEME, 0, (LPARAM)&old) ||
                         old.clrBtnHighlight != cs.clrBtnHighlight || old.clrBtnShadow != cs.clrBtnShadow;
    if (schemeChanged)
        SendMessage(hRebar, RB_SETCOLORSCHEME, 0, (LPARAM)&cs);
    if (newStyle != style)
    {
        SetWindowLongPtr(hRebar, GWL_STYLE, newStyle);
        SetWindowPos(hRebar, NULL, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        InvalidateRect(hRebar, NULL, TRUE);
    }
    else if (schemeChanged) // a theme switch: the same layout, other colours - repaint the frame and the bands
        RedrawWindow(hRebar, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME);
}

LRESULT ThemeRebarCustomDraw(HWND hRebar, LPNMCUSTOMDRAW cd)
{
    // feature 418: the classic rebar draws a band's grip with the colour scheme's highlight /
    // shadow (dark in Dark, ThemeUpdateRebarStyle) but fills its middle with the system face
    // brush - a light stripe on the dark rebar (why feature 028 hid the grips in Dark, which
    // also moved the bands' contents and made them impossible to drag). After a band is drawn,
    // the light face pixels of its header (the grip's area, left of the band's child) become the
    // band's background. The default theme is left alone.
    if (!IsDarkThemeActive() || cd == NULL)
        return CDRF_DODEFAULT;
    if (cd->dwDrawStage == CDDS_PREPAINT)
        return CDRF_NOTIFYITEMDRAW;
    if (cd->dwDrawStage == CDDS_ITEMPREPAINT)
        return CDRF_NOTIFYPOSTPAINT;
    if (cd->dwDrawStage != CDDS_ITEMPOSTPAINT || cd->hdc == NULL)
        return CDRF_DODEFAULT;

    // the band drawn: dwItemSpec is its id (rc its header); never matched by the rectangle alone - a
    // hidden band (the drive bars while a band is dragged) keeps its old rectangle (review 3)
    int index = (int)SendMessage(hRebar, RB_IDTOINDEX, (WPARAM)cd->dwItemSpec, 0);
    RECT bandRect;
    if (index < 0 || !SendMessage(hRebar, RB_GETRECT, (WPARAM)index, (LPARAM)&bandRect) ||
        bandRect.left != cd->rc.left || bandRect.top != cd->rc.top)
        return CDRF_DODEFAULT;
    REBARBANDINFO rbbi;
    ZeroMemory(&rbbi, sizeof(rbbi));
    rbbi.cbSize = sizeof(REBARBANDINFO);
    rbbi.fMask = RBBIM_STYLE;
    if (!SendMessage(hRebar, RB_GETBANDINFO, (WPARAM)index, (LPARAM)&rbbi) ||
        (rbbi.fStyle & RBBS_GRIPPERALWAYS) == 0 || (rbbi.fStyle & RBBS_HIDDEN) != 0)
        return CDRF_DODEFAULT;
    RECT borders; // left: the header (grip) plus the gap before the child
    ZeroMemory(&borders, sizeof(borders));
    SendMessage(hRebar, RB_GETBANDBORDERS, (WPARAM)index, (LPARAM)&borders); // returns no value
    if (borders.left <= 0)
        return CDRF_DODEFAULT;
    int w = (int)borders.left;
    if (w > cd->rc.right - cd->rc.left)
        w = cd->rc.right - cd->rc.left;
    int h = cd->rc.bottom - cd->rc.top;
    if (w <= 0 || h <= 0 || w > 200 || h > 400)
        return CDRF_DODEFAULT;

    BITMAPINFO bi;
    ZeroMemory(&bi, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    void* bits = NULL;
    HDC mem = CreateCompatibleDC(cd->hdc);
    HBITMAP dib = mem != NULL ? CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &bits, NULL, 0) : NULL;
    if (dib != NULL && bits != NULL)
    {
        HGDIOBJ oldBmp = SelectObject(mem, dib);
        if (BitBlt(mem, 0, 0, w, h, cd->hdc, cd->rc.left, cd->rc.top, SRCCOPY))
        {
            GdiFlush();
            COLORREF light = GetSysColor(COLOR_BTNFACE);
            COLORREF face = (COLORREF)SendMessage(hRebar, RB_GETBKCOLOR, 0, 0);
            if (face == CLR_DEFAULT || face == CLR_NONE)
                face = ThemeSysColor(COLOR_BTNFACE);
            DWORD lightPx = ((DWORD)GetRValue(light) << 16) | ((DWORD)GetGValue(light) << 8) | GetBValue(light);
            DWORD facePx = ((DWORD)GetRValue(face) << 16) | ((DWORD)GetGValue(face) << 8) | GetBValue(face);
            DWORD* px = (DWORD*)bits;
            int changed = 0;
            for (int i = 0; i < w * h; i++)
            {
                if ((px[i] & 0x00FFFFFF) == lightPx)
                {
                    px[i] = facePx;
                    changed++;
                }
            }
            if (changed > 0 && lightPx != facePx)
                BitBlt(cd->hdc, cd->rc.left, cd->rc.top, w, h, mem, 0, 0, SRCCOPY);
        }
        SelectObject(mem, oldBmp);
    }
    if (dib != NULL)
        DeleteObject(dib);
    if (mem != NULL)
        DeleteDC(mem);
    return CDRF_DODEFAULT;
}

//
// ****************************************************************************
// Dialog theming
//

// Classic (unthemed) text controls render a DISABLED label with a two-pass
// etched emboss: COLOR_3DHILIGHT offset by 1px under COLOR_GRAYTEXT. On a
// dark background the near-white highlight makes the text look corroded.
// This subclass repaints the disabled label flat (theme gray on theme
// background); enabled controls and the Default theme pass through.
static LRESULT CALLBACK ThemeFlatDisabledTextSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                          LPARAM lParam, UINT_PTR uIdSubclass,
                                                          DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_PAINT:
    {
        if (!IsDarkThemeActive() || IsWindowEnabled(hWnd))
            break; // normal drawing

        DWORD style = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE);
        DWORD type = style & SS_TYPEMASK;
        if (type != SS_LEFT && type != SS_CENTER && type != SS_RIGHT &&
            type != SS_SIMPLE && type != SS_LEFTNOWORDWRAP)
            break; // icons/bitmaps/frames/owner-draw keep their own drawing

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        FillRect(hDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));
        WCHAR text[512];
        int len = GetWindowTextW(hWnd, text, _countof(text));
        if (len > 0)
        {
            HFONT hFont = (HFONT)SendMessage(hWnd, WM_GETFONT, 0, 0);
            HFONT hOldFont = hFont != NULL ? (HFONT)SelectObject(hDC, hFont) : NULL;
            int oldBkMode = SetBkMode(hDC, TRANSPARENT);
            COLORREF oldClr = SetTextColor(hDC, ThemeSysColor(COLOR_GRAYTEXT));
            UINT dt = DT_EXPANDTABS;
            if (type == SS_CENTER)
                dt |= DT_CENTER;
            else if (type == SS_RIGHT)
                dt |= DT_RIGHT;
            if (type == SS_SIMPLE || type == SS_LEFTNOWORDWRAP)
                dt |= DT_SINGLELINE;
            else
                dt |= DT_WORDBREAK;
            if (style & SS_NOPREFIX)
                dt |= DT_NOPREFIX;
            if (style & SS_CENTERIMAGE)
                dt |= DT_VCENTER | DT_SINGLELINE;
            DrawTextW(hDC, text, len, &r, dt);
            SetTextColor(hDC, oldClr);
            SetBkMode(hDC, oldBkMode);
            if (hOldFont != NULL)
                SelectObject(hDC, hOldFont);
        }
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeFlatDisabledTextSubclassProc, 2);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// SS_ETCHED* separators are drawn by the native Static control with real
// GetSysColor(COLOR_3DSHADOW/3DHILIGHT) - the etched edge never routes
// through WM_CTLCOLORSTATIC, so the lines stay light in the dark theme
// (feature 044). Repaint them with the dark bevel pair; the Default theme
// passes through to the native drawing.
static LRESULT CALLBACK ThemeEtchedLineSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                    LPARAM lParam, UINT_PTR uIdSubclass,
                                                    DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_PAINT:
    {
        if (!IsDarkThemeActive())
            break; // normal drawing

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        FillRect(hDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));
        // mirror the native geometry: the horizontal/vertical variants draw
        // a two-pixel etched line at the top/left of the client area
        DWORD type = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE) & SS_TYPEMASK;
        if (type == SS_ETCHEDHORZ)
            r.bottom = r.top + 2;
        else if (type == SS_ETCHEDVERT)
            r.right = r.left + 2;
        ThemeDrawEdge(hDC, &r, EDGE_ETCHED, BF_RECT);
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeEtchedLineSubclassProc, 3);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// A DISABLED Edit control paints its text with the visual style's
// ETS_DISABLED color (a light-theme gray), ignoring the WM_CTLCOLOR*
// colors entirely - unreadable on the dark face (feature 044). Repaint
// single-line disabled edits flat, like the static subclass above;
// enabled edits and the Default theme pass through.
static LRESULT CALLBACK ThemeFlatDisabledEditSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                          LPARAM lParam, UINT_PTR uIdSubclass,
                                                          DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_PAINT:
    {
        if (!IsDarkThemeActive() || IsWindowEnabled(hWnd))
            break; // normal drawing

        DWORD style = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE);

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        FillRect(hDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));
        WCHAR stackBuf[512];
        WCHAR* text = stackBuf;
        int textLen = GetWindowTextLengthW(hWnd);
        if (textLen + 1 > _countof(stackBuf))
            text = (WCHAR*)malloc(((size_t)textLen + 1) * sizeof(WCHAR));
        int len = text != NULL ? GetWindowTextW(hWnd, text, textLen + 1) : 0;
        if (len > 0)
        {
            RECT fr;
            SendMessage(hWnd, EM_GETRECT, 0, (LPARAM)&fr); // the exact text rectangle
            if (fr.right <= fr.left || fr.bottom <= fr.top)
                fr = r;
            HFONT hFont = (HFONT)SendMessage(hWnd, WM_GETFONT, 0, 0);
            HFONT hOldFont = hFont != NULL ? (HFONT)SelectObject(hDC, hFont) : NULL;
            int oldBkMode = SetBkMode(hDC, TRANSPARENT);
            COLORREF oldClr = SetTextColor(hDC, ThemeSysColor(COLOR_GRAYTEXT));
            // multiline disabled edits in this app are short informational
            // texts without scrolling; DrawText wrapping inside the edit's
            // own formatting rectangle matches their layout (feature 049)
            UINT dt = (style & ES_MULTILINE)
                          ? DT_WORDBREAK | DT_NOPREFIX | DT_EDITCONTROL | DT_EXPANDTABS
                          : DT_SINGLELINE | DT_NOPREFIX;
            if (style & ES_CENTER)
                dt |= DT_CENTER;
            else if (style & ES_RIGHT)
                dt |= DT_RIGHT;
            DrawTextW(hDC, text, len, &fr, dt);
            SetTextColor(hDC, oldClr);
            SetBkMode(hDC, oldBkMode);
            if (hOldFont != NULL)
                SelectObject(hDC, hOldFont);
        }
        if (text != NULL && text != stackBuf)
            free(text);
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeFlatDisabledEditSubclassProc, 4);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// comctl32 has no dark visual style for msctls_statusbar32 and ignores
// SB_SETBKCOLOR while visual styles are active, so the dark theme paints
// the whole control here: background, part borders and texts, forwarded
// owner-draw parts and the size grip (feature 044). The Default theme
// passes every message to the native control.
static LRESULT CALLBACK ThemeStatusBarSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                   LPARAM lParam, UINT_PTR uIdSubclass,
                                                   DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_ERASEBKGND:
    {
        if (!IsDarkThemeActive())
            break;
        RECT r;
        GetClientRect(hWnd, &r);
        FillRect((HDC)wParam, &r, ThemeSysColorBrush(COLOR_BTNFACE));
        return TRUE;
    }

    case WM_PAINT:
    {
        if (!IsDarkThemeActive())
            break;

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT client;
        GetClientRect(hWnd, &client);
        FillRect(hDC, &client, ThemeSysColorBrush(COLOR_BTNFACE));

        HFONT hFont = (HFONT)SendMessage(hWnd, WM_GETFONT, 0, 0);
        HFONT hOldFont = hFont != NULL ? (HFONT)SelectObject(hDC, hFont) : NULL;
        int oldBkMode = SetBkMode(hDC, TRANSPARENT);
        COLORREF oldClr = SetTextColor(hDC, ThemeSysColor(COLOR_BTNTEXT));

        int parts = (int)SendMessage(hWnd, SB_GETPARTS, 0, 0);
        int i;
        for (i = 0; i < parts; i++)
        {
            RECT r;
            if (!SendMessage(hWnd, SB_GETRECT, i, (LPARAM)&r))
                continue;
            LRESULT lenType = SendMessage(hWnd, SB_GETTEXTLENGTHW, i, 0);
            WORD flags = HIWORD(lenType);
            if (flags & SBT_OWNERDRAW)
            {
                // native contract: the parent draws owner-draw parts
                DRAWITEMSTRUCT dis;
                memset(&dis, 0, sizeof(dis));
                dis.CtlID = (UINT)GetDlgCtrlID(hWnd);
                dis.itemID = i;
                dis.itemAction = ODA_DRAWENTIRE;
                dis.hwndItem = hWnd;
                dis.hDC = hDC;
                dis.rcItem = r;
                dis.itemData = (ULONG_PTR)SendMessage(hWnd, SB_GETTEXTW, i, 0);
                SendMessage(GetParent(hWnd), WM_DRAWITEM, (WPARAM)dis.CtlID, (LPARAM)&dis);
                continue;
            }
            if ((flags & SBT_NOBORDERS) == 0)
            {
                RECT br = r;
                ThemeDrawEdge(hDC, &br, BDR_SUNKENOUTER, BF_RECT);
            }
            int len = LOWORD(lenType);
            if (len > 0)
            {
                WCHAR stackBuf[512];
                WCHAR* buf = stackBuf;
                if (len + 1 > _countof(stackBuf))
                    buf = (WCHAR*)malloc(((size_t)len + 1) * sizeof(WCHAR));
                if (buf != NULL)
                {
                    buf[0] = 0;
                    SendMessage(hWnd, SB_GETTEXTW, i, (LPARAM)buf);
                    RECT tr = r;
                    tr.left += 3;
                    tr.right -= 3;
                    DrawTextW(hDC, buf, -1, &tr, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
                    if (buf != stackBuf)
                        free(buf);
                }
            }
        }

        // size grip: three diagonal light/dark line pairs in the corner
        DWORD style = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE);
        if (style & SBARS_SIZEGRIP)
        {
            HPEN penLight = CreatePen(PS_SOLID, 1, ThemeSysColor(COLOR_3DLIGHT));
            HPEN penDark = CreatePen(PS_SOLID, 1, ThemeSysColor(COLOR_BTNSHADOW));
            if (penLight != NULL && penDark != NULL)
            {
                HPEN hOldPen = (HPEN)SelectObject(hDC, penLight);
                int x = client.right - 1;
                int y = client.bottom - 1;
                int o;
                for (o = 4; o <= 12; o += 4)
                {
                    SelectObject(hDC, penLight);
                    MoveToEx(hDC, x - o - 1, y, NULL);
                    LineTo(hDC, x + 1, y - o - 2);
                    SelectObject(hDC, penDark);
                    MoveToEx(hDC, x - o, y, NULL);
                    LineTo(hDC, x + 1, y - o - 1);
                }
                SelectObject(hDC, hOldPen);
            }
            if (penLight != NULL)
                DeleteObject(penLight);
            if (penDark != NULL)
                DeleteObject(penDark);
        }

        SetTextColor(hDC, oldClr);
        SetBkMode(hDC, oldBkMode);
        if (hOldFont != NULL)
            SelectObject(hDC, hOldFont);
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeStatusBarSubclassProc, 5);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// Classic group boxes paint their etched frame with real
// GetSysColor(COLOR_3DHILIGHT/3DSHADOW) - the frame never routes through
// WM_CTLCOLORSTATIC, so it stays light in the dark theme (feature 049; the
// group-box sibling of the 044 SS_ETCHED* defect). Repaint frame + label
// with the dark bevel pair; the Default theme passes through.
static LRESULT CALLBACK ThemeGroupBoxSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                  LPARAM lParam, UINT_PTR uIdSubclass,
                                                  DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_PAINT:
    {
        if (!IsDarkThemeActive())
            break; // normal drawing

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        HFONT hFont = (HFONT)SendMessage(hWnd, WM_GETFONT, 0, 0);
        HFONT hOldFont = hFont != NULL ? (HFONT)SelectObject(hDC, hFont) : NULL;
        WCHAR text[512];
        int len = GetWindowTextW(hWnd, text, _countof(text));
        TEXTMETRIC tm;
        GetTextMetrics(hDC, &tm);
        // classic geometry: the frame's top edge runs through the label middle
        RECT frame = r;
        frame.top += tm.tmHeight / 2 - 1;
        ThemeDrawEdge(hDC, &frame, EDGE_ETCHED, BF_RECT);
        if (len > 0)
        {
            SIZE textSize;
            GetTextExtentPoint32W(hDC, text, len, &textSize);
            RECT tr;
            tr.left = r.left + 9;
            tr.top = r.top;
            tr.right = tr.left + textSize.cx + 2;
            if (tr.right > r.right - 9)
                tr.right = r.right - 9;
            tr.bottom = tr.top + tm.tmHeight;
            // opaque face background covers the frame line behind the label
            FillRect(hDC, &tr, ThemeSysColorBrush(COLOR_BTNFACE));
            int oldBkMode = SetBkMode(hDC, TRANSPARENT);
            COLORREF oldClr = SetTextColor(hDC, ThemeSysColor(IsWindowEnabled(hWnd) ? COLOR_BTNTEXT : COLOR_GRAYTEXT));
            UINT dt = DT_SINGLELINE | DT_LEFT;
            if (SendMessage(hWnd, WM_QUERYUISTATE, 0, 0) & UISF_HIDEACCEL)
                dt |= DT_HIDEPREFIX;
            RECT dr = tr;
            dr.left += 1;
            DrawTextW(hDC, text, len, &dr, dt);
            SetTextColor(hDC, oldClr);
            SetBkMode(hDC, oldBkMode);
        }
        if (hOldFont != NULL)
            SelectObject(hDC, hOldFont);
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeGroupBoxSubclassProc, 6);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// Classic radio buttons take their label color from WM_CTLCOLORSTATIC (that
// is why 036 stripped their visual style), but the glyph itself is drawn by
// DrawFrameControl with real system colors - a white circle on the dark
// face (feature 049). Render the classic paint into a memory DC and overlay
// just the glyph square with a dark-drawn radio; label, focus rectangle and
// prefix rendering stay pixel-native. The Default theme passes through.
static LRESULT CALLBACK ThemeRadioGlyphSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                    LPARAM lParam, UINT_PTR uIdSubclass,
                                                    DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_ERASEBKGND:
    {
        if (!IsDarkThemeActive())
            break;
        return TRUE; // WM_PAINT covers the whole client area
    }

    case WM_PAINT:
    {
        if (!IsDarkThemeActive())
            break; // normal drawing

        DWORD fullStyle = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE);
        if (fullStyle & BS_PUSHLIKE)
            break; // push-like radios render as buttons - no glyph to overlay

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        int w = r.right;
        int h = r.bottom;
        if (w > 0 && h > 0)
        {
            HDC memDC = HANDLES(CreateCompatibleDC(hDC));
            HBITMAP hBmp = HANDLES(CreateCompatibleBitmap(hDC, w, h));
            if (memDC != NULL && hBmp != NULL)
            {
                HBITMAP hOldBmp = (HBITMAP)SelectObject(memDC, hBmp);
                // classic button paint does not erase: fill the face first;
                // the label colors then come from the parent's
                // WM_CTLCOLORSTATIC (already dark) during WM_PRINTCLIENT
                FillRect(memDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));
                DefSubclassProc(hWnd, WM_PRINTCLIENT, (WPARAM)memDC, PRF_CLIENT);

                // overlay the glyph square with a dark-drawn radio
                int g = MulDiv(13, GetDeviceCaps(hDC, LOGPIXELSY), 96);
                if (g > h)
                    g = h;
                DWORD style = (DWORD)GetWindowLongPtr(hWnd, GWL_STYLE);
                RECT gr;
                gr.left = (style & BS_LEFTTEXT) ? w - g : 0;
                gr.top = (h - g) / 2;
                gr.right = gr.left + g;
                gr.bottom = gr.top + g;
                FillRect(memDC, &gr, ThemeSysColorBrush(COLOR_BTNFACE));
                BOOL enabled = IsWindowEnabled(hWnd);
                BOOL checked = (SendMessage(hWnd, BM_GETCHECK, 0, 0) & BST_CHECKED) != 0;
                HPEN ring = HANDLES(CreatePen(PS_SOLID, 1, ThemeSysColor(COLOR_GRAYTEXT)));
                HBRUSH interior = ThemeSysColorBrush(enabled ? COLOR_WINDOW : COLOR_BTNFACE);
                if (ring != NULL)
                {
                    HPEN hOldPen = (HPEN)SelectObject(memDC, ring);
                    HBRUSH hOldBrush = (HBRUSH)SelectObject(memDC, interior);
                    Ellipse(memDC, gr.left + 1, gr.top + 1, gr.right - 1, gr.bottom - 1);
                    if (checked)
                    {
                        HBRUSH dot = ThemeSysColorBrush(enabled ? COLOR_BTNTEXT : COLOR_GRAYTEXT);
                        RECT dr = gr;
                        InflateRect(&dr, -(g / 3), -(g / 3));
                        SelectObject(memDC, dot);
                        HPEN dotPen = HANDLES(CreatePen(PS_SOLID, 1, ThemeSysColor(enabled ? COLOR_BTNTEXT : COLOR_GRAYTEXT)));
                        if (dotPen != NULL)
                        {
                            SelectObject(memDC, dotPen);
                            Ellipse(memDC, dr.left, dr.top, dr.right, dr.bottom);
                            SelectObject(memDC, hOldPen);
                            HANDLES(DeleteObject(dotPen));
                        }
                    }
                    SelectObject(memDC, hOldPen);
                    SelectObject(memDC, hOldBrush);
                    HANDLES(DeleteObject(ring));
                }
                BitBlt(hDC, 0, 0, w, h, memDC, 0, 0, SRCCOPY);
                SelectObject(memDC, hOldBmp);
            }
            if (hBmp != NULL)
                HANDLES(DeleteObject(hBmp));
            if (memDC != NULL)
                HANDLES(DeleteDC(memDC));
        }
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeRadioGlyphSubclassProc, 7);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// SysDateTimePick32 and msctls_hotkey32 have no dark visual-style class and
// their classic fallback still paints with real system colors. A full owner
// redraw would lose the date picker's per-segment edit highlight (a
// functional cue), so instead the native rendering is captured into a DIB
// and its grayscale pixels are remapped (white -> dark field, black ->
// light text); strongly chromatic pixels - the blue segment selection - are
// preserved (feature 049). The Default theme passes through.
static LRESULT CALLBACK ThemeGrayscaleRemapSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                        LPARAM lParam, UINT_PTR uIdSubclass,
                                                        DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_ERASEBKGND:
    {
        if (!IsDarkThemeActive())
            break;
        return TRUE; // WM_PAINT covers the whole client area
    }

    case WM_NCPAINT:
    {
        // the WS_EX_CLIENTEDGE border is non-client - the client remap below
        // never touches it and it stays light (hotkey control in the Plugin
        // Keyboard Shortcuts dialog); redraw it with the dark bevel pair
        // (the 044 Find WM_NCPAINT precedent)
        if (!IsDarkThemeActive())
            break;
        DWORD exStyle = (DWORD)GetWindowLongPtr(hWnd, GWL_EXSTYLE);
        if ((exStyle & WS_EX_CLIENTEDGE) == 0)
            break;
        HDC hDC = GetWindowDC(hWnd);
        if (hDC != NULL)
        {
            RECT r;
            GetWindowRect(hWnd, &r);
            OffsetRect(&r, -r.left, -r.top);
            ThemeDrawEdge(hDC, &r, EDGE_SUNKEN, BF_RECT);
            ReleaseDC(hWnd, hDC);
        }
        return 0;
    }

    case WM_PAINT:
    {
        if (!IsDarkThemeActive())
            break; // normal drawing

        PAINTSTRUCT ps;
        HDC hDC = BeginPaint(hWnd, &ps);
        RECT r;
        GetClientRect(hWnd, &r);
        int w = r.right;
        int h = r.bottom;
        if (w > 0 && h > 0)
        {
            BITMAPINFO bi;
            memset(&bi, 0, sizeof(bi));
            bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            bi.bmiHeader.biWidth = w;
            bi.bmiHeader.biHeight = -h; // top-down
            bi.bmiHeader.biPlanes = 1;
            bi.bmiHeader.biBitCount = 32;
            bi.bmiHeader.biCompression = BI_RGB;
            void* bits = NULL;
            HDC memDC = HANDLES(CreateCompatibleDC(hDC));
            HBITMAP hDib = HANDLES(CreateDIBSection(hDC, &bi, DIB_RGB_COLORS, &bits, NULL, 0));
            if (memDC != NULL && hDib != NULL && bits != NULL)
            {
                HBITMAP hOldBmp = (HBITMAP)SelectObject(memDC, hDib);
                // the native painter assumes the light window background
                FillRect(memDC, &r, (HBRUSH)GetStockObject(WHITE_BRUSH));
                DefSubclassProc(hWnd, WM_PRINTCLIENT, (WPARAM)memDC, PRF_CLIENT);
                GdiFlush();

                COLORREF fieldC = ThemeSysColor(COLOR_WINDOW);
                COLORREF textC = ThemeSysColor(COLOR_WINDOWTEXT);
                int field = GetRValue(fieldC); // both palette entries are gray
                int text = GetRValue(textC);
                DWORD* px = (DWORD*)bits;
                int count = w * h;
                int i;
                for (i = 0; i < count; i++)
                {
                    DWORD p = px[i];
                    int pr = (int)((p >> 16) & 0xFF);
                    int pg = (int)((p >> 8) & 0xFF);
                    int pb = (int)(p & 0xFF);
                    int maxc = pr > pg ? (pr > pb ? pr : pb) : (pg > pb ? pg : pb);
                    int minc = pr < pg ? (pr < pb ? pr : pb) : (pg < pb ? pg : pb);
                    // keep strongly chromatic pixels (segment selection);
                    // weakly tinted ClearType fringes are remapped smoothly
                    if (maxc - minc > 64)
                        continue;
                    int v = (pr + pg + pb) / 3;
                    int nv = text + MulDiv(v, field - text, 255);
                    px[i] = ((DWORD)nv << 16) | ((DWORD)nv << 8) | (DWORD)nv;
                }
                BitBlt(hDC, 0, 0, w, h, memDC, 0, 0, SRCCOPY);
                SelectObject(memDC, hOldBmp);
            }
            if (hDib != NULL)
                HANDLES(DeleteObject(hDib));
            if (memDC != NULL)
                HANDLES(DeleteDC(memDC));
        }
        EndPaint(hWnd, &ps);
        return 0;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeGrayscaleRemapSubclassProc, 8);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

LRESULT ThemePaintDarkHeaderItem(HWND hHeader, LPNMCUSTOMDRAW cd)
{
    HDC hDC = cd->hdc;
    RECT r = cd->rc;

    // background: the header's own (dark) theme part, so hover and
    // pressed states match the default-painted area past the last column
    int state = HIS_NORMAL;
    if (cd->uItemState & CDIS_SELECTED)
        state = HIS_PRESSED;
    else if (cd->uItemState & CDIS_HOT)
        state = HIS_HOT;
    HTHEME hTheme = OpenThemeData(hHeader, L"Header");
    if (hTheme != NULL)
    {
        DrawThemeBackground(hTheme, hDC, HP_HEADERITEM, state, &r, NULL);
        CloseThemeData(hTheme);
    }
    else
        FillRect(hDC, &r, ThemeSysColorBrush(COLOR_BTNFACE));

    WCHAR text[260];
    text[0] = 0;
    HDITEMW hdi;
    memset(&hdi, 0, sizeof(hdi));
    hdi.mask = HDI_TEXT | HDI_FORMAT;
    hdi.pszText = text;
    hdi.cchTextMax = _countof(text);
    SendMessage(hHeader, HDM_GETITEMW, cd->dwItemSpec, (LPARAM)&hdi);

    HFONT hFont = (HFONT)SendMessage(hHeader, WM_GETFONT, 0, 0);
    HFONT hOldFont = hFont != NULL ? (HFONT)SelectObject(hDC, hFont) : NULL;
    int oldBkMode = SetBkMode(hDC, TRANSPARENT);
    COLORREF textClr = ThemeSysColor(COLOR_BTNTEXT);
    COLORREF oldClr = SetTextColor(hDC, textClr);
    RECT tr = r;
    tr.left += 6;
    tr.right -= 6;
    UINT dt = DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS;
    if ((hdi.fmt & HDF_JUSTIFYMASK) == HDF_RIGHT)
        dt |= DT_RIGHT;
    else if ((hdi.fmt & HDF_JUSTIFYMASK) == HDF_CENTER)
        dt |= DT_CENTER;
    DrawTextW(hDC, text, -1, &tr, dt);

    // feature 407: the sort arrow the default painting drew - a chevron at the
    // top centre, as Windows draws it in the light theme, in the label colour
    if (hdi.fmt & (HDF_SORTUP | HDF_SORTDOWN))
    {
        TEXTMETRICW tm;
        int fontHeight = GetTextMetricsW(hDC, &tm) ? tm.tmHeight : 16;
        CSalArrowPoints ap;
        if (SalSortArrowChevron(r.left, r.top, r.right, r.bottom, fontHeight, (hdi.fmt & HDF_SORTUP) != 0, &ap))
        {
            POINT pts[3];
            for (int i = 0; i < 3; i++)
            {
                pts[i].x = ap.X[i];
                pts[i].y = ap.Y[i];
            }
            HPEN pen = CreatePen(PS_SOLID, 1, textClr);
            if (pen != NULL)
            {
                HPEN oldPen = (HPEN)SelectObject(hDC, pen);
                Polyline(hDC, pts, 3);
                SetPixel(hDC, pts[2].x, pts[2].y, textClr); // Polyline leaves out the last point
                SelectObject(hDC, oldPen);
                DeleteObject(pen);
            }
        }
    }

    SetTextColor(hDC, oldClr);
    SetBkMode(hDC, oldBkMode);
    if (hOldFont != NULL)
        SelectObject(hDC, hOldFont);
    return CDRF_SKIPDEFAULT;
}

// The DarkMode_ItemsView header paints a dark background but keeps the light
// theme's BLACK label text (the app deliberately avoids the undocumented
// SetPreferredAppMode), so every listview header rendered "Name"/"Hot Key"
// etc. unreadably dark-on-dark. 044 fixed this for the Find window only, via
// its parent's NM_CUSTOMDRAW; feature 049 centralizes the same recipe: the
// listview (the header's parent) is subclassed and answers the header's
// NM_CUSTOMDRAW with a light-text repaint. The Default theme passes through.
static LRESULT CALLBACK ThemeListViewHeaderSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                        LPARAM lParam, UINT_PTR uIdSubclass,
                                                        DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_NOTIFY:
    {
        if (!IsDarkThemeActive())
            break;
        LPNMHDR nmh = (LPNMHDR)lParam;
        HWND hHeader = ListView_GetHeader(hWnd);
        if (hHeader == NULL || nmh->hwndFrom != hHeader || nmh->code != NM_CUSTOMDRAW)
            break;
        LPNMCUSTOMDRAW cd = (LPNMCUSTOMDRAW)lParam;
        if (cd->dwDrawStage == CDDS_PREPAINT)
            return CDRF_NOTIFYITEMDRAW;
        if (cd->dwDrawStage == CDDS_ITEMPREPAINT)
            return ThemePaintDarkHeaderItem(nmh->hwndFrom, cd);
        return CDRF_DODEFAULT;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemeListViewHeaderSubclassProc, 9);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

static BOOL CALLBACK ThemeApplyChildEnumProc(HWND hChild, LPARAM lParam)
{
    BOOL dark = (BOOL)lParam;
    char className[64];
    if (GetClassNameA(hChild, className, _countof(className)) == 0)
        return TRUE;

    if (_stricmp(className, "Button") == 0)
    {
        // the DarkMode_Explorer Button theme renders push buttons and
        // checkboxes with light label text, but radio buttons and group
        // boxes keep the theme's black text (unreadable on the dark
        // background) - strip those to classic drawing, which honors the
        // WM_CTLCOLORSTATIC text color from ThemeHandleCtlColor
        DWORD type = (DWORD)GetWindowLongPtr(hChild, GWL_STYLE) & BS_TYPEMASK;
        if (type == BS_RADIOBUTTON || type == BS_AUTORADIOBUTTON || type == BS_GROUPBOX)
        {
            SetWindowTheme(hChild, dark ? L"" : NULL, dark ? L"" : NULL);
            // classic drawing gets the label color right but paints its
            // chrome (etched frame / radio glyph) with real system colors -
            // repaint those parts dark (see the subclasses above)
            if (type == BS_GROUPBOX)
            {
                if (dark)
                    SetWindowSubclass(hChild, ThemeGroupBoxSubclassProc, 6, 0);
                else
                    RemoveWindowSubclass(hChild, ThemeGroupBoxSubclassProc, 6);
            }
            else
            {
                if (dark)
                    SetWindowSubclass(hChild, ThemeRadioGlyphSubclassProc, 7, 0);
                else
                    RemoveWindowSubclass(hChild, ThemeRadioGlyphSubclassProc, 7);
            }
        }
        else
            SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : NULL, NULL);
    }
    else if (_stricmp(className, "Edit") == 0)
    {
        // DarkMode_CFD keeps the edit border dark - DarkMode_Explorer has no
        // dark Edit border part and falls back to the light frame (feature
        // 044; same class the command line and the combo boxes already use).
        // Edits with their own scrollbars keep DarkMode_Explorer, which is
        // the class that darkens scrollbars.
        DWORD editStyle = (DWORD)GetWindowLongPtr(hChild, GWL_STYLE);
        if (editStyle & (WS_VSCROLL | WS_HSCROLL))
            SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : NULL, NULL);
        else
            SetWindowTheme(hChild, dark ? L"DarkMode_CFD" : NULL, NULL);
        // flat repaint of disabled edits (see the subclass above); inert
        // while the control is enabled or Default is active
        if (dark)
            SetWindowSubclass(hChild, ThemeFlatDisabledEditSubclassProc, 4, 0);
        else
            RemoveWindowSubclass(hChild, ThemeFlatDisabledEditSubclassProc, 4);
    }
    else if (_stricmp(className, "ListBox") == 0 ||
             _stricmp(className, "ScrollBar") == 0)
    {
        SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : NULL, NULL);
    }
    else if (_stricmp(className, "Static") == 0)
    {
        DWORD type = (DWORD)GetWindowLongPtr(hChild, GWL_STYLE) & SS_TYPEMASK;
        if (type == SS_ETCHEDHORZ || type == SS_ETCHEDVERT || type == SS_ETCHEDFRAME)
        {
            // etched separator lines self-draw with real 3D system colors;
            // repaint them with the dark bevel pair (see the subclass above)
            if (dark)
                SetWindowSubclass(hChild, ThemeEtchedLineSubclassProc, 3, 0);
            else
                RemoveWindowSubclass(hChild, ThemeEtchedLineSubclassProc, 3);
        }
        else
        {
            // flat repaint of disabled labels (see the subclass above); the
            // subclass is inert while the control is enabled or Default is active
            if (dark)
                SetWindowSubclass(hChild, ThemeFlatDisabledTextSubclassProc, 2, 0);
            else
                RemoveWindowSubclass(hChild, ThemeFlatDisabledTextSubclassProc, 2);
        }
    }
    else if (_stricmp(className, "msctls_statusbar32") == 0)
    {
        // dark repaint of the whole status bar (see the subclass above);
        // pure passthrough while Default is active
        if (dark)
            SetWindowSubclass(hChild, ThemeStatusBarSubclassProc, 5, 0);
        else
            RemoveWindowSubclass(hChild, ThemeStatusBarSubclassProc, 5);
    }
    else if (_stricmp(className, "ComboBox") == 0 ||
             _stricmp(className, "ComboBoxEx32") == 0)
    {
        SetWindowTheme(hChild, dark ? L"DarkMode_CFD" : NULL, NULL);
    }
    else if (_stricmp(className, "SysDateTimePick32") == 0 ||
             _stricmp(className, "msctls_hotkey32") == 0)
    {
        // no dark visual-style class exists for these controls; repaint by
        // grayscale remap of the native rendering (see the subclass above)
        if (dark)
            SetWindowSubclass(hChild, ThemeGrayscaleRemapSubclassProc, 8, 0);
        else
            RemoveWindowSubclass(hChild, ThemeGrayscaleRemapSubclassProc, 8);
    }
    else if (_stricmp(className, "msctls_progress32") == 0)
    {
        // the themed progress bar ignores PBM_SETBKCOLOR/PBM_SETBARCOLOR;
        // strip its visual style in the dark theme so the classic renderer
        // honors the dark track/bar colors (the 044 Find recipe, central
        // since 049); the Default theme restores the native themed look
        if (dark)
        {
            SetWindowTheme(hChild, L"", L"");
            SendMessage(hChild, PBM_SETBKCOLOR, 0, (LPARAM)ThemeSysColor(COLOR_BTNSHADOW));
            SendMessage(hChild, PBM_SETBARCOLOR, 0, (LPARAM)ThemeSysColor(COLOR_HIGHLIGHT));
        }
        else
        {
            SetWindowTheme(hChild, NULL, NULL);
            SendMessage(hChild, PBM_SETBKCOLOR, 0, (LPARAM)CLR_DEFAULT);
            SendMessage(hChild, PBM_SETBARCOLOR, 0, (LPARAM)CLR_DEFAULT);
        }
    }
    else if (_stricmp(className, WC_LISTVIEWA) == 0)
    {
        SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : NULL, NULL);
        COLORREF bk = dark ? ThemeSysColor(COLOR_WINDOW) : GetSysColor(COLOR_WINDOW);
        COLORREF tx = dark ? ThemeSysColor(COLOR_WINDOWTEXT) : GetSysColor(COLOR_WINDOWTEXT);
        ListView_SetBkColor(hChild, bk);
        ListView_SetTextBkColor(hChild, bk);
        ListView_SetTextColor(hChild, tx);
        HWND hHeader = ListView_GetHeader(hChild);
        if (hHeader != NULL)
        {
            SetWindowTheme(hHeader, dark ? L"DarkMode_ItemsView" : NULL, NULL);
            // the DarkMode_ItemsView header keeps black label text; repaint
            // the labels via the header's NM_CUSTOMDRAW answered at the
            // listview level (see the subclass above)
            if (dark)
                SetWindowSubclass(hChild, ThemeListViewHeaderSubclassProc, 9, 0);
            else
                RemoveWindowSubclass(hChild, ThemeListViewHeaderSubclassProc, 9);
            InvalidateRect(hHeader, NULL, TRUE);
        }
        // the native LVS_EX_CHECKBOXES state glyphs are light-theme bitmaps;
        // swap in the theme-aware generated pair (feature 049). Only dark
        // installs it and only a previously darkened listview is restored,
        // so a light-theme run never touches native state (passthrough).
        // The listview owns and destroys the current state image list at
        // window destruction (no LVS_SHAREIMAGELISTS anywhere).
        if (ListView_GetExtendedListViewStyle(hChild) & LVS_EX_CHECKBOXES)
        {
            if (dark)
            {
                if (GetPropA(hChild, THEME_DARKCHK_PROP) == NULL)
                {
                    HIMAGELIST hIL = CreateCheckboxImagelist(IconSizes[ICONSIZE_16]);
                    if (hIL != NULL)
                    {
                        HIMAGELIST hOld = ListView_SetImageList(hChild, hIL, LVSIL_STATE);
                        if (hOld != NULL)
                            ImageList_Destroy(hOld); // detached native list
                        SetPropA(hChild, THEME_DARKCHK_PROP, (HANDLE)1);
                    }
                }
            }
            else if (GetPropA(hChild, THEME_DARKCHK_PROP) != NULL)
            {
                // regenerate light glyphs without re-toggling the extended
                // style (a style toggle would reset the item check states)
                HIMAGELIST hIL = CreateCheckboxImagelist(IconSizes[ICONSIZE_16]);
                if (hIL != NULL)
                {
                    HIMAGELIST hOld = ListView_SetImageList(hChild, hIL, LVSIL_STATE);
                    if (hOld != NULL)
                        ImageList_Destroy(hOld); // our dark list
                    RemovePropA(hChild, THEME_DARKCHK_PROP);
                }
            }
        }
    }
    else if (_stricmp(className, WC_TREEVIEWA) == 0)
    {
        SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : L"Explorer", NULL);
        TreeView_SetBkColor(hChild, dark ? ThemeSysColor(COLOR_WINDOW) : (COLORREF)-1);
        TreeView_SetTextColor(hChild, dark ? ThemeSysColor(COLOR_WINDOWTEXT) : (COLORREF)-1);
    }
    else if (_stricmp(className, WC_HEADERA) == 0)
    {
        SetWindowTheme(hChild, dark ? L"DarkMode_ItemsView" : NULL, NULL);
    }
    else
    {
        // custom windows with standard (non-client) scrollbars - panels,
        // viewers, edit-list boxes: the DarkMode_Explorer theme darkens the
        // scrollbars without touching the self-painted client area
        DWORD style = (DWORD)GetWindowLongPtr(hChild, GWL_STYLE);
        if (style & (WS_VSCROLL | WS_HSCROLL))
            SetWindowTheme(hChild, dark ? L"DarkMode_Explorer" : NULL, NULL);
    }
    InvalidateRect(hChild, NULL, TRUE);
    return TRUE;
}

void ThemeApplyToDialog(HWND hDialog)
{
    if (hDialog == NULL)
        return;
    BOOL dark = IsDarkThemeActive();
    if (!dark && GetPropA(hDialog, THEME_DARKENED_PROP) == NULL)
        return; // Default theme + never darkened: strict no-op (passthrough)

    ThemeApplyToTopLevel(hDialog);
    EnumChildWindows(hDialog, ThemeApplyChildEnumProc, (LPARAM)dark);
    if (dark)
        SetPropA(hDialog, THEME_DARKENED_PROP, (HANDLE)1);
    else
        RemovePropA(hDialog, THEME_DARKENED_PROP);
    InvalidateRect(hDialog, NULL, TRUE);
}

void ThemeApplyToWindowTree(HWND hWnd)
{
    if (hWnd == NULL || !IsDarkThemeActive())
        return; // freshly created controls are native in the Default theme;
                // live switches restore through ThemeApplyToDialog (which
                // tracks THEME_DARKENED_PROP), so light stays a pure no-op

    ThemeApplyChildEnumProc(hWnd, (LPARAM)TRUE);
    EnumChildWindows(hWnd, ThemeApplyChildEnumProc, (LPARAM)TRUE);
}

void ThemeApplyToTooltip(HWND hTooltip)
{
    if (hTooltip == NULL)
        return;
    if (IsDarkThemeActive())
    {
        // the themed tooltip ignores TTM_SETTIP*COLOR; strip its visual
        // style so the classic renderer honors the dark info colors
        SetWindowTheme(hTooltip, L"", L"");
        SendMessage(hTooltip, TTM_SETTIPBKCOLOR, (WPARAM)ThemeSysColor(COLOR_INFOBK), 0);
        SendMessage(hTooltip, TTM_SETTIPTEXTCOLOR, (WPARAM)ThemeSysColor(COLOR_INFOTEXT), 0);
    }
    else
    {
        SetWindowTheme(hTooltip, NULL, NULL);
        SendMessage(hTooltip, TTM_SETTIPBKCOLOR, (WPARAM)GetSysColor(COLOR_INFOBK), 0);
        SendMessage(hTooltip, TTM_SETTIPTEXTCOLOR, (WPARAM)GetSysColor(COLOR_INFOTEXT), 0);
    }
}

BOOL ThemeHandleCtlColor(UINT uMsg, WPARAM wParam, LPARAM lParam, INT_PTR* result)
{
    if (!IsDarkThemeActive())
        return FALSE;

    HDC hDC = (HDC)wParam;
    switch (uMsg)
    {
    case WM_CTLCOLORDLG:
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLORBTN:
    {
        SetTextColor(hDC, ThemeSysColor(COLOR_BTNTEXT));
        SetBkColor(hDC, ThemeSysColor(COLOR_BTNFACE));
        *result = (INT_PTR)ThemeSysColorBrush(COLOR_BTNFACE);
        return TRUE;
    }

    case WM_CTLCOLOREDIT:
    case WM_CTLCOLORLISTBOX:
    {
        SetTextColor(hDC, ThemeSysColor(COLOR_WINDOWTEXT));
        SetBkColor(hDC, ThemeSysColor(COLOR_WINDOW));
        *result = (INT_PTR)ThemeSysColorBrush(COLOR_WINDOW);
        return TRUE;
    }

    case WM_CTLCOLORSCROLLBAR:
    {
        *result = (INT_PTR)ThemeSysColorBrush(COLOR_BTNFACE);
        return TRUE;
    }
    }
    return FALSE;
}

//
// ****************************************************************************
// ThemeAdjustBitmapForDarkMode
//

void ThemeAdjustBitmapForDarkMode(HBITMAP hBitmap, COLORREF transparent)
{
    if (!IsDarkThemeActive() || hBitmap == NULL)
        return;
    // feature 427: the bitmap walk is header-only (src/common/themes_bitmap.h) so that the
    // plug-ins' legacy toolbars get the same Dark adaptation without an interface change
    ThemeDarkAdaptBitmap(hBitmap, transparent);
}

//
// ****************************************************************************
// Property-sheet frame subclass
//

static LRESULT CALLBACK ThemePropSheetFrameSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam,
                                                        LPARAM lParam, UINT_PTR uIdSubclass,
                                                        DWORD_PTR dwRefData)
{
    switch (uMsg)
    {
    case WM_CTLCOLORDLG:
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLORBTN:
    case WM_CTLCOLOREDIT:
    case WM_CTLCOLORLISTBOX:
    case WM_CTLCOLORSCROLLBAR:
    {
        INT_PTR result;
        if (ThemeHandleCtlColor(uMsg, wParam, lParam, &result))
            return result;
        break;
    }

    case WM_ERASEBKGND:
    {
        if (IsDarkThemeActive())
        {
            RECT r;
            GetClientRect(hWnd, &r);
            FillRect((HDC)wParam, &r, ThemeSysColorBrush(COLOR_BTNFACE));
            return TRUE;
        }
        break;
    }

    case WM_NCDESTROY:
    {
        RemoveWindowSubclass(hWnd, ThemePropSheetFrameSubclassProc, 1);
        break;
    }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

void ThemeSubclassPropSheetFrame(HWND hFrame)
{
    if (hFrame == NULL)
        return;
    if (!IsDarkThemeActive() && GetPropA(hFrame, THEME_DARKENED_PROP) == NULL)
        return;                                                       // strict Default-theme passthrough
    SetWindowSubclass(hFrame, ThemePropSheetFrameSubclassProc, 1, 0); // idempotent
    ThemeApplyToDialog(hFrame);                                       // DWM title bar + tree/buttons/tab children
}

//
// ****************************************************************************
// SetThemeMode
//

void SetThemeMode(DWORD mode)
{
    CALL_STACK_MESSAGE2("SetThemeMode(%u)", mode);
    if (mode != THEME_MODE_DARK)
        mode = THEME_MODE_DEFAULT; // forward compatibility: unknown -> Default
    if ((DWORD)Configuration.ThemeMode == mode)
        return;

    Configuration.ThemeMode = mode;
    RefreshThemeHighContrastState();
    UpdateCurrentColorsForTheme();

    if (MainWindow != NULL && MainWindow->HWindow != NULL)
        ThemeUpdateWindowClassBackground(MainWindow->HWindow, COLOR_WINDOW);

    // the standard color-change pipeline: rebuilds brushes/pens/toolbar
    // bitmaps and notifies panels, Find windows, viewers and plugins
    ColorsChanged(TRUE, FALSE, TRUE);

    if (MainWindow != NULL && MainWindow->HWindow != NULL)
    {
        // re-insert the rebar bands (since feature 418 their grips are the same
        // in both themes - Dark repaints their light middle, ThemeRebarCustomDraw -
        // but a fresh insertion keeps the layout equal to a start in this theme)
        if (MainWindow->HTopRebar != NULL)
            MainWindow->RebuildRebarBands();
        // DWM title bar + per-child theming (scrollbars, combos, ...)
        ThemeApplyToDialog(MainWindow->HWindow);
        // let DWM redraw the frame with the new caption color
        SetWindowPos(MainWindow->HWindow, NULL, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        RedrawWindow(MainWindow->HWindow, NULL, NULL,
                     RDW_ERASE | RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    }
}
