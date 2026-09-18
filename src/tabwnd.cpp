// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include "cfgdlg.h"
#include "mainwnd.h"
#include "toolbar.h"
#include "stswnd.h"
#include "plugins.h"
#include "fileswnd.h"
#include "tabwnd.h"
#include "menu.h"
#include "gui.h"
#include "svg.h"
#include "themes.h"

//
// ****************************************************************************
// CTabWindow
//

// pixel metrics at 100 % scale
#define TABSTRIP_PAD 4    // text inset inside a tab
#define TABSTRIP_GLYPH 8  // size of the close / plus glyph box
#define TABSTRIP_BAND 2   // extra band above the tab row
#define TABSTRIP_MIN_CHARS 6
#define TABSTRIP_MAX_CHARS 20

#define TABSTRIP_TT_PLUS 1
#define TABSTRIP_TT_LIST 2
#define TABSTRIP_TT_TAB 100

static int TabStripScaled(int px)
{
    return MulDiv(px, GetScaleForSystemDPI(), 100);
}

CTabWindow::CTabWindow(CFilesWindow* filesWindow) : CWindow(ooStatic)
{
    CALL_STACK_MESSAGE_NONE
    FilesWindow = filesWindow;
    Width = 0;
    Height = 0;
    AvgCharWidth = 0;
    HotIndex = -1;
    HotPart = tspNone;
    MouseIsTracked = FALSE;
    FirstVisible = 0;
    VisibleCount = 0;
    TabWidth = 0;
    TabsLeft = 1;
    ListButtonVisible = FALSE;
    SetRectEmpty(&PlusRect);
    SetRectEmpty(&ListRect);
    WaitForDrag = FALSE;
    Dragging = FALSE;
    DragAnchor.x = DragAnchor.y = 0;
    DragIndex = -1;
    InsertIndex = -1;
    MButtonDownIndex = -1;
    MeasureFont();
}

CTabWindow::~CTabWindow()
{
    CALL_STACK_MESSAGE1("CTabWindow::~CTabWindow()");
}

void CTabWindow::MeasureFont()
{
    AvgCharWidth = 0;
    HDC dc = HANDLES(GetDC(NULL));
    if (dc != NULL)
    {
        HFONT oldFont = (HFONT)SelectObject(dc, EnvFont);
        TEXTMETRIC tm;
        if (GetTextMetrics(dc, &tm))
            AvgCharWidth = tm.tmAveCharWidth;
        SelectObject(dc, oldFont);
        HANDLES(ReleaseDC(NULL, dc));
    }
    if (AvgCharWidth <= 0)
        AvgCharWidth = max(4, EnvFontCharHeight / 2);
}

void CTabWindow::DestroyWindow()
{
    CALL_STACK_MESSAGE1("CTabWindow::DestroyWindow()");
    if (HWindow != NULL)
        ::DestroyWindow(HWindow);
}

int CTabWindow::GetNeededHeight()
{
    CALL_STACK_MESSAGE_NONE
    return 2 + EnvFontCharHeight + 2 + TabStripScaled(TABSTRIP_BAND);
}

void CTabWindow::InvalidateAndUpdate(BOOL update)
{
    CALL_STACK_MESSAGE_NONE
    if (HWindow == NULL)
        return;
    InvalidateRect(HWindow, NULL, FALSE);
    if (update)
        UpdateWindow(HWindow);
}

void CTabWindow::Repaint()
{
    CALL_STACK_MESSAGE_NONE
    if (HWindow == NULL)
        return;
    HDC hdc = HANDLES(GetDC(HWindow));
    Paint(hdc);
    HANDLES(ReleaseDC(HWindow, hdc));
}

void CTabWindow::SetFont()
{
    MeasureFont();
    if (HWindow != NULL)
        InvalidateRect(HWindow, NULL, TRUE);
}

void CTabWindow::OnColorsChanged()
{
    InvalidateAndUpdate(FALSE);
}

//
// ****************************************************************************
// layout and hit testing
//

