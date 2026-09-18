// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// tabwnd.h
//
// CTabWindow - the tab strip above a panel's directory line (feature
// 078-panel-tabs). Owner-drawn in the house style of the directory line
// (EnvFont, theme colours, the shared ItemBitmap cache), never takes the
// keyboard focus, and only ever asks its panel to switch/open/close tabs
// (CFilesWindow::SwitchToTab and friends in paneltabs.cpp).
//

class CFilesWindow;

// what is under a point of the strip
enum CTabStripPart
{
    tspNone,
    tspTab,   // the body of a tab
    tspClose, // the close glyph of a tab
    tspPlus,  // the "+" button
    tspList,  // the tab-list button (shown only while some tabs do not fit)
};

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
    int FirstVisible;  // index of the first painted tab
    int VisibleCount;  // number of painted tabs
    int TabWidth;      // width of every painted tab
    int TabsLeft;      // x of the first painted tab
    BOOL ListButtonVisible;
    RECT PlusRect;
    RECT ListRect;

    // drag-to-reorder (the CEditListBox gesture)
    BOOL WaitForDrag;
    BOOL Dragging;
    POINT DragAnchor;
    int DragIndex;
    int InsertIndex; // where the dragged tab would land (0..count)

    int MButtonDownIndex; // tab under the middle button when it went down (-1 = none)

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
    BOOL GetCloseRect(int index, RECT* r);
    BOOL ShowsCloseGlyph(int index);
    int HitTest(int x, int y, int* part);
    void UpdateHot(int x, int y);
    void ResetDrag();

    void Paint(HDC hdc);
    void PaintTab(HDC dc, int index);
    void PaintPlus(HDC dc);
    void PaintList(HDC dc);
    void PaintInsertMark(HDC dc);
    void DrawGlyphLines(HDC dc, const POINT* pts, int count, COLORREF clr);

    void OnLButtonDown(int x, int y);
    void OnLButtonUp(int x, int y);
    void OnMouseMove(int x, int y);
    void OpenTabList();
    void OpenContextMenu(int index, int xScreen, int yScreen);
};
