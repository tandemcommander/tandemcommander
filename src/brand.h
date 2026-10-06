// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// Tandem Commander brand palette (feature 032, see tools/brand/README.md) and
// the brand painting shared by the About dialog, the splash screen and the
// new-version notification (feature 123). Implemented in logo.cpp; the
// wordmark is drawn with GDI so no font has to be installed or shipped.

#define TC_COLOR_NAVY RGB(0x0A, 0x14, 0x24)           // brand navy background
#define TC_COLOR_TEXT_DARKBG RGB(0xEA, 0xF2, 0xFB)    // "Tandem" + regular text on dark background
#define TC_COLOR_ORANGE_DARKBG RGB(0xF9, 0x73, 0x16)  // "Commander" on dark background
#define TC_COLOR_MUTED_DARKBG RGB(0x8F, 0xA6, 0xC4)   // version/tagline on dark background
#define TC_COLOR_TEXT_LIGHTBG RGB(0x0A, 0x14, 0x24)   // "Tandem" + regular text on light background
#define TC_COLOR_ORANGE_LIGHTBG RGB(0xEA, 0x6A, 0x0B) // "Commander" on light background
#define TC_COLOR_MUTED_LIGHTBG RGB(0x5D, 0x82, 0xB8)  // version/tagline on light background

// Paints a brand header band into 'hDC': the band 'band' in the brand
// background (white, navy in the Dark theme), the "Tandem Commander" wordmark
// in 'wordmarkR', the product artwork fitted into and centred in 'logoR', and
// the blue-to-orange accent line across the band's width with its top at
// 'accentY'. Returns the bottom of the accent line (the first row below the
// band's painting).
int TCPaintBrandHeader(HDC hDC, const RECT* band, const RECT* wordmarkR, const RECT* logoR, int accentY);

// returns the rectangle of the dialog control 'resID' in client coordinates of 'hWindow' and
// destroys the control: layout placeholders of painted dialogs (logo.cpp)
void GetDlgItemRectAndDestroy(HWND hWindow, int resID, RECT* r);