void CTabWindow::Layout()
{
    int count = FilesWindow->Tabs.Count();
    int pad = TabStripScaled(TABSTRIP_PAD);
    int glyph = TabStripScaled(TABSTRIP_GLYPH);
    int btnW = Height; // square buttons
    int minW = TABSTRIP_MIN_CHARS * AvgCharWidth + 2 * pad + glyph;
    int maxW = TABSTRIP_MAX_CHARS * AvgCharWidth + 2 * pad + glyph;

    TabsLeft = 1;
    ListButtonVisible = FALSE;
    VisibleCount = count;
    TabWidth = 0;
    ListRect.left = Width - btnW - 1;
    ListRect.right = Width - 1;
    ListRect.top = 1;
    ListRect.bottom = Height - 1;

    if (count > 0 && Width > 0)
    {
        int available = Width - TabsLeft - btnW - 2; // the "+" follows the last visible tab
        if (available < 0)
            available = 0;
        TabWidth = available / count;
        if (TabWidth > maxW)
            TabWidth = maxW;
        if (TabWidth < minW)
        {
            // not everything fits at the minimum width: show a run around the
            // active tab and the tab-list button
            ListButtonVisible = TRUE;
            int room = available - btnW - 2;
            if (room < 0)
                room = 0;
            TabWidth = minW;
            VisibleCount = room / minW;
            if (VisibleCount < 1)
            {
                VisibleCount = 1;
                TabWidth = max(room, 3 * AvgCharWidth);
            }
            if (VisibleCount > count)
                VisibleCount = count;
            int active = FilesWindow->Tabs.ActiveIndex;
            if (FirstVisible > count - VisibleCount)
                FirstVisible = count - VisibleCount;
            if (active < FirstVisible)
                FirstVisible = active;
            if (active >= FirstVisible + VisibleCount)
                FirstVisible = active - VisibleCount + 1;
            if (FirstVisible < 0)
                FirstVisible = 0;
        }
        else
            FirstVisible = 0;
    }
    else
        FirstVisible = 0;

    PlusRect.left = TabsLeft + VisibleCount * TabWidth + 2;
    PlusRect.right = PlusRect.left + btnW;
    PlusRect.top = 1;
    PlusRect.bottom = Height - 1;
    int limit = ListButtonVisible ? ListRect.left - 1 : Width - 1;
    if (PlusRect.right > limit)
    {
        PlusRect.right = limit;
        PlusRect.left = max(TabsLeft, limit - btnW);
    }
}

BOOL CTabWindow::GetTabRect(int index, RECT* r)
{
    if (index < FirstVisible || index >= FirstVisible + VisibleCount || TabWidth <= 0)
        return FALSE;
    r->left = TabsLeft + (index - FirstVisible) * TabWidth;
    r->right = r->left + TabWidth - 1;
    r->top = 1;
    r->bottom = Height - 1;
    return TRUE;
}

BOOL CTabWindow::ShowsCloseGlyph(int index)
{
    return FilesWindow->Tabs.Count() > 1 &&
           (index == FilesWindow->Tabs.ActiveIndex || index == HotIndex);
}

BOOL CTabWindow::GetCloseRect(int index, RECT* r)
{
    RECT tab;
    if (!GetTabRect(index, &tab))
        return FALSE;
    int pad = TabStripScaled(TABSTRIP_PAD);
    int glyph = TabStripScaled(TABSTRIP_GLYPH);
    r->right = tab.right - pad;
    r->left = r->right - glyph;
    r->top = (Height - glyph) / 2;
    r->bottom = r->top + glyph;
    if (r->left < tab.left + pad)
        r->left = tab.left + pad;
    return r->left < r->right;
}

int CTabWindow::HitTest(int x, int y, int* part)
{
    *part = tspNone;
    if (y < 0 || y >= Height || x < 0 || x >= Width)
        return -1;
    POINT pt = {x, y};
    if (PtInRect(&PlusRect, pt))
    {
        *part = tspPlus;
        return -1;
    }
    if (ListButtonVisible && PtInRect(&ListRect, pt))
    {
        *part = tspList;
        return -1;
    }
    if (TabWidth > 0 && x >= TabsLeft && x < TabsLeft + VisibleCount * TabWidth)
    {
        int index = FirstVisible + (x - TabsLeft) / TabWidth;
        if (index >= FilesWindow->Tabs.Count())
            return -1;
        RECT cr;
        // the glyph hit test is evaluated for the tab as if it were hot (it becomes hot on hover)
        if (FilesWindow->Tabs.Count() > 1 && GetCloseRect(index, &cr) && PtInRect(&cr, pt))
            *part = tspClose;
        else
            *part = tspTab;
        return index;
    }
    return -1;
}

