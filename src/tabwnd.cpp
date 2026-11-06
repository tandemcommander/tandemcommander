// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#include "precomp.h"

#include <math.h>

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

#include "nanosvg\nanosvg.h"
#include "nanosvg\nanosvgrast.h"

//
// ****************************************************************************
// CTabWindow
//

// pixel metrics at 100 % scale (feature 404: variant F of the 2026-11-06 mockups,
// specs/404-panel-tabs-rounded-look/contracts/tab-strip-f.md)
#define TABSTRIP_PAD 10      // icon (or text) inset from the tab's left edge, text inset on the right
#define TABSTRIP_GLYPH 8     // size of the close glyph box
#define TABSTRIP_CLOSEPAD 8  // the close glyph box ends this far before the tab's right edge
#define TABSTRIP_TITLEGAP 6  // the title ends this far before the close glyph
#define TABSTRIP_ICONGAP 6   // between the icon and the title
#define TABSTRIP_LEFT 8      // the first tab starts here (room for the active tab's left foot)
#define TABSTRIP_TOP 3       // the content band runs from here to the bottom
#define TABSTRIP_RADIUS 6.0f // the active tab's top corners and feet
#define TABSTRIP_ANIM_MS 150 // the neighbour slide / glide of the live drag

#define TABSTRIP_TT_PLUS 1
#define TABSTRIP_TT_LIST 2
#define TABSTRIP_TT_TAB 100

#define TABSTRIP_ANIM_TIMER 404

// the colours of one paint (computed in Paint)
struct CTabPaintColors
{
    CSalTabStripColors Strip;
    COLORREF Text;  // COLOR_BTNTEXT
    COLORREF CapBk; // the caption background of the panel (active / inactive)
    COLORREF CapFg;
    BOOL Dark;
    BOOL HighContrast;
};

static CTabPaintColors TabPaint; // the UI thread only

static float TabStripScale()
{
    return GetScaleForSystemDPI() / 100.0f;
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
    GrabOffset = 0;
    DragX = 0;
    DragSlot = -1;
    Anim = NULL;
    AnimCount = 0;
    TimerOn = FALSE;
    PressedClose = -1;
    PressedCloseInside = FALSE;
    PressedCloseTab = NULL;
    MButtonDownIndex = -1;
    Rast = NULL;
    AADC = NULL;
    AABitmap = NULL;
    AAOldBitmap = NULL;
    AABits = NULL;
    AAWidth = 0;
    AAHeight = 0;
    IconFolder = NULL;
    IconArchive = NULL;
    IconPluginFS = NULL;
    memset(IconDrive, 0, sizeof(IconDrive));
    int i;
    for (i = 0; i < TABSTRIP_PLUGIN_ICONS; i++)
    {
        PluginIconPlugin[i] = -1;
        PluginIcon[i] = NULL;
    }
    MeasureFont();
}

