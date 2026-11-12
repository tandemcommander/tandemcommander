// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// Feature 427: the Dark adaptation of a legacy raster glyph bitmap, header-only so that plug-ins
// (which cannot compile a .cpp of src/common) use the same transform as the core. Moved here from
// ThemeAdjustBitmapForDarkMode (src/themes.cpp, feature 028), which now calls it after its Dark
// check; plug-ins call it when CSalamanderGeneralAbstract::IsDarkThemeActive() says Dark (no
// plug-in interface change).
//
// Per pixel: ThemeDarkAdaptColor (themes_palette.h, feature 029) - neutral dark pixels become
// light, dark saturated ones brighter, light ones stay. Skipped: the mask key colour of a bitmap
// without alpha (`key`) and fully transparent pixels of a bitmap with alpha; partially transparent
// (premultiplied) pixels are un-premultiplied, adapted and premultiplied again. The caller decides
// whether the theme is Dark; this function always adapts.

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include "themes_palette.h"

// WCAG relative luminance of an sRGB colour (0..1)
inline double ThemeDarkLiftLuminance(int r, int g, int b)
{
    double c[3] = {r / 255.0, g / 255.0, b / 255.0};
    for (int i = 0; i < 3; i++)
        c[i] = c[i] <= 0.03928 ? c[i] / 12.92 : pow((c[i] + 0.055) / 1.055, 2.4);
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

inline double ThemeDarkLiftContrast(int r, int g, int b, COLORREF face)
{
    double a = ThemeDarkLiftLuminance(r, g, b);
    double f = ThemeDarkLiftLuminance(GetRValue(face), GetGValue(face), GetBValue(face));
    return a > f ? (a + 0.05) / (f + 0.05) : (f + 0.05) / (a + 0.05);
}

// a saturated colour below 3:1 to `face` mixed toward white until it reaches 3:1 (same hue family)
inline void ThemeDarkLiftColor(int* r, int* g, int* b, COLORREF face)
{
    int maxc = *r > *g ? (*r > *b ? *r : *b) : (*g > *b ? *g : *b);
    int minc = *r < *g ? (*r < *b ? *r : *b) : (*g < *b ? *g : *b);
    if (maxc - minc < 32 || ThemeDarkLiftContrast(*r, *g, *b, face) >= 3.0)
        return;
    int r0 = *r, g0 = *g, b0 = *b;
    for (int t = 1; t <= 20; t++)
    {
        *r = r0 + ThemeDarkAdaptMulDivRound(255 - r0, t, 20);
        *g = g0 + ThemeDarkAdaptMulDivRound(255 - g0, t, 20);
        *b = b0 + ThemeDarkAdaptMulDivRound(255 - b0, t, 20);
        if (ThemeDarkLiftContrast(*r, *g, *b, face) >= 3.0)
            return;
    }
}

// the walk; face == CLR_INVALID: the 028 adaptation only
inline void ThemeDarkAdaptBitmapImpl(HBITMAP hBitmap, COLORREF key, COLORREF face)
{
    if (hBitmap == NULL)
        return;

    BITMAP bmp;
    if (GetObject(hBitmap, sizeof(bmp), &bmp) == 0 || bmp.bmWidth <= 0 || bmp.bmHeight <= 0)
        return;

    int width = bmp.bmWidth;
    int height = bmp.bmHeight;
    DWORD* pixels = (DWORD*)malloc((size_t)width * height * sizeof(DWORD));
    if (pixels == NULL)
        return;

    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = width;
    bi.bmiHeader.biHeight = -height; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    HDC hDC = GetDC(NULL);
    if (hDC != NULL && GetDIBits(hDC, hBitmap, 0, height, pixels, &bi, DIB_RGB_COLORS) == height)
    {
        int count = width * height;
        int i;

        // legacy 24bpp sources come back with a zero alpha byte everywhere;
        // PNG (alpha) sources have at least one non-zero alpha byte
        BOOL hasAlpha = FALSE;
        for (i = 0; i < count; i++)
        {
            if ((pixels[i] & 0xFF000000) != 0)
            {
                hasAlpha = TRUE;
                break;
            }
        }

        for (i = 0; i < count; i++)
        {
            DWORD px = pixels[i];
            int a = (int)(px >> 24);
            if (hasAlpha && a == 0)
                continue; // fully transparent
            int r = (int)((px >> 16) & 0xFF);
            int g = (int)((px >> 8) & 0xFF);
            int b = (int)(px & 0xFF);
            if (!hasAlpha && RGB(r, g, b) == key)
                continue; // mask key color must survive untouched

            // un-premultiply partially transparent PNG pixels
            if (hasAlpha && a > 0 && a < 255)
            {
                r = MulDiv(r, 255, a);
                g = MulDiv(g, 255, a);
                b = MulDiv(b, 255, a);
                r = r > 255 ? 255 : r;
                g = g > 255 ? 255 : g;
                b = b > 255 ? 255 : b;
            }

            // feature 029: shared per-color rules (also applied to SVG toolbar
            // glyphs in svg.cpp and unit-tested from saltests)
            ThemeDarkAdaptColor(&r, &g, &b);
            if (face != CLR_INVALID)
                ThemeDarkLiftColor(&r, &g, &b, face);

            if (hasAlpha && a > 0 && a < 255)
            {
                r = MulDiv(r, a, 255);
                g = MulDiv(g, a, 255);
                b = MulDiv(b, a, 255);
            }
            pixels[i] = ((DWORD)a << 24) | ((DWORD)r << 16) | ((DWORD)g << 8) | (DWORD)b;
        }
        SetDIBits(hDC, hBitmap, 0, height, pixels, &bi, DIB_RGB_COLORS);
    }
    if (hDC != NULL)
        ReleaseDC(NULL, hDC);
    free(pixels);
}

// the core's legacy glyphs and anything that must look exactly like them (feature 028)
inline void ThemeDarkAdaptBitmap(HBITMAP hBitmap, COLORREF key)
{
    ThemeDarkAdaptBitmapImpl(hBitmap, key, CLR_INVALID);
}

// plug-in toolbars: 028 plus the 3:1 lift of low-contrast saturated colours against `face` (427)
inline void ThemeDarkAdaptBitmapLift(HBITMAP hBitmap, COLORREF key, COLORREF face)
{
    ThemeDarkAdaptBitmapImpl(hBitmap, key, face);
}