void CTabWindow::UpdateHot(int x, int y)
{
    int part;
    int index = HitTest(x, y, &part);
    if (index != HotIndex || part != HotPart)
    {
        HotIndex = index;
        HotPart = part;
        if (!MouseIsTracked)
        {
            TRACKMOUSEEVENT tme;
            tme.cbSize = sizeof(tme);
            tme.dwFlags = TME_LEAVE;
            tme.hwndTrack = HWindow;
            TrackMouseEvent(&tme);
            MouseIsTracked = TRUE;
        }
        Repaint();
    }
    DWORD tt = 0;
    if (part == tspPlus)
        tt = TABSTRIP_TT_PLUS;
    else if (part == tspList)
        tt = TABSTRIP_TT_LIST;
    else if (index >= 0)
        tt = TABSTRIP_TT_TAB + index;
    if ((GetKeyState(VK_LBUTTON) & 0x8000) || (GetKeyState(VK_MBUTTON) & 0x8000) ||
        (GetKeyState(VK_RBUTTON) & 0x8000))
        tt = 0; // never fight a gesture with a tooltip
    SetCurrentToolTip(HWindow, tt);
}

void CTabWindow::ResetDrag()
{
    WaitForDrag = FALSE;
    Dragging = FALSE;
    DragIndex = -1;
    InsertIndex = -1;
}

//
// ****************************************************************************
// painting
//

void CTabWindow::DrawGlyphLines(HDC dc, const POINT* pts, int count, COLORREF clr)
{
    HPEN pen = HANDLES(CreatePen(PS_SOLID, max(1, GetScaleForSystemDPI() / 100), clr));
    if (pen == NULL)
        return;
    HPEN oldPen = (HPEN)SelectObject(dc, pen);
    int i;
    for (i = 0; i + 1 < count; i += 2)
    {
        MoveToEx(dc, pts[i].x, pts[i].y, NULL);
        LineTo(dc, pts[i + 1].x, pts[i + 1].y);
    }
    SelectObject(dc, oldPen);
    HANDLES(DeleteObject(pen));
}

void CTabWindow::PaintTab(HDC dc, int index)
{
    RECT r;
    if (!GetTabRect(index, &r))
        return;
    CPanelTab* tab = FilesWindow->Tabs.At(index);
    if (tab == NULL)
        return;
    BOOL active = (index == FilesWindow->Tabs.ActiveIndex);
    BOOL activePanel = (FilesWindow == MainWindow->GetActivePanel()) && MainWindow->CaptionIsActive;
    BOOL hot = (HotIndex == index && HotPart == tspTab);
    int pad = TabStripScaled(TABSTRIP_PAD);
    int glyph = TabStripScaled(TABSTRIP_GLYPH);

    RECT body = r;
    if (active)
        body.bottom = Height; // the active tab joins the directory line below
    else
        body.top += TabStripScaled(TABSTRIP_BAND);
    if (active)
        FillRect(dc, &body, activePanel ? HActiveCaptionBrush : HInactiveCaptionBrush);
    else
        FillRect(dc, &body, ThemeSysColorBrush(COLOR_BTNFACE));
    RECT edge = body;
    ThemeDrawEdge(dc, &edge, BDR_RAISEDINNER, BF_LEFT | BF_TOP | BF_RIGHT);

    COLORREF clr;
    if (active)
    {
        int slot = hot ? (activePanel ? HOT_ACTIVE : HOT_INACTIVE)
                       : (activePanel ? ACTIVE_CAPTION_FG : INACTIVE_CAPTION_FG);
        clr = GetCOLORREF(CurrentColors[slot]);
    }
    else
        clr = hot ? GetCOLORREF(CurrentColors[HOT_PANEL]) : ThemeSysColor(COLOR_BTNTEXT);

    char title[SAL_FIND_NAME_U8];
    SalTabTitleFromLocation(tab->Location, title, sizeof(title));
    RECT tr = body;
    tr.left += pad;
    tr.right -= pad;
    BOOL closeGlyph = ShowsCloseGlyph(index);
    if (closeGlyph)
        tr.right -= glyph + pad;
    if (tr.right > tr.left)
    {
        SetBkMode(dc, TRANSPARENT);
        HFONT oldFont = (HFONT)SelectObject(dc, EnvFont);
        SetTextColor(dc, clr);
        UINT flags = DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX;
        WCHAR* titleW = SalU8ToWAlloc(title, -1); // feature 010: titles are UTF-8 (WTF-8), draw wide
        if (titleW != NULL)
        {
            DrawTextW(dc, titleW, -1, &tr, flags);
            free(titleW);
        }
        else
            DrawText(dc, title, -1, &tr, flags);
        SelectObject(dc, oldFont);
    }

    if (closeGlyph)
    {
        RECT cr;
        if (GetCloseRect(index, &cr))
        {
            BOOL closeHot = (HotIndex == index && HotPart == tspClose);
            COLORREF gc = closeHot ? GetCOLORREF(CurrentColors[active ? (activePanel ? HOT_ACTIVE : HOT_INACTIVE) : HOT_PANEL]) : clr;
            if (!active && !closeHot)
                gc = ThemeSysColor(COLOR_BTNTEXT);
            POINT pts[4] = {{cr.left, cr.top}, {cr.right, cr.bottom}, {cr.left, cr.bottom}, {cr.right, cr.top}};
            DrawGlyphLines(dc, pts, 4, gc);
        }
    }
}