CTabWindow::~CTabWindow()
{
    CALL_STACK_MESSAGE1("CTabWindow::~CTabWindow()");
    if (Anim != NULL)
        delete[] Anim;
    Anim = NULL;
    FreeAABitmap();
    if (Rast != NULL)
        nsvgDeleteRasterizer(Rast);
    Rast = NULL;
    ClearIcons();
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

int CTabWindow::Scaled(int px)
{
    return SalTabScaled(px, GetScaleForSystemDPI());
}

int CTabWindow::TextTop()
{
    return Scaled(TABSTRIP_TOP);
}

int CTabWindow::GetNeededHeight()
{
    CALL_STACK_MESSAGE_NONE
    return SalTabStripHeight(EnvFontCharHeight, GetScaleForSystemDPI());
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
    ClearIcons(); // feature 404: a theme or system colour change may come with new icons
    InvalidateAndUpdate(FALSE);
}

//
// ****************************************************************************
// layout and hit testing
//

void CTabWindow::Layout()
{
    int count = FilesWindow->Tabs.Count();
    int btnW = Height; // square buttons
    int minW, maxW;
    SalTabStripWidths(AvgCharWidth, GetScaleForSystemDPI(), IconSizes[ICONSIZE_16], &minW, &maxW);

    TabsLeft = Scaled(TABSTRIP_LEFT);
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

BOOL CTabWindow::GetDrawnTabRect(int index, RECT* r)
{
    if (!GetTabRect(index, r))
        return FALSE;
    int dx = 0;
    if (Dragging && index == DragIndex)
        dx = DragX - r->left;
    else if (Anim != NULL && index >= 0 && index < AnimCount)
        dx = Anim[index].Cur;
    r->left += dx;
    r->right += dx;
    return TRUE;
}

BOOL CTabWindow::ShowsCloseGlyph(int index)
{
    return FilesWindow->Tabs.Count() > 1 &&
           (index == FilesWindow->Tabs.ActiveIndex || index == HotIndex || index == PressedClose);
}

BOOL CTabWindow::GetCloseRect(int index, RECT* r)
{
    RECT tab;
    if (!GetTabRect(index, &tab))
        return FALSE;
    int pad = Scaled(TABSTRIP_PAD);
    int glyph = Scaled(TABSTRIP_GLYPH);
    int top = TextTop();
    r->right = tab.right - Scaled(TABSTRIP_CLOSEPAD);
    r->left = r->right - glyph;
    r->top = top + (Height - top - glyph) / 2;
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
    DragSlot = -1;
}

void CTabWindow::CancelPress()
{
    if (PressedClose >= 0)
    {
        PressedClose = -1;
        PressedCloseInside = FALSE;
        PressedCloseTab = NULL;
        Repaint();
    }
}

void CTabWindow::CancelGesture()
{
    if (Dragging)
        EndDrag(FALSE); // glides back, order unchanged
    else if (WaitForDrag)
        ResetDrag();
    PressedClose = -1;
    PressedCloseInside = FALSE;
    PressedCloseTab = NULL;
    if (HWindow != NULL && GetCapture() == HWindow)
        ReleaseCapture(); // its WM_CAPTURECHANGED finds nothing left to cancel
    Repaint();
}

//
// ****************************************************************************
// live drag (feature 404)
//

BOOL CTabWindow::AnimationsOn()
{
    BOOL on = TRUE;
    if (!SystemParametersInfo(SPI_GETCLIENTAREAANIMATION, 0, &on, 0))
        on = TRUE;
    return on;
}

void CTabWindow::EnsureTimer()
{
    if (!TimerOn && HWindow != NULL)
        TimerOn = SetTimer(HWindow, TABSTRIP_ANIM_TIMER, 16, NULL) != 0;
}

void CTabWindow::StopAnim()
{
    if (Anim != NULL)
        delete[] Anim;
    Anim = NULL;
    AnimCount = 0;
    if (TimerOn && !Dragging)
    {
        if (HWindow != NULL)
            KillTimer(HWindow, TABSTRIP_ANIM_TIMER);
        TimerOn = FALSE;
    }
}

void CTabWindow::SetAnimTarget(int index, int to)
{
    if (Anim == NULL || index < 0 || index >= AnimCount)
        return;
    CTabStripAnim* a = &Anim[index];
    if (a->To == to)
        return;
    a->From = a->Cur;
    a->To = to;
    a->Start = GetTickCount();
    if (!AnimationsOn())
        a->Cur = a->From = to; // Windows animation effects off: jump
    EnsureTimer();
}

BOOL CTabWindow::AnimStep(BOOL* changed)
{
    if (changed != NULL)
        *changed = FALSE;
    if (Anim == NULL)
        return FALSE;
    DWORD now = GetTickCount();
    BOOL moving = FALSE;
    int i;
    for (i = 0; i < AnimCount; i++)
    {
        CTabStripAnim* a = &Anim[i];
        if (a->Cur == a->To)
            continue;
        int p = SalTabEaseOut((int)(now - a->Start), TABSTRIP_ANIM_MS);
        int cur = a->From + (int)(((__int64)(a->To - a->From) * p) / 1000);
        if (p >= 1000)
            cur = a->To;
        if (cur != a->Cur && changed != NULL)
            *changed = TRUE;
        a->Cur = cur;
        if (a->Cur != a->To)
            moving = TRUE;
    }
    return moving;
}

void CTabWindow::StartDrag()
{
    int count = FilesWindow->Tabs.Count();
    if (DragIndex < FirstVisible || DragIndex >= FirstVisible + VisibleCount || DragIndex >= count)
    {
        ResetDrag();
        if (GetCapture() == HWindow)
            ReleaseCapture();
        return;
    }
    if (Anim != NULL)
        delete[] Anim;
    Anim = new CTabStripAnim[count];
    if (Anim == NULL)
    {
        AnimCount = 0;
        ResetDrag();
        if (GetCapture() == HWindow)
            ReleaseCapture();
        return;
    }
    memset(Anim, 0, sizeof(CTabStripAnim) * count);
    AnimCount = count;
    WaitForDrag = FALSE;
    Dragging = TRUE;
    DragSlot = DragIndex;
    DragX = TabsLeft + (DragIndex - FirstVisible) * TabWidth;
    HotIndex = -1;
    HotPart = tspNone;
    SetCurrentToolTip(NULL, 0);
    EnsureTimer(); // also watches Esc
}

void CTabWindow::UpdateDrag(int x)
{
    if (!Dragging)
        return;
    if (AnimCount != FilesWindow->Tabs.Count() || TabWidth <= 0 || VisibleCount <= 0)
    {
        // the tab set changed under the drag (a key closed or opened a tab): give the drag up
        ResetDrag();
        StopAnim();
        if (GetCapture() == HWindow)
            ReleaseCapture();
        Repaint();
        return;
    }
    int runLeft = TabsLeft;
    int maxLeft = TabsLeft + (VisibleCount - 1) * TabWidth; // within the visible run, no tear-off
    int left = x - GrabOffset;
    if (left < runLeft)
        left = runLeft;
    if (left > maxLeft)
        left = maxLeft;
    DragX = left;
    int slot = FirstVisible + SalTabDragSlot(VisibleCount, TabWidth, left - runLeft, DragIndex - FirstVisible);
    if (slot != DragSlot)
    {
        DragSlot = slot;
        int i;
        for (i = FirstVisible; i < FirstVisible + VisibleCount; i++)
            if (i != DragIndex)
                SetAnimTarget(i, (SalTabDragPosition(DragIndex, DragSlot, i) - i) * TabWidth);
    }
    Repaint();
}

void CTabWindow::EndDrag(BOOL apply)
{
    if (!Dragging)
    {
        ResetDrag();
        return;
    }
    int count = FilesWindow->Tabs.Count();
    int from = DragIndex;
    int to = (apply && DragSlot >= 0) ? DragSlot : DragIndex;
    if (AnimCount != count)
    {
        ResetDrag();
        StopAnim();
        Repaint();
        return;
    }
    // where every tab is drawn now (absolute x), to glide from there after the order changed
    int* drawn = new int[count];
    BOOL* shown = new BOOL[count];
    if (drawn == NULL || shown == NULL)
    {
        if (drawn != NULL)
            delete[] drawn;
        if (shown != NULL)
            delete[] shown;
        ResetDrag();
        StopAnim();
        if (apply && to != from)
            FilesWindow->MoveTab(from, to);
        Repaint();
        return;
    }
    int i;
    for (i = 0; i < count; i++)
    {
        RECT r;
        shown[i] = GetDrawnTabRect(i, &r);
        drawn[i] = shown[i] ? r.left : 0;
    }
    ResetDrag(); // Dragging = FALSE before anything can re-enter (MoveTab repaints)
    if (to != from)
        FilesWindow->MoveTab(from, to); // the order changes once; persistence is unchanged
    Layout();
    BOOL animate = AnimationsOn();
    DWORD now = GetTickCount();
    memset(Anim, 0, sizeof(CTabStripAnim) * count);
    for (i = 0; i < count; i++)
    {
        if (!shown[i])
            continue;
        int j = SalTabDragPosition(from, to, i); // the new index of old tab i
        RECT r;
        if (j < 0 || j >= count || !GetTabRect(j, &r))
            continue;
        int off = animate ? drawn[i] - r.left : 0;
        Anim[j].Cur = Anim[j].From = off;
        Anim[j].To = 0;
        Anim[j].Start = now;
    }
    delete[] drawn;
    delete[] shown;
    EnsureTimer();
    Repaint();
}

//
// ****************************************************************************
// anti-aliased drawing (feature 404): nanosvg rasterizes one white path into
// the DIB (every channel = coverage), the coverage becomes premultiplied BGRA
// of the wanted colour and is alpha-blended onto the strip
//

BOOL CTabWindow::EnsureAABitmap()
{
    if (Rast == NULL)
        Rast = nsvgCreateRasterizer();
    if (Rast == NULL)
        return FALSE;
    if (AABitmap != NULL && AAWidth >= Width && AAHeight >= Height)
        return TRUE;
    FreeAABitmap();
    int w = max(Width, 1);
    int h = max(Height, 1);
    AADC = HANDLES(CreateCompatibleDC(NULL));
    if (AADC == NULL)
        return FALSE;
    BITMAPINFOHEADER bmhdr;
    memset(&bmhdr, 0, sizeof(bmhdr));
    bmhdr.biSize = sizeof(bmhdr);
    bmhdr.biWidth = w;
    bmhdr.biHeight = -h; // top-down
    bmhdr.biPlanes = 1;
    bmhdr.biBitCount = 32;
    bmhdr.biCompression = BI_RGB;
    void* bits = NULL;
    AABitmap = HANDLES(CreateDIBSection(AADC, (CONST BITMAPINFO*)&bmhdr, DIB_RGB_COLORS, &bits, NULL, 0));
    if (AABitmap == NULL || bits == NULL)
    {
        FreeAABitmap();
        return FALSE;
    }
    AAOldBitmap = (HBITMAP)SelectObject(AADC, AABitmap);
    AABits = (BYTE*)bits;
    AAWidth = w;
    AAHeight = h;
    return TRUE;
}

void CTabWindow::FreeAABitmap()
{
    if (AADC != NULL && AAOldBitmap != NULL)
        SelectObject(AADC, AAOldBitmap);
    AAOldBitmap = NULL;
    if (AABitmap != NULL)
        HANDLES(DeleteObject(AABitmap));
    AABitmap = NULL;
    if (AADC != NULL)
        HANDLES(DeleteDC(AADC));
    AADC = NULL;
    AABits = NULL;
    AAWidth = AAHeight = 0;
}

void CTabWindow::AAShape(HDC dc, const char* svgElement, COLORREF clr, float fx0, float fy0, float fx1, float fy1)
{
    if (!EnsureAABitmap())
        return;
    int x0 = (int)floorf(fx0) - 1;
    int y0 = (int)floorf(fy0) - 1;
    int x1 = (int)ceilf(fx1) + 1;
    int y1 = (int)ceilf(fy1) + 1;
    if (x0 < 0)
        x0 = 0;
    if (y0 < 0)
        y0 = 0;
    if (x1 > min(Width, AAWidth))
        x1 = min(Width, AAWidth);
    if (y1 > min(Height, AAHeight))
        y1 = min(Height, AAHeight);
    if (x1 <= x0 || y1 <= y0)
        return;
    char svg[1024];
    if (_snprintf_s(svg, _TRUNCATE, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\">%s</svg>",
                    Width, Height, svgElement) < 0)
        return;
    // the numbers are formatted by the C runtime: a decimal comma of a locale set by someone else
    // in the process (a shell extension) would break them - SVG takes only the dot and never a comma
    char* c;
    for (c = svg; *c != 0; c++)
        if (*c == ',')
            *c = '.';
    NSVGimage* image = nsvgParse(svg, "px", 96.0f);
    if (image == NULL)
        return;
    int w = x1 - x0;
    int h = y1 - y0;
    BYTE* dst = AABits + ((size_t)y0 * AAWidth + x0) * 4;
    nsvgRasterize(Rast, image, (float)-x0, (float)-y0, 1.0f, dst, w, h, AAWidth * 4);
    nsvgDelete(image);
    int r = GetRValue(clr);
    int g = GetGValue(clr);
    int b = GetBValue(clr);
    int y;
    for (y = 0; y < h; y++)
    {
        BYTE* p = dst + (size_t)y * AAWidth * 4;
        int x;
        for (x = 0; x < w; x++, p += 4)
        {
            int a = p[3];
            p[0] = (BYTE)((b * a + 127) / 255);
            p[1] = (BYTE)((g * a + 127) / 255);
            p[2] = (BYTE)((r * a + 127) / 255);
        }
    }
    GdiFlush();
    BLENDFUNCTION bf;
    bf.BlendOp = AC_SRC_OVER;
    bf.BlendFlags = 0;
    bf.SourceConstantAlpha = 0xff;
    bf.AlphaFormat = AC_SRC_ALPHA;
    AlphaBlend(dc, x0, y0, w, h, AADC, x0, y0, w, h, bf);
}

void CTabWindow::AAFillCircle(HDC dc, float cx, float cy, float radius, COLORREF clr)
{
    char el[200];
    _snprintf_s(el, _TRUNCATE, "<circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\" fill=\"#ffffff\"/>", cx, cy, radius);
    AAShape(dc, el, clr, cx - radius, cy - radius, cx + radius, cy + radius);
}

void CTabWindow::AACross(HDC dc, float cx, float cy, float half, float stroke, COLORREF clr)
{
    char el[400];
    _snprintf_s(el, _TRUNCATE,
                "<path d=\"M%.3f %.3fL%.3f %.3fM%.3f %.3fL%.3f %.3f\" fill=\"none\" stroke=\"#ffffff\" "
                "stroke-width=\"%.3f\" stroke-linecap=\"round\"/>",
                cx - half, cy - half, cx + half, cy + half, cx - half, cy + half, cx + half, cy - half, stroke);
    float e = half + stroke;
    AAShape(dc, el, clr, cx - e, cy - e, cx + e, cy + e);
}

void CTabWindow::AAPlus(HDC dc, float cx, float cy, float half, float stroke, COLORREF clr)
{
    // butt caps reaching 0.25 px (scaled) past the ends: at 1.2 px the eye cannot tell them from the
    // mockup's round caps, and they stay within a shade of the mockup's GDI+ tips - nanosvg's round cap
    // of this size comes out a third lighter, a square cap a third darker (measured, fix-log)
    char el[400];
    float ext = half + 0.25f * TabStripScale();
    _snprintf_s(el, _TRUNCATE,
                "<path d=\"M%.3f %.3fL%.3f %.3fM%.3f %.3fL%.3f %.3f\" fill=\"none\" stroke=\"#ffffff\" "
                "stroke-width=\"%.3f\" stroke-linecap=\"butt\"/>",
                cx - ext, cy, cx + ext, cy, cx, cy - ext, cx, cy + ext, stroke);
    float e = ext + stroke;
    AAShape(dc, el, clr, cx - e, cy - e, cx + e, cy + e);
}

//
// ****************************************************************************
// icons (feature 404): from the tab's location kind, never from a call on the
// location itself (a remembered tab may point to an unreachable network path)
//

static HICON TabIconFromList(int index)
{
    if (SimpleIconLists[ICONSIZE_16] == NULL)
        return NULL;
    return SimpleIconLists[ICONSIZE_16]->GetIcon(index, TRUE);
}

HICON CTabWindow::GetTabIcon(CPanelTab* tab)
{
    if (tab == NULL)
        return NULL;
    FilesWindow->ResolveTabIconKind(tab);
    int iconSize = IconSizes[ICONSIZE_16];
    switch (tab->IconKind)
    {
    case SAL_TAB_KIND_ARCHIVE:
    {
        if (IconArchive == NULL)
            IconArchive = LoadArchiveIcon(iconSize, iconSize, IconLRFlags);
        return IconArchive;
    }

    case SAL_TAB_KIND_DRIVE:
    case SAL_TAB_KIND_UNC:
    {
        UINT type = tab->IconDriveType;
        if (type >= 8)
            type = DRIVE_UNKNOWN;
        // GetDriveIcon picks the icon by the drive type (and the Windows drive) only - one per pair
        char root[4] = {tab->IconKind == SAL_TAB_KIND_DRIVE ? tab->Location[0] : 'A', ':', '\\', 0};
        int sys = 0;
        if (tab->IconKind == SAL_TAB_KIND_DRIVE && type == DRIVE_FIXED)
        {
            WCHAR win[MAX_PATH];
            if (GetWindowsDirectoryW(win, MAX_PATH) && win[1] == L':' && towupper(win[0]) == towupper((WCHAR)(BYTE)root[0]))
                sys = 1;
            if (sys)
                root[0] = (char)win[0]; // GetDriveIcon compares the letter as written
        }
        if (IconDrive[type][sys] == NULL)
        {
            if (type == DRIVE_REMOVABLE)
                IconDrive[type][sys] = SalLoadIcon(ImageResDLL, 28, iconSize); // the generic removable drive: no shell call on the medium
            else
                IconDrive[type][sys] = GetDriveIcon(root, type, TRUE);
        }
        return IconDrive[type][sys];
    }

    case SAL_TAB_KIND_PLUGINFS:
    {
        int plugin = tab->IconPluginIndex;
        int i;
        if (plugin >= 0)
        {
            for (i = 0; i < TABSTRIP_PLUGIN_ICONS; i++)
                if (PluginIconPlugin[i] == plugin)
                    return PluginIcon[i] != NULL ? PluginIcon[i] : IconPluginFS;
            CPluginData* p = Plugins.Get(plugin);
            HICON icon = NULL;
            if (p != NULL && p->PluginIcons != NULL && p->ChDrvMenuFSItemIconIndex != -1)
                icon = p->PluginIcons->GetIcon(p->ChDrvMenuFSItemIconIndex, TRUE); // the Change Drive menu's icon
            for (i = 0; i < TABSTRIP_PLUGIN_ICONS; i++)
            {
                if (PluginIconPlugin[i] == -1)
                {
                    PluginIconPlugin[i] = plugin;
                    PluginIcon[i] = icon;
                    icon = NULL;
                    break;
                }
            }
            if (icon != NULL) // the cache is full: use the generic icon
                HANDLES(DestroyIcon(icon));
            for (i = 0; i < TABSTRIP_PLUGIN_ICONS; i++)
                if (PluginIconPlugin[i] == plugin && PluginIcon[i] != NULL)
                    return PluginIcon[i];
        }
        if (IconPluginFS == NULL)
            IconPluginFS = SalLoadIcon(HInstance, IDI_PLUGINFS, iconSize);
        return IconPluginFS;
    }
    }
    if (IconFolder == NULL)
        IconFolder = TabIconFromList(symbolsDirectory);
    return IconFolder;
}

void CTabWindow::ClearIcons()
{
    if (IconFolder != NULL)
        HANDLES(DestroyIcon(IconFolder));
    IconFolder = NULL;
    if (IconArchive != NULL)
        HANDLES(DestroyIcon(IconArchive));
    IconArchive = NULL;
    if (IconPluginFS != NULL)
        HANDLES(DestroyIcon(IconPluginFS));
    IconPluginFS = NULL;
    int i, j;
    for (i = 0; i < 8; i++)
        for (j = 0; j < 2; j++)
        {
            if (IconDrive[i][j] != NULL)
                HANDLES(DestroyIcon(IconDrive[i][j]));
            IconDrive[i][j] = NULL;
        }
    for (i = 0; i < TABSTRIP_PLUGIN_ICONS; i++)
    {
        if (PluginIcon[i] != NULL)
            HANDLES(DestroyIcon(PluginIcon[i]));
        PluginIcon[i] = NULL;
        PluginIconPlugin[i] = -1;
    }
}

//
// ****************************************************************************
// painting (feature 404: the mockup's PaintNew - TabMock.cs, variant 6)
//

static void TabFillSolid(HDC dc, const RECT* r, COLORREF clr)
{
    SetBkColor(dc, clr);
    ExtTextOutW(dc, 0, 0, ETO_OPAQUE, r, L"", 0, NULL);
}

void CTabWindow::PaintTabBack(HDC dc, int index, BOOL hot)
{
    RECT r;
    if (!GetDrawnTabRect(index, &r))
        return;
    float sc = TabStripScale();
    BOOL active = (index == FilesWindow->Tabs.ActiveIndex);
    float H = (float)Height;
    char el[700];
    if (active)
    {
        // the rounded tab with outward feet that joins the directory line below
        float rad = TABSTRIP_RADIUS * sc;
        float L = (float)r.left;
        float R = (float)(r.right + 1);
        float T = (float)TextTop();
        float B = H;
        _snprintf_s(el, _TRUNCATE,
                    "<path d=\"M%.3f %.3fA%.3f %.3f 0 0 0 %.3f %.3fL%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3f"
                    "L%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3fL%.3f %.3fA%.3f %.3f 0 0 0 %.3f %.3fZ\" fill=\"#ffffff\"/>",
                    L - rad, B, rad, rad, L, B - rad,  // left foot
                    L, T + rad, rad, rad, L + rad, T,  // top-left corner
                    R - rad, T, rad, rad, R, T + rad,  // top-right corner
                    R, B - rad, rad, rad, R + rad, B); // right foot
        AAShape(dc, el, TabPaint.CapBk, L - rad, T, R + rad, B);
    }
    else if (hot)
    {
        // the hover pill
        float x = r.left + 3 * sc;
        float y = 4 * sc;
        float w = (float)(r.right - r.left) - 5 * sc;
        float h = H - 7 * sc;
        float rad = 5 * sc;
        _snprintf_s(el, _TRUNCATE,
                    "<path d=\"M%.3f %.3fL%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3fL%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3f"
                    "L%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3fL%.3f %.3fA%.3f %.3f 0 0 1 %.3f %.3fZ\" fill=\"#ffffff\"/>",
                    x + rad, y, x + w - rad, y, rad, rad, x + w, y + rad,
                    x + w, y + h - rad, rad, rad, x + w - rad, y + h,
                    x + rad, y + h, rad, rad, x, y + h - rad,
                    x, y + rad, rad, rad, x + rad, y);
        AAShape(dc, el, TabPaint.Strip.HoverBk, x, y, x + w, y + h);
    }
}

void CTabWindow::PaintTabFront(HDC dc, int index)
{
    RECT r;
    if (!GetDrawnTabRect(index, &r))
        return;
    CPanelTab* tab = FilesWindow->Tabs.At(index);
    if (tab == NULL)
        return;
    float sc = TabStripScale();
    BOOL active = (index == FilesWindow->Tabs.ActiveIndex);
    BOOL hot = !Dragging && HotIndex == index && (HotPart == tspTab || HotPart == tspClose);
    COLORREF clr = active ? TabPaint.CapFg : (hot ? TabPaint.Strip.HoverText : TabPaint.Strip.DimText);
    int pad = Scaled(TABSTRIP_PAD);
    int glyph = Scaled(TABSTRIP_GLYPH);

    RECT tr;
    tr.left = r.left + pad;
    tr.top = TextTop();
    tr.right = r.right - pad;
    tr.bottom = Height;
    BOOL closeGlyph = ShowsCloseGlyph(index);
    if (closeGlyph)
        tr.right = r.right - Scaled(TABSTRIP_CLOSEPAD) - glyph - Scaled(TABSTRIP_TITLEGAP);

    // the location icon
    int iconSize = IconSizes[ICONSIZE_16];
    HICON icon = GetTabIcon(tab);
    if (icon != NULL && tr.left + iconSize <= r.right)
    {
        int iy = tr.top + (tr.bottom - tr.top - iconSize) / 2;
        DrawIconEx(dc, tr.left, iy, icon, iconSize, iconSize, 0, NULL, DI_NORMAL);
    }
    tr.left += iconSize + Scaled(TABSTRIP_ICONGAP);

    char title[SAL_FIND_NAME_U8];
    SalTabTitleFromLocation(tab->Location, title, sizeof(title));
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
        SelectObject(dc, oldFont);
    }

    if (closeGlyph)
    {
        RECT cr, layout;
        if (GetCloseRect(index, &cr) && GetTabRect(index, &layout))
        {
            int dx = r.left - layout.left; // the drawn offset of a dragged / gliding tab
            BOOL pressed = (PressedClose == index && PressedCloseInside);
            BOOL closeHot = pressed || (!Dragging && PressedClose < 0 && HotIndex == index && HotPart == tspClose);
            COLORREF bk = active ? TabPaint.CapBk : (hot || pressed ? TabPaint.Strip.HoverBk : TabPaint.Strip.StripBk);
            COLORREF fg = active ? TabPaint.CapFg : TabPaint.Text;
            DWORD cross, circle;
            SalTabCloseColors(bk, fg, TabPaint.Dark, TabPaint.HighContrast, &cross, &circle);
            float cx = cr.left + dx + glyph / 2.0f;
            float cy = cr.top + glyph / 2.0f;
            if (pressed) // the pressed button: the hover circle, darker
                circle = SalTabMix(bk, fg, (TabPaint.Dark && !TabPaint.HighContrast) ? 0.40 : 0.28);
            if (closeHot)
                AAFillCircle(dc, cx, cy, 8 * sc, circle);
            AACross(dc, cx, cy, 3.5f * sc, 1.2f * sc, closeHot ? fg : cross);
        }
    }
}

void CTabWindow::PaintPlus(HDC dc)
{
    if (PlusRect.right - PlusRect.left < 4)
        return;
    float sc = TabStripScale();
    float top = (float)TextTop();
    float cx = (PlusRect.left + PlusRect.right) / 2.0f;
    float cy = top + (Height - top) / 2.0f;
    BOOL hot = (HotPart == tspPlus);
    if (hot)
        AAFillCircle(dc, cx, cy, 9 * sc, TabPaint.Strip.HoverBk);
    AAPlus(dc, cx, cy, 4.5f * sc, 1.2f * sc, hot ? TabPaint.Strip.HoverText : TabPaint.Strip.DimText);
}

void CTabWindow::PaintList(HDC dc)
{
    SIZE sz;
    SVGArrowDropDown.GetSize(&sz);
    int x = ListRect.left + (ListRect.right - ListRect.left - sz.cx) / 2;
    int top = TextTop();
    int y = top + (Height - top - sz.cy) / 2;
    SVGArrowDropDown.AlphaBlend(dc, x, y, -1, -1, SVGSTATE_ENABLED);
}

void CTabWindow::Paint(HDC hdc)
{
    CALL_STACK_MESSAGE1("CTabWindow::Paint()");
    if (Width <= 0 || Height <= 0)
        return;
    HDC dc = ItemBitmap.HMemDC;

    Layout();
    if (Anim != NULL && AnimCount != FilesWindow->Tabs.Count())
        StopAnim(); // the tab set changed during a glide

    // the colours of this paint
    BOOL activePanel = (FilesWindow == MainWindow->GetActivePanel()) && MainWindow->CaptionIsActive;
    TabPaint.Dark = IsDarkThemeActive();
    TabPaint.HighContrast = IsThemeHighContrast();
    TabPaint.Text = ThemeSysColor(COLOR_BTNTEXT);
    SalTabStripColorsGet(ThemeSysColor(COLOR_BTNFACE), ThemeSysColor(COLOR_BTNSHADOW), ThemeSysColor(COLOR_BTNHIGHLIGHT),
                         TabPaint.Text, TabPaint.Dark, TabPaint.HighContrast, GetSysColor(COLOR_HIGHLIGHT),
                         GetSysColor(COLOR_HIGHLIGHTTEXT), &TabPaint.Strip);
    TabPaint.CapBk = GetCOLORREF(CurrentColors[activePanel ? ACTIVE_CAPTION_BK : INACTIVE_CAPTION_BK]);
    TabPaint.CapFg = GetCOLORREF(CurrentColors[activePanel ? ACTIVE_CAPTION_FG : INACTIVE_CAPTION_FG]);

    RECT all = {0, 0, Width, Height};
    TabFillSolid(dc, &all, TabPaint.Strip.StripBk);

    int active = FilesWindow->Tabs.ActiveIndex;
    int dragged = Dragging ? DragIndex : -1;
    int last = FirstVisible + VisibleCount;
    int i;
    // the hover pill of an inactive tab
    for (i = FirstVisible; i < last; i++)
        if (i != active && i != dragged)
            PaintTabBack(dc, i, !Dragging && HotIndex == i && (HotPart == tspTab || HotPart == tspClose));

    // separators between two plain tabs (not while tabs move)
    if (!Dragging && Anim == NULL)
    {
        int grow = (Height - Scaled(25)) / 2;
        int top = Scaled(8) + grow;
        int bottom = Height - Scaled(6) - grow;
        for (i = FirstVisible; i + 1 < last; i++)
        {
            BOOL plain1 = (i != active && i != HotIndex);
            BOOL plain2 = (i + 1 != active && i + 1 != HotIndex);
            RECT r;
            if (plain1 && plain2 && GetTabRect(i, &r) && bottom > top)
            {
                RECT sep = {r.right, top, r.right + 1, bottom};
                TabFillSolid(dc, &sep, TabPaint.Strip.Separator);
            }
        }
    }

    for (i = FirstVisible; i < last; i++)
        if (i != active && i != dragged)
            PaintTabFront(dc, i);
    // the active tab last: its feet overlap the neighbours; a dragged tab on top of everything
    if (active >= FirstVisible && active < last && active != dragged)
    {
        PaintTabBack(dc, active, FALSE);
        PaintTabFront(dc, active);
    }
    if (dragged >= FirstVisible && dragged < last)
    {
        PaintTabBack(dc, dragged, TRUE);
        PaintTabFront(dc, dragged);
    }
    PaintPlus(dc);
    if (ListButtonVisible)
        PaintList(dc);

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

    if (Anim != NULL && !Dragging) // a new press ends a glide at once
        StopAnim();
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
    {
        // feature 404: the X is a push button - it closes on the release over it, never switches or drags
        if (HWindow != NULL && index >= 0)
        {
            PressedClose = index;
            PressedCloseInside = TRUE;
            PressedCloseTab = FilesWindow->Tabs.At(index);
            HotIndex = index;
            HotPart = tspClose;
            SetCurrentToolTip(NULL, 0);
            SetCapture(HWindow);
            Repaint();
        }
        return;
    }

    case tspTab:
    {
        if (index != FilesWindow->Tabs.ActiveIndex)
            FilesWindow->SwitchToTab(index);
        if (FilesWindow->Tabs.Count() > 1 && HWindow != NULL && index < FilesWindow->Tabs.Count())
        {
            Layout();
            RECT r;
            if (GetTabRect(index, &r))
            {
                WaitForDrag = TRUE;
                Dragging = FALSE;
                DragAnchor.x = x;
                DragAnchor.y = y;
                DragIndex = index;
                DragSlot = index;
                GrabOffset = x - r.left;
                SetCapture(HWindow);
            }
        }
        break;
    }
    }
    UpdateHot(x, y);
}

