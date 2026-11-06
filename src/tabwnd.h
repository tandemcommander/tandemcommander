// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// tabwnd.h
//
// CTabWindow - the tab strip above a panel's directory line (feature
// 078-panel-tabs). Owner-drawn (EnvFont, theme colours, the shared ItemBitmap
// cache), never takes the keyboard focus, and only ever asks its panel to
// switch/open/close tabs (CFilesWindow::SwitchToTab and friends in
// paneltabs.cpp). Feature 404: drawn as variant F of the 2026-11-06 mockups
// (rounded active tab with feet, location icons, anti-aliased glyphs through
// nanosvg), live animated drag reorder and close on release
// (specs/404-panel-tabs-rounded-look/contracts/tab-strip-f.md).
//

class CFilesWindow;
class CPanelTab;
struct NSVGrasterizer;

// what is under a point of the strip
enum CTabStripPart
{
    tspNone,
    tspTab,   // the body of a tab
    tspClose, // the close glyph of a tab
    tspPlus,  // the "+" button
    tspList,  // the tab-list button (shown only while some tabs do not fit)
};

// feature 404: the drawn offset of one tab from its laid-out place (live drag)
struct CTabStripAnim
{
    int Cur;     // offset now
    int From;    // offset when the move to 'To' began
    int To;      // the offset it moves to
    DWORD Start; // GetTickCount() when the move began
};

#define TABSTRIP_PLUGIN_ICONS 16

class CTabWindow : public CWindow
{
public:
    CFilesWindow* FilesWindow;

protected:
    int Width;
    int Height;
    int AvgCharWidth; // of EnvFont, for the tab width limits

    int HotIndex; // tab under the mouse (-1 = none)
    int HotPart;  // CTabStripPart under the mouse
    BOOL MouseIsTracked;

    // layout computed by Layout() from the panel's tab set and Width
    int FirstVisible; // index of the first painted tab
    int VisibleCount; // number of painted tabs
    int TabWidth;     // width of every painted tab
    int TabsLeft;     // x of the first painted tab
    BOOL ListButtonVisible;
    RECT PlusRect;
    RECT ListRect;

    // drag-to-reorder (feature 404: live, the tab follows the cursor)
    BOOL WaitForDrag;
    BOOL Dragging;
    POINT DragAnchor;
    int DragIndex;       // the pressed tab (index into the panel's tabs)
    int GrabOffset;      // cursor x - the pressed tab's left at the press
    int DragX;           // drawn left of the dragged tab
    int DragSlot;        // the index the dragged tab takes now
    CTabStripAnim* Anim; // per tab (AnimCount entries), NULL while nothing moves
    int AnimCount;
    BOOL TimerOn;

    // feature 404: close on release
    int PressedClose;        // tab whose close glyph got the left button (-1 = none)
    BOOL PressedCloseInside; // the cursor is still over that glyph

    int MButtonDownIndex; // tab under the middle button when it went down (-1 = none)

    // feature 404: anti-aliased shapes - nanosvg into a DIB of the strip's size
    NSVGrasterizer* Rast;
    HDC AADC;
    HBITMAP AABitmap;
    HBITMAP AAOldBitmap;
    BYTE* AABits;
    int AAWidth;
    int AAHeight;

    // feature 404: icon cache (HANDLES-tracked, destroyed in ClearIcons)
    HICON IconFolder;
    HICON IconArchive;
    HICON IconPluginFS;    // the generic plug-in file system icon
    HICON IconDrive[8][2]; // [drive type][system drive]
    int PluginIconPlugin[TABSTRIP_PLUGIN_ICONS];
    HICON PluginIcon[TABSTRIP_PLUGIN_ICONS];

public:
    CTabWindow(CFilesWindow* filesWindow);
    ~CTabWindow();

    int GetNeededHeight();
    void DestroyWindow(); // destroys the strip window (HWindow -> NULL); the object stays

    void InvalidateAndUpdate(BOOL update); // may be called when HWindow == NULL
    void Repaint();
    void SetFont();
    void OnColorsChanged();

protected:
    virtual LRESULT WindowProc(UINT uMsg, WPARAM wParam, LPARAM lParam);

    void MeasureFont();
    void Layout();
    BOOL GetTabRect(int index, RECT* r);
    BOOL GetDrawnTabRect(int index, RECT* r); // GetTabRect moved by the drag / animation
    BOOL GetCloseRect(int index, RECT* r);
    BOOL ShowsCloseGlyph(int index);
    int HitTest(int x, int y, int* part);
    void UpdateHot(int x, int y);
    void ResetDrag();
    int Scaled(int px);
    int TextTop();

    // live drag (feature 404)
    void StartDrag();
    void UpdateDrag(int x);
    void EndDrag(BOOL apply); // release (apply) or cancel: the tabs glide to their slots
    void SetAnimTarget(int index, int to);
    BOOL AnimStep(); // advances the offsets; FALSE when nothing moves any more
    void EnsureTimer();
    void StopAnim();
    BOOL AnimationsOn();
    void CancelPress(); // forgets a pressed close glyph

    void Paint(HDC hdc);
    void PaintTabBack(HDC dc, int index, BOOL hot);
    void PaintTabFront(HDC dc, int index);
    void PaintPlus(HDC dc);
    void PaintList(HDC dc);

    // anti-aliased drawing (feature 404)
    BOOL EnsureAABitmap();
    void FreeAABitmap();
    void AAShape(HDC dc, const char* svgElement, COLORREF clr, float x0, float y0, float x1, float y1);
    void AAFillCircle(HDC dc, float cx, float cy, float radius, COLORREF clr);
    void AACross(HDC dc, float cx, float cy, float half, float stroke, COLORREF clr);
    void AAPlus(HDC dc, float cx, float cy, float half, float stroke, COLORREF clr);

    // icons (feature 404)
    HICON GetTabIcon(CPanelTab* tab);
    void ClearIcons();

    void OnLButtonDown(int x, int y);
    void OnLButtonUp(int x, int y);
    void OnMouseMove(int x, int y);
    void OpenTabList();
    void OpenContextMenu(int index, int xScreen, int yScreen);
};