void CTabWindow::PaintPlus(HDC dc)
{
    if (PlusRect.right - PlusRect.left < 4)
        return;
    int glyph = TabStripScaled(TABSTRIP_GLYPH);
    int cx = (PlusRect.left + PlusRect.right) / 2;
    int cy = (PlusRect.top + PlusRect.bottom) / 2;
    int h = glyph / 2;
    BOOL hot = (HotPart == tspPlus);
    COLORREF clr = hot ? GetCOLORREF(CurrentColors[HOT_PANEL]) : ThemeSysColor(COLOR_BTNTEXT);
    POINT pts[4] = {{cx - h, cy}, {cx + h + 1, cy}, {cx, cy - h}, {cx, cy + h + 1}};
    DrawGlyphLines(dc, pts, 4, clr);
}

void CTabWindow::PaintList(HDC dc)
{
    SIZE sz;
    SVGArrowDropDown.GetSize(&sz);
    int x = ListRect.left + (ListRect.right - ListRect.left - sz.cx) / 2;
    int y = ListRect.top + (ListRect.bottom - ListRect.top - sz.cy) / 2;
    SVGArrowDropDown.AlphaBlend(dc, x, y, -1, -1, SVGSTATE_ENABLED);
}

void CTabWindow::PaintInsertMark(HDC dc)
{
    if (InsertIndex < FirstVisible || InsertIndex > FirstVisible + VisibleCount || TabWidth <= 0)
        return;
    int x = TabsLeft + (InsertIndex - FirstVisible) * TabWidth - 1;
    if (x < 0)
        x = 0;
    RECT r = {x, 1, x + 2, Height - 1};
    FillRect(dc, &r, ThemeSysColorBrush(COLOR_BTNTEXT));
}

void CTabWindow::Paint(HDC hdc)
{
    CALL_STACK_MESSAGE1("CTabWindow::Paint()");
    if (Width <= 0 || Height <= 0)
        return;
    HDC dc = ItemBitmap.HMemDC;
    RECT r = {0, 0, Width, Height};
    FillRect(dc, &r, HDialogBrush);

    Layout();

    // the baseline the inactive tabs sit on
    RECT base = {0, Height - 1, Width, Height};
    FillRect(dc, &base, ThemeSysColorBrush(COLOR_BTNSHADOW));

    int i;
    for (i = FirstVisible; i < FirstVisible + VisibleCount; i++)
        if (i != FilesWindow->Tabs.ActiveIndex)
            PaintTab(dc, i);
    PaintTab(dc, FilesWindow->Tabs.ActiveIndex); // last, it overlaps the baseline
    PaintPlus(dc);
    if (ListButtonVisible)
        PaintList(dc);
    if (Dragging)
        PaintInsertMark(dc);

    BitBlt(hdc, 0, 0, Width, Height, dc, 0, 0, SRCCOPY);
}

//
// ****************************************************************************
// mouse
//

