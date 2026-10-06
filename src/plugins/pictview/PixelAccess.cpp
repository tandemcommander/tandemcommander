// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/* This is a dual file, include both in PictView.spl and PV Envelope.
   The envelope is built with #define BUILD_ENVELOPE.
 */
#include "precomp.h"

#include "lib/pvw32dll.h"

#include "pictview.h"
#include "PixelAccess.h"
#ifndef BUILD_ENVELOPE
#include "wicengine.h"
#endif
#include "../../common/salpvpixel.h" // feature 120: one row reader for the pipette and the histogram

static_assert(SAL_PV_COLOR_HC15 == PV_COLOR_HC15 && SAL_PV_COLOR_HC16 == PV_COLOR_HC16 &&
                  SAL_PV_COLOR_TC24 == PV_COLOR_TC24 && SAL_PV_COLOR_TC32 == PV_COLOR_TC32,
              "salpvpixel.h must name the same row formats as PVW32DLL.h");

// Feature 120: the rows are read by their format (src/common/salpvpixel.h). Before, every row of
// PV_COLOR_TC24 or more was read as 3 bytes per pixel, but the WIC engine's rows are PV_COLOR_TC32
// (4 bytes): the pipette showed another pixel's color with shifted channels and the histogram counted
// misaligned bytes of 3/4 of every row - every release since feature 006.

// the size of the rows the engine holds; FALSE when it is not known (the envelope build)
static BOOL GetRowsSize(LPPVHandle PVHandle, int* width, int* height)
{
#ifdef BUILD_ENVELOPE
    UNREFERENCED_PARAMETER(PVHandle);
    *width = *height = INT_MAX;
    return FALSE;
#else
    return WicGetRowsSize(PVHandle, width, height);
#endif
}

// pixel (x, y) of the rows (the caller maps a shown position to it - the mirror)
bool GetRGBAtCursor(LPPVHandle PVHandle, DWORD Colors, int x, int y, RGBQUAD* pRGB, int* pIndex)
{
    LPPVImageHandles pHandles;

#ifdef BUILD_ENVELOPE
    if ((PVC_OK == PVGetHandles2(PVHandle, &pHandles)) && pHandles->pLines)
    {
#else
    if ((PVC_OK == PVW32DLL.PVGetHandles2(PVHandle, &pHandles)) && pHandles->pLines)
    {
#endif
        int w, h;
        // never past the rows the engine holds, whatever the caller's image information says meanwhile
        // (the engine's own size is unknown only in the envelope build: the caller's bounds then)
        if (x < 0 || y < 0 || (GetRowsSize(PVHandle, &w, &h) && (x >= w || y >= h)))
            return false;
        RGBQUAD rgb;
        int ind;
        if (!SalPvReadRowPixel(pHandles->pLines[y], Colors, (unsigned)x, pHandles->Palette, &rgb, &ind))
            return false;
        *pIndex = ind;
        *pRGB = rgb;
        return true;
    }
    return false;
}

PVCODE CalculateHistogram(LPPVHandle PVHandle, const LPPVImageInfo pvii, LPDWORD luminosity, LPDWORD red, LPDWORD green, LPDWORD blue, LPDWORD rgb)
{
    LPPVImageHandles pHandles;
    PVCODE ret;
    DWORD tmp[256]; // palette rows: the pixels of each index

    memset(luminosity, 0, sizeof(DWORD) * 256);
    memset(red, 0, sizeof(DWORD) * 256);
    memset(green, 0, sizeof(DWORD) * 256);
    memset(blue, 0, sizeof(DWORD) * 256);
    memset(rgb, 0, sizeof(DWORD) * 256);
    memset(tmp, 0, sizeof(DWORD) * 256);

#ifdef BUILD_ENVELOPE
    if (PVC_OK != (ret = PVGetHandles2(PVHandle, &pHandles)))
    {
#else
    if (PVC_OK != (ret = PVW32DLL.PVGetHandles2(PVHandle, &pHandles)))
    {
#endif
        return ret;
    }
    // a row format, its palette for a paletted image, and the rows
    if (SalPvRowBitsPerPixel(pvii->Colors) == 0 || ((pvii->Colors <= 256) && !pHandles->Palette) ||
        !pHandles->pLines)
    {
        return PVC_UNSUP_COLOR_DEPTH;
    }
    // every pixel of the image once - never past the rows the engine holds
    DWORD width = pvii->Width, height = pvii->Height;
    int w, h;
    if (GetRowsSize(PVHandle, &w, &h))
    {
        width = min(width, (DWORD)w);
        height = min(height, (DWORD)h);
    }
    DWORD i;
    for (i = 0; i < height; i++)
        SalPvHistogramRow(pHandles->pLines[i], pvii->Colors, width, tmp, luminosity, red, green, blue, rgb);
    if (pvii->Colors <= 256)
    {
        for (i = 0; i < pvii->Colors; i++)
            if (tmp[i] != 0)
                SalPvHistogramAdd(luminosity, red, green, blue, rgb, pHandles->Palette[i], tmp[i]);
    }
    SalPvHistogramFinish(rgb);
    return PVC_OK;
}
