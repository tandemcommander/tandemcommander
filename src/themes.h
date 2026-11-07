// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// Feature 028: application-wide visual themes (Default + Dark).
//
// The theme is an axis independent of the panel color schemes: the Default
// theme is a pure passthrough (the application looks exactly as before this
// feature existed), the Dark theme substitutes a built-in dark palette for
// both the panel colors (DarkColors/DarkViewerColors, see consts.h) and the
// window chrome (ThemeSysColor below). When Windows High Contrast is active,
// the Dark theme is suppressed and system colors win.
//
// Contract: specs/028-visual-themes/contracts/theme-engine.md

// Configuration.ThemeMode values
#define THEME_MODE_DEFAULT 0
#define THEME_MODE_DARK 1

// TRUE only when the Dark theme is selected AND High Contrast is off;
// every theme-aware code path keys off this single predicate
BOOL IsDarkThemeActive();

// feature 404: TRUE while Windows High Contrast is on (cached like IsDarkThemeActive)
BOOL IsThemeHighContrast();

// re-reads the Windows High Contrast state (call on WM_SYSCOLORCHANGE /
// WM_SETTINGCHANGE; cheap, cached otherwise)
void RefreshThemeHighContrastState();

// GetSysColor replacement for DRAWING code only: Default theme returns
// GetSysColor(index) unchanged; Dark theme returns the dark chrome palette
// entry (fallback GetSysColor for unmapped indices)
COLORREF ThemeSysColor(int index);

// GetSysColorBrush / (HBRUSH)(COLOR_X + 1) replacement for fills; the
// returned brush is engine-owned (do not delete); valid until process exit
HBRUSH ThemeSysColorBrush(int index);

// DrawEdge replacement: passthrough in Default theme, flat dark bevel in Dark
BOOL ThemeDrawEdge(HDC hDC, RECT* rc, UINT edge, UINT flags);

// repoints CurrentColors/CurrentViewerColors according to the active theme:
// Dark -> DarkColors/DarkViewerColors, otherwise SchemeColors/ViewerColors;
// call after any scheme change and on startup once ThemeMode is known
void UpdateCurrentColorsForTheme();

// full live theme switch: stores mode into Configuration.ThemeMode, repoints
// palettes and pushes the change through the standard ColorsChanged pipeline
// (panels, Find, viewers, plugins) + retitles top-level windows
void SetThemeMode(DWORD mode);

// applies/removes the dark (DWM immersive) title bar on a top-level window
// according to the active theme; no-op for windows never dark-themed when
// the Default theme is active (passthrough guarantee)
void ThemeApplyToTopLevel(HWND hWindow);

// paints one item of a list header in the dark theme (the CDDS_ITEMPREPAINT
// stage of the header's NM_CUSTOMDRAW): the header's dark theme part, the label
// in the light text colour and - feature 407 - the sort arrow of HDF_SORTUP /
// HDF_SORTDOWN, which the default painting this replaces drew; returns
// CDRF_SKIPDEFAULT (features 044, 049)
LRESULT ThemePaintDarkHeaderItem(HWND hHeader, LPNMCUSTOMDRAW cd);

// dark-themes a dialog: dark title bar + per-child SetWindowTheme dark
// variants + listview/treeview colors; restores standard look when called
// again after switching back to the Default theme
void ThemeApplyToDialog(HWND hDialog);

// re-applies per-HWND dark theming (SetWindowTheme variants + engine
// subclasses + control colors) to 'hWnd' itself and every descendant; use
// after creating or recreating controls at runtime (panel view-mode
// switches, inline editors, late-created children). Idempotent; a no-op in
// the Default theme (fresh controls are already native). Does NOT touch the
// DWM title bar - that stays with ThemeApplyToTopLevel/ThemeApplyToDialog.
// Feature 049. Restriction: thread owning 'hWnd'.
void ThemeApplyToWindowTree(HWND hWnd);

// applies/removes dark colors on a native tooltips_class32 window (tooltips
// are WS_POPUP - the per-dialog child sweep never reaches them); call once
// after creating the tooltip and again on theme changes (feature 049)
void ThemeApplyToTooltip(HWND hTooltip);

// swaps the background class brush (GCLP_HBRBACKGROUND) of 'hWindow's window
// class between the original system brush and the dark brush; 'lightSysColor'
// is the COLOR_* index the class was registered with (e.g. COLOR_WINDOW)
void ThemeUpdateWindowClassBackground(HWND hWindow, int lightSysColor);

// the classic (unthemed) rebar draws its WS_BORDER edges and RBS_BANDBORDERS
// separators with light system 3D colors that cannot be recolored - strip
// both styles while the Dark theme is active and restore them for Default
void ThemeUpdateRebarStyle(HWND hRebar);

// central WM_CTLCOLOR* handling for dialog procs; returns TRUE when handled
// (Dark theme) and stores the brush into 'result'; FALSE in the Default theme
BOOL ThemeHandleCtlColor(UINT uMsg, WPARAM wParam, LPARAM lParam, INT_PTR* result);

// dark-themes a property-sheet frame window (the dialog holding the pages):
// installs a subclass handling WM_CTLCOLOR*/WM_ERASEBKGND and themes its
// children (tree, buttons); no-op in the Default theme for untouched frames
void ThemeSubclassPropSheetFrame(HWND hFrame);

// Dark-theme transform of a legacy (light-background) glyph bitmap: pixels in
// the 'transparent' key color are left alone; dark neutral pixels (black
// outlines, gray shading) are remapped to light ones and dark saturated
// colors are brightened, so the glyphs stay legible on dark surfaces.
// No-op in the Default theme. Call while the bitmap is NOT selected in a DC.
void ThemeAdjustBitmapForDarkMode(HBITMAP hBitmap, COLORREF transparent);

// frees engine-owned GDI objects (process shutdown)
void ReleaseThemeGraphics();