void CTabWindow::OnLButtonDown(int x, int y)
{
    int part;
    int index = HitTest(x, y, &part);
    if (part == tspNone)
        return;

    MainWindow->CancelPanelsUI(); // cancel QuickSearch and QuickEdit
    if (GetActiveWindow() == NULL)
        SetForegroundWindow(MainWindow->HWindow);
    // a click on a panel's strip activates that panel (FR-011); the caret stays in its list
    if (MainWindow->GetActivePanel() != FilesWindow && FilesWindow->CanBeFocused())
        MainWindow->ChangePanel();

    switch (part)
    {
    case tspPlus:
        FilesWindow->NewTab();
        break;

    case tspList:
        OpenTabList();
        break;

    case tspClose:
        FilesWindow->CloseTab(index);
        break;

    case tspTab:
    {
        if (index != FilesWindow->Tabs.ActiveIndex)
            FilesWindow->SwitchToTab(index);
        if (FilesWindow->Tabs.Count() > 1 && HWindow != NULL)
        {
            WaitForDrag = TRUE;
            Dragging = FALSE;
            DragAnchor.x = x;
            DragAnchor.y = y;
            DragIndex = index;
            InsertIndex = index;
            SetCapture(HWindow);
        }
        break;
    }
    }
    UpdateHot(x, y);
}

void CTabWindow::OnMouseMove(int x, int y)
{
    if (WaitForDrag)
    {
        int dx = GetSystemMetrics(SM_CXDRAG);
        int dy = GetSystemMetrics(SM_CYDRAG);
        if (dx < 1)
            dx = 1;
        if (dy < 1)
            dy = 1;
        if (x < DragAnchor.x - dx || x > DragAnchor.x + dx || y < DragAnchor.y - dy || y > DragAnchor.y + dy)
        {
            WaitForDrag = FALSE;
            Dragging = TRUE;
            SetCurrentToolTip(NULL, 0);
        }
    }
    if (Dragging)
    {
        int count = FilesWindow->Tabs.Count();
        int idx = InsertIndex;
        if (TabWidth > 0)
        {
            int rel = x - TabsLeft;
            if (rel < 0)
                idx = FirstVisible;
            else
                idx = FirstVisible + (rel + TabWidth / 2) / TabWidth;
            if (idx > FirstVisible + VisibleCount)
                idx = FirstVisible + VisibleCount;
            if (idx > count)
                idx = count;
            if (idx < 0)
                idx = 0;
        }
        if (idx != InsertIndex)
        {
            InsertIndex = idx;
            Repaint();
        }
        return;
    }
    UpdateHot(x, y);
}

void CTabWindow::OnLButtonUp(int x, int y)
{
    if (Dragging)
    {
        int from = DragIndex;
        int to = InsertIndex;
        if (to > from)
            to--;
        ReleaseCapture();
        ResetDrag();
        if (from >= 0 && to >= 0 && to != from)
            FilesWindow->MoveTab(from, to);
        Repaint();
        UpdateHot(x, y);
        return;
    }
    if (WaitForDrag)
    {
        ReleaseCapture();
        ResetDrag();
    }
}

void CTabWindow::OpenTabList()
{
    CALL_STACK_MESSAGE1("CTabWindow::OpenTabList()");
    int count = FilesWindow->Tabs.Count();
    if (count <= 0)
        return;
    BeginStopRefresh(); // no refreshes while the menu is up

    CMenuPopup menu;
    MENU_ITEM_INFO mii;
    mii.Mask = MENU_MASK_TYPE | MENU_MASK_ID | MENU_MASK_STATE | MENU_MASK_STRING;
    mii.Type = MENU_TYPE_STRING;
    int i;
    for (i = 0; i < count; i++)
    {
        CPanelTab* tab = FilesWindow->Tabs.At(i);
        char title[SAL_FIND_NAME_U8];
        SalTabTitleFromLocation(tab != NULL ? tab->Location : "", title, sizeof(title));
        if (title[0] == 0)
            lstrcpyn(title, "?", sizeof(title));
        mii.String = title;
        mii.ID = i + 1;
        mii.State = (i == FilesWindow->Tabs.ActiveIndex) ? MENU_STATE_CHECKED : 0;
        menu.InsertItem(0xffffffff, TRUE, &mii);
    }

    RECT r = ListRect;
    MapWindowPoints(HWindow, NULL, (POINT*)&r, 2);
    DWORD cmd = menu.Track(MENU_TRACK_RETURNCMD | MENU_TRACK_VERTICAL, r.left, r.bottom, HWindow, &r);

    EndStopRefresh();
    HotIndex = -1;
    HotPart = tspNone;
    if (cmd != 0 && (int)cmd - 1 != FilesWindow->Tabs.ActiveIndex)
        FilesWindow->SwitchToTab((int)cmd - 1);
    else
        Repaint();
}

