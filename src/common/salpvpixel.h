// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpvpixel.h
//
// Feature 120: how PictView's pipette and histogram read the rows of the image
// the viewer holds - pure rules, so saltests can check them.
//
// The image engine (wicengine.cpp, feature 006) hands out 32-bit rows (blue,
// green, red, an unused byte) and says so: PVImageInfo::Colors is
// PV_COLOR_TC32, PVImageInfo::BytesPerLine is the width times 4. The pipette
// and the histogram (PixelAccess.cpp, Open Salamander's) read every row of
// PV_COLOR_TC24 *or more* as 3 bytes per pixel - the old engine's 32-bit
// images were converted to 24-bit rows. So since feature 006 the pipette
// showed pixel x * 3 / 4 with its channels shifted (blue, green, red taken
// from blue/green/red/unused at a byte offset that walks along the row) and
// the histogram counted misaligned bytes of three quarters of every row.
// Display only - nothing was ever written from these values.
//
// One reader now serves both, by the bytes per pixel of the row format:
//   PV_COLOR_TC32  4 (B, G, R, unused)    PV_COLOR_TC24  3 (B, G, R)
//   PV_COLOR_HC15  2 (x RRRRR GGGGG BBBBB, little-endian)
//   PV_COLOR_HC16  2 (RRRRR GGGGGG BBBBB, little-endian)
//   > 16 colors    1 palette index        > 2 colors     4 bits (high nibble first)
//   2 colors       1 bit (most significant bit first)
// The histogram's own 15/16-bit decoding had red and blue swapped and its
// palette branch counted the bytes that pad a row; both are gone with it (no
// row of the WIC engine has either form - recorded, not reachable).
//
// The viewer mirrors when it draws (a negative stretch) - the rows are never
// mirrored. The pipette reads the pixel UNDER the cursor: SalPvShownToRow
// maps the shown position to the row position.
//
// Header-only: PictView and saltests share it.
//
//*****************************************************************************

#include <windows.h>

// PVImageInfo::Colors of the direct-color rows (lib/PVW32DLL.h PV_COLOR_*; PixelAccess.cpp checks
// that the values are equal)
#define SAL_PV_COLOR_HC15 65532
#define SAL_PV_COLOR_HC16 65533
#define SAL_PV_COLOR_TC24 65534
#define SAL_PV_COLOR_TC32 65535

// bits one pixel takes in a row of 'colors' (PVImageInfo::Colors); 0 = not a row format
inline unsigned SalPvRowBitsPerPixel(DWORD colors)
{
    switch (colors)
    {
    case SAL_PV_COLOR_TC32:
        return 32;
    case SAL_PV_COLOR_TC24:
        return 24;
    case SAL_PV_COLOR_HC15:
    case SAL_PV_COLOR_HC16:
        return 16;
    }
    if (colors == 0 || colors > 256)
        return 0;
    return colors > 16 ? 8 : (colors > 2 ? 4 : 1);
}

// the palette index of pixel 'x' of a palette row (1 <= colors <= 256)
inline unsigned SalPvRowIndex(const BYTE* line, DWORD colors, unsigned x)
{
    if (colors > 16)
        return line[x];
    if (colors > 2)
        return (x & 1) ? (line[x >> 1] & 0x0F) : (line[x >> 1] >> 4);
    return (line[x >> 3] & (0x80 >> (x & 7))) ? 1 : 0;
}

// the color of pixel 'x' of a direct-color row (TC32, TC24, HC15, HC16); rgbReserved is 0
inline RGBQUAD SalPvRowColor(const BYTE* line, DWORD colors, unsigned x)
{
    RGBQUAD c = {0, 0, 0, 0};
    if (colors == SAL_PV_COLOR_HC15 || colors == SAL_PV_COLOR_HC16)
    {
        unsigned w = line[2 * x] | ((unsigned)line[2 * x + 1] << 8);
        c.rgbBlue = (BYTE)((w & 31) << 3);
        if (colors == SAL_PV_COLOR_HC15)
        {
            c.rgbGreen = (BYTE)(((w >> 5) & 31) << 3);
            c.rgbRed = (BYTE)(((w >> 10) & 31) << 3);
        }
        else
        {
            c.rgbGreen = (BYTE)(((w >> 5) & 63) << 2);
            c.rgbRed = (BYTE)(((w >> 11) & 31) << 3);
        }
        return c;
    }
    const BYTE* p = line + (size_t)x * (colors == SAL_PV_COLOR_TC24 ? 3 : 4);
    c.rgbBlue = p[0];
    c.rgbGreen = p[1];
    c.rgbRed = p[2];
    return c;
}