void CTabWindow::OnMouseMove(int x, int y)
{
    if (PressedClose >= 0)
    {
        int part;
        int index = HitTest(x, y, &part);
        BOOL inside = (index == PressedClose && part == tspClose);
        if (inside != PressedCloseInside)
        {
            PressedCloseInside = inside; // like a push button: pressed only while over it
            HotIndex = PressedClose;
            HotPart = inside ? tspClose : tspTab;
            Repaint();
        }
        return;
    }
    if (WaitForDrag)
    {
        int dx = GetSystemMetrics(SM_CXDRAG);
        int dy = GetSystemMetrics(SM_CYDRAG);
        if (dx < 1)
            dx = 1;
        if (dy < 1)
            dy = 1;
        if (x < DragAnchor.x - dx || x > DragAnchor.x + dx || y < DragAnchor.y - dy || y > DragAnchor.y + dy)
            StartDrag();
    }
    if (Dragging)
    {
        UpdateDrag(x); // only x: the tab stays in the strip (no tear-off)
        return;
    }
    UpdateHot(x, y);
}

void CTabWindow::OnLButtonUp(int x, int y)
{
    if (PressedClose >= 0)
    {
        int pressed = PressedClose;
        CPanelTab* pressedTab = PressedCloseTab;
        int part;
        int index = HitTest(x, y, &part);
        BOOL inside = (index == pressed && part == tspClose);
        PressedClose = -1; // before ReleaseCapture: its WM_CAPTURECHANGED finds nothing to cancel
        PressedCloseInside = FALSE;
        PressedCloseTab = NULL;
        if (GetCapture() == HWindow)
            ReleaseCapture();
        if (inside && FilesWindow->Tabs.At(pressed) == pressedTab) // still the pressed tab
            FilesWindow->CloseTab(pressed); // never the only tab (CloseTab refuses)
        Repaint();
        UpdateHot(x, y);
        return;
    }
    if (Dragging)
    {
        EndDrag(TRUE);
        if (GetCapture() == HWindow)
            ReleaseCapture();
        return;
    }
    if (WaitForDrag)
    {
        ResetDrag();
        if (GetCapture() == HWindow)
            ReleaseCapture();
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
  {MNTT_IT, IDS_MENU_TAB_NEWASOTHER
  {MNTT_IT, IDS_MENU_TAB_DUPLICATE
  {MNTT_IT, IDS_MENU_TAB_MOVETOOTHER
  {MNTT_IT, IDS_MENU_TAB_CLOSE
  {MNTT_IT, IDS_MENU_TAB_REOPEN
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
    CFilesWindow* other = MainWindow->GetOtherPanel(FilesWindow);
    BOOL otherShowsTabs = other != NULL && other != FilesWindow && other->GetTabStripHWND() != NULL;
    BOOL otherHasLocation = other != NULL && other != FilesWindow && other->Tabs.Active() != NULL &&
                            other->Tabs.Active()->Location[0] != 0;
    BeginStopRefresh();

    CMenuPopup menu;
    MENU_ITEM_INFO miiSep;
    miiSep.Mask = MENU_MASK_TYPE;
    miiSep.Type = MENU_TYPE_SEPARATOR;
    MENU_ITEM_INFO mii;
    mii.Mask = MENU_MASK_TYPE | MENU_MASK_ID | MENU_MASK_STATE | MENU_MASK_STRING;
    mii.Type = MENU_TYPE_STRING;

    mii.String = (char*)LoadStrTabKeys(IDS_MENU_TAB_NEW); // feature 312: the keys of the mode in effect
    mii.ID = 1;
    mii.State = 0;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_NEWASOTHER); // feature 404: shared by a tab and the empty strip
    mii.ID = 7;
    mii.State = SalTabMenuCanNewAsOther(otherHasLocation) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_DUPLICATE);
    mii.ID = 2;
    mii.State = onTab ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = LoadStr(IDS_MENU_TAB_MOVETOOTHER); // feature 404
    mii.ID = 8;
    mii.State = SalTabMenuCanMoveToOther(onTab, count, otherShowsTabs) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    menu.InsertItem(0xffffffff, TRUE, &miiSep);

    mii.String = (char*)LoadStrTabKeys(IDS_MENU_TAB_CLOSE);
    mii.ID = 3;
    mii.State = (onTab && count > 1) ? 0 : MENU_STATE_GRAYED;
    menu.InsertItem(0xffffffff, TRUE, &mii);

    mii.String = (char*)LoadStrTabKeys(IDS_MENU_TAB_REOPEN); // feature 312
    mii.ID = 6;
    mii.State = (FilesWindow->Tabs.Closed.Count > 0) ? 0 : MENU_STATE_GRAYED;
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
    case 6:
        cm = left ? CM_LEFT_REOPENTAB : CM_RIGHT_REOPENTAB;
        break;
    case 7:
        cm = left ? CM_LEFT_NEWTABASOTHER : CM_RIGHT_NEWTABASOTHER; // feature 404
        break;
    case 8:
        cm = left ? CM_LEFT_MOVETABTOOTHER : CM_RIGHT_MOVETABTOOTHER; // feature 404
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
        PressedClose = -1;
        PressedCloseInside = FALSE;
        PressedCloseTab = NULL;
        ResetDrag();
        if (GetCapture() == HWindow)
            ReleaseCapture();
        if (TimerOn)
            KillTimer(HWindow, TABSTRIP_ANIM_TIMER);
        TimerOn = FALSE;
        StopAnim();
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

    case WM_PRINTCLIENT: // feature 404: PrintWindow (the probe's capture)
    {
        if (wParam != 0)
            Paint((HDC)wParam);
        return 0;
    }

    case WM_TIMER:
    {
        if (wParam != TABSTRIP_ANIM_TIMER)
            break;
        if (Dragging && (GetAsyncKeyState(VK_ESCAPE) & 0x8000)) // the strip never has the focus: Esc is read here
        {
            EndDrag(FALSE);
            if (GetCapture() == HWindow)
                ReleaseCapture();
        }
        BOOL changed;
        BOOL moving = AnimStep(&changed);
        if (changed)
            Repaint(); // a held drag with nothing moving paints nothing
        if (!Dragging && !moving)
        {
            StopAnim();
            if (TimerOn)
                KillTimer(HWindow, TABSTRIP_ANIM_TIMER);
            TimerOn = FALSE;
            Repaint(); // the separators come back
        }
        return 0;
    }

    case WM_USER_TTGETTEXT:
    {
        DWORD id = (DWORD)wParam;
        char* text = (char*)lParam;
        if (id == TABSTRIP_TT_PLUS)
            CopyToolTipAnswer(LoadStrTabKeys(IDS_TABS_TT_NEW, TRUE), text); // feature 312: the key of the mode
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
        if ((wParam & MK_LBUTTON) == 0 && (WaitForDrag || Dragging || PressedClose >= 0))
            CancelGesture(); // the button went up elsewhere (a dialog of the tab switch took it): never a drag without the button
        OnMouseMove((short)LOWORD(lParam), (short)HIWORD(lParam));
        return 0;
    }

    case WM_MOUSELEAVE:
    case WM_CANCELMODE:
    {
        MouseIsTracked = FALSE;
        POINT cursor;
        if (uMsg == WM_MOUSELEAVE && !GetCursorPos(&cursor))
            break; // feature 404: no cursor to judge by (a desktop without input): the hover stays until the next mouse message
        if (uMsg == WM_CANCELMODE)
        {
            // feature 404: a cancelled drag glides back, a pressed X is forgotten
            if (Dragging || WaitForDrag || PressedClose >= 0)
                CancelGesture();
        }
        if (Dragging || PressedClose >= 0)
            break; // the capture keeps the gesture; the hot state belongs to it
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
        if ((HWND)lParam != HWindow && (Dragging || WaitForDrag || PressedClose >= 0))
        {
            // feature 404: losing the capture cancels: the drag glides back, a pressed X closes nothing
            // (CancelGesture also releases a capture that is still ours - a posted notice)
            CancelGesture();
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
        if (Dragging || PressedClose >= 0)
            return 0; // never close a tab under a left-button gesture
        if ((part == tspTab || part == tspClose) && index >= 0 && index == down)
            FilesWindow->CloseTab(index); // never the only tab (CloseTab refuses)
        return 0;
    }

    case WM_RBUTTONDOWN:
    {
        if (Dragging || WaitForDrag || PressedClose >= 0)
            CancelGesture();
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