/* used by the export_mnu.py script that generates salmenu.mnu for Translator;
   keep synchronized with the InsertItem() calls in OpenContextMenu()
MENU_TEMPLATE_ITEM TabStripMenu[] =
{
  {MNTT_PB, 0
  {MNTT_IT, IDS_MENU_TAB_NEW
  {MNTT_IT, IDS_MENU_TAB_DUPLICATE
  {MNTT_IT, IDS_MENU_TAB_CLOSE
  {MNTT_IT, IDS_MENU_TAB_CLOSEOTHERS
  {MNTT_IT, IDS_MENU_TAB_CLOSERIGHT
  {MNTT_PE, 0
};
*/

void CTabWindow::OpenContextMenu(int index, int xScreen, int yScreen)
{
    CALL_STACK_MESSAGE2("CTabWindow::OpenContextMenu(%d, , )", index);
    int count = FilesWindow->Tabs.Count();
    BOOL onTab = (index >= 0 && index < count);
    BeginStopRefresh();

    CMenuPopup menu;
    MENU_ITEM_INFO miiSep;
    miiSep.Mask = MENU_MASK_TYPE;
    miiSep.Type = MENU_TYPE_SEPARATOR;
    MENU_ITEM_INFO mii;
    mii.Mask = MENU_MASK_TYPE | MENU_MASK_ID | MENU_MASK_STATE | MENU_MASK_STRING;
    mii.Type = MENU_TYPE_STRING;

    mii.String = LoadStr(IDS_MENU_TAB_NEW);
    mii.ID = 1;
    mii.State = 0;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_DUPLICATE);
    mii.ID = 2;
    mii.State = onTab ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    menu.InsertItem(0xffffffff, TRUE, &miiSep);

    mii.String = LoadStr(IDS_MENU_TAB_CLOSE);
    mii.ID = 3;
    mii.State = (onTab && count > 1) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_CLOSEOTHERS);
    mii.ID = 4;
    mii.State = (count > 1) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_CLOSERIGHT);
    mii.ID = 5;
    mii.State = (onTab && index < count - 1) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    FilesWindow->Tabs.ContextTabIndex = onTab ? index : -1;
    DWORD cmd = menu.Track(MENU_TRACK_RETURNCMD | MENU_TRACK_RIGHTBUTTON, xScreen, yScreen, HWindow, NULL);
    EndStopRefresh();
    HotIndex = -1;
    HotPart = tspNone;
    Repaint();

    BOOL left = (MainWindow->LeftPanel == FilesWindow);
    int cm = 0;
    switch (cmd)
    {
    case 1:
        cm = left ? CM_LEFT_NEWTAB : CM_RIGHT_NEWTAB;
        break;
    case 2:
        cm = left ? CM_LEFT_DUPTAB : CM_RIGHT_DUPTAB;
        break;
    case 3:
        cm = left ? CM_LEFT_CLOSETAB : CM_RIGHT_CLOSETAB;
        break;
    case 4:
        cm = left ? CM_LEFT_CLOSEOTHERTABS : CM_RIGHT_CLOSEOTHERTABS;
        break;
    case 5:
        cm = left ? CM_LEFT_CLOSETABSRIGHT : CM_RIGHT_CLOSETABSRIGHT;
        break;
    }
    if (cm != 0)
        PostMessage(MainWindow->HWindow, WM_COMMAND, MAKEWPARAM(cm, 0), 0); // the handler resets ContextTabIndex
    else
        FilesWindow->Tabs.ContextTabIndex = -1;
}

//
// ****************************************************************************
// window procedure
//