// pixel 'x' of a row of 'colors': TRUE with its color in '*out' and, for a palette row, its index in
// '*index' (0 for a direct-color row). FALSE for a format that is not a row format, a palette row
// without its palette ('palette' NULL) and an index outside the palette ('colors' entries). The
// caller keeps 'x' inside the row.
inline BOOL SalPvReadRowPixel(const BYTE* line, DWORD colors, unsigned x, const RGBQUAD* palette, RGBQUAD* out,
                              int* index)
{
    if (line == NULL || SalPvRowBitsPerPixel(colors) == 0)
        return FALSE;
    if (colors <= 256)
    {
        unsigned i = SalPvRowIndex(line, colors, x);
        if (palette == NULL || i >= colors)
            return FALSE;
        *out = palette[i];
        *index = (int)i;
        return TRUE;
    }
    *out = SalPvRowColor(line, colors, x);
    *index = 0;
    return TRUE;
}

// adds 'count' pixels of color 'c' to the histogram's arrays (256 entries each): the channels, the
// luminosity (0.299 R + 0.587 G + 0.114 B, rounded down) and the "RGB" levels (Photoshop's: every
// channel value once - SalPvHistogramFinish divides them by three)
inline void SalPvHistogramAdd(DWORD* luminosity, DWORD* red, DWORD* green, DWORD* blue, DWORD* rgb, RGBQUAD c,
                              DWORD count)
{
    red[c.rgbRed] += count;
    green[c.rgbGreen] += count;
    blue[c.rgbBlue] += count;
    luminosity[(299 * (unsigned)c.rgbRed + 587 * (unsigned)c.rgbGreen + 114 * (unsigned)c.rgbBlue) / 1000] += count;
    rgb[c.rgbRed] += count;
    rgb[c.rgbGreen] += count;
    rgb[c.rgbBlue] += count;
}

// the first 'width' pixels of a row: a direct color goes into the histogram's arrays, a palette
// index is counted in 'indexCounts' (256 entries) - the caller adds those through the palette once
// at the end (SalPvHistogramAdd with each entry's count). Nothing for a format that is not a row
// format.
inline void SalPvHistogramRow(const BYTE* line, DWORD colors, unsigned width, DWORD* indexCounts, DWORD* luminosity,
                              DWORD* red, DWORD* green, DWORD* blue, DWORD* rgb)
{
    if (line == NULL || SalPvRowBitsPerPixel(colors) == 0)
        return;
    unsigned x;
    if (colors <= 256)
    {
        for (x = 0; x < width; x++)
            indexCounts[SalPvRowIndex(line, colors, x)]++;
        return;
    }
    for (x = 0; x < width; x++)
        SalPvHistogramAdd(luminosity, red, green, blue, rgb, SalPvRowColor(line, colors, x), 1);
}

// the "RGB" levels hold every channel value once: one third of that is the level's share
inline void SalPvHistogramFinish(DWORD* rgb)
{
    for (int i = 0; i < 256; i++)
        rgb[i] /= 3;
}

// the row pixel under the SHOWN position ('x', 'y') of an image 'width' x 'height' (the rows' size,
// rotations included): the viewer mirrors when it draws, the rows stay as decoded. FALSE outside the
// image.
inline BOOL SalPvShownToRow(int x, int y, int width, int height, BOOL mirrorHor, BOOL mirrorVert, int* rowX,
                            int* rowY)
{
    if (x < 0 || y < 0 || x >= width || y >= height)
        return FALSE;
    *rowX = mirrorHor ? width - 1 - x : x;
    *rowY = mirrorVert ? height - 1 - y : y;
    return TRUE;
}