LRESULT
CTabWindow::WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    SLOW_CALL_STACK_MESSAGE4("CTabWindow::WindowProc(0x%X, 0x%IX, 0x%IX)", uMsg, wParam, lParam);
    switch (uMsg)
    {
    case WM_CREATE:
    {
        MeasureFont();
        return 0;
    }

    case WM_DESTROY:
    {
        SetCurrentToolTip(NULL, 0);
        if (GetCapture() == HWindow)
            ReleaseCapture();
        ResetDrag();
        return 0;
    }

    case WM_SIZE:
    case WM_ERASEBKGND:
    {
        RECT r;
        GetClientRect(HWindow, &r);
        if (Width != r.right || Height != r.bottom)
        {
            Width = r.right;
            Height = r.bottom;
            ItemBitmap.Enlarge(Width, Height); // the shared cache; Paint() covers the whole client area
        }
        if (uMsg == WM_ERASEBKGND)
            return TRUE;
        break;
    }

    case WM_PAINT:
    {
        PAINTSTRUCT ps;
        HDC hdc = HANDLES(BeginPaint(HWindow, &ps));
        Paint(hdc);
        HANDLES(EndPaint(HWindow, &ps));
        return 0;
    }

    case WM_USER_TTGETTEXT:
    {
        DWORD id = (DWORD)wParam;
        char* text = (char*)lParam;
        if (id == TABSTRIP_TT_PLUS)
            CopyToolTipAnswer(LoadStrU8(IDS_TABS_TT_NEW), text);
        else if (id == TABSTRIP_TT_LIST)
            CopyToolTipAnswer(LoadStrU8(IDS_TABS_TT_LIST), text);
        else if (id >= TABSTRIP_TT_TAB)
        {
            CPanelTab* tab = FilesWindow->Tabs.At((int)(id - TABSTRIP_TT_TAB));
            if (tab != NULL)
                CopyToolTipAnswer(tab->Location, text); // UTF-8, clamped on a character boundary
        }
        return 0;
    }

    case WM_SETCURSOR:
    {
        if (GetCapture() == HWindow)
            return TRUE; // keep the cursor during the drag
        break;
    }

    case WM_MOUSEMOVE:
    {
        if (MainWindow->HasLockedUI())
            break;
        OnMouseMove((short)LOWORD(lParam), (short)HIWORD(lParam));
        return 0;
    }

    case WM_MOUSELEAVE:
    case WM_CANCELMODE:
    {
        MouseIsTracked = FALSE;
        if (uMsg == WM_CANCELMODE && (Dragging || WaitForDrag))
        {
            if (GetCapture() == HWindow)
                ReleaseCapture();
            ResetDrag();
        }
        MButtonDownIndex = -1;
        if (HotIndex != -1 || HotPart != tspNone)
        {
            HotIndex = -1;
            HotPart = tspNone;
            Repaint();
        }
        SetCurrentToolTip(NULL, 0);
        break;
    }

    case WM_CAPTURECHANGED:
    {
        if ((HWND)lParam != HWindow && (Dragging || WaitForDrag))
        {
            ResetDrag();
            Repaint();
        }
        break;
    }

    case WM_LBUTTONDOWN:
    {
        if (MainWindow->HasLockedUI())
            break;
        SetCurrentToolTip(NULL, 0);
        OnLButtonDown((short)LOWORD(lParam), (short)HIWORD(lParam));
        return 0;
    }

    case WM_LBUTTONUP:
    {
        if (MainWindow->HasLockedUI())
            break;
        OnLButtonUp((short)LOWORD(lParam), (short)HIWORD(lParam));
        return 0;
    }

    case WM_MBUTTONDOWN:
    {
        if (MainWindow->HasLockedUI())
            break;
        SetCurrentToolTip(NULL, 0);
        int part;
        int index = HitTest((short)LOWORD(lParam), (short)HIWORD(lParam), &part);
        MButtonDownIndex = (part == tspTab || part == tspClose) ? index : -1;
        return 0;
    }

    case WM_MBUTTONUP:
    {
        if (MainWindow->HasLockedUI())
            break;
        int part;
        int index = HitTest((short)LOWORD(lParam), (short)HIWORD(lParam), &part);
        int down = MButtonDownIndex;
        MButtonDownIndex = -1;
        if ((part == tspTab || part == tspClose) && index >= 0 && index == down)
            FilesWindow->CloseTab(index); // never the only tab (CloseTab refuses)
        return 0;
    }

    case WM_RBUTTONDOWN:
    {
        if (Dragging || WaitForDrag)
        {
            if (GetCapture() == HWindow)
                ReleaseCapture();
            ResetDrag();
            Repaint();
        }
        return 0;
    }

    case WM_RBUTTONUP:
    {
        if (MainWindow->HasLockedUI())
            break;
        SetCurrentToolTip(NULL, 0);
        int x = (short)LOWORD(lParam);
        int y = (short)HIWORD(lParam);
        int part;
        int index = HitTest(x, y, &part);
        POINT pt = {x, y};
        ClientToScreen(HWindow, &pt);
        if (GetActiveWindow() == NULL)
            SetForegroundWindow(MainWindow->HWindow);
        OpenContextMenu((part == tspTab || part == tspClose) ? index : -1, pt.x, pt.y);
        return 0;
    }
    }
    return CWindow::WindowProc(uMsg, wParam, lParam);
}
