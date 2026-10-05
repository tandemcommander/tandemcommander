// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpvsource.h
//
// Feature 111: pure rules of PictView's image engine (wicengine.cpp) that do not
// need the Windows Imaging Component, so saltests can check them.
//
//   - What a source holds. The engine decodes every image into 32-bit rows and
//     reported every image as 32-bit, so the Save As dialog asked about a lost
//     alpha channel for every PNG/TIFF/ICO and never offered "2 colors" (nor the
//     CCITT TIFF compressions, which need it). The engine now reads the source's
//     pixel format; these rules turn a palette's size into the dialog's color
//     counts and decide what an alpha channel means for saving.
//   - The JPEG comment. The Windows JPEG encoder writes the COM segment with a
//     NUL byte after the text (measured: "FF FE <length> <text> 00"); COM holds
//     bytes, not a C string, and readers show the NUL. The engine takes it out
//     of the finished file; SalJpegCommentNul finds it - and only it.
//
// Header-only: PictView and saltests share it.
//
//*****************************************************************************

#include <windows.h>
#include <stddef.h>

// the dialog's color count for an indexed source: 'count' palette entries (0 = unknown: from the
// bits per pixel). A GIF of two colors is 8bppIndexed with a 2-entry palette (measured) - the
// palette decides, not the pixel format.
inline unsigned SalPaletteColorsForSave(unsigned count, unsigned bitsPerPixel)
{
    if (count == 0)
        count = bitsPerPixel >= 1 && bitsPerPixel <= 8 ? 1u << bitsPerPixel : 256;
    return count <= 2 ? 2 : (count <= 16 ? 16 : 256);
}

// TRUE when saving loses transparency the user can see: the source pixel format has an alpha
// channel AND a pixel of the decoded frame is not opaque. An opaque 32-bit image (most PNG, TIFF,
// ICO files written by common tools) loses nothing - the engine flattens alpha 255 to the same
// color - so no question is asked for it.
inline BOOL SalAlphaWouldBeLost(BOOL hasAlphaChannel, BOOL alphaUsed)
{
    return hasAlphaChannel && alphaUsed;
}

// In the first 'got' bytes of a JPEG file: the first COM segment before the image data (SOS).
// TRUE when it holds exactly 'textLen' bytes of text plus one NUL byte - then '*lengthAt' is the
// offset of its two-byte big-endian length and '*nulAt' the offset of the NUL. Anything else
// (no COM in 'head', a COM without the NUL, another length, a damaged segment chain) is FALSE:
// the caller leaves the file as it is.
inline BOOL SalJpegCommentNul(const BYTE* head, size_t got, size_t textLen, size_t* lengthAt, size_t* nulAt)
{
    if (head == NULL || got < 4 || head[0] != 0xFF || head[1] != 0xD8 || textLen == 0 || textLen > 65532)
        return FALSE;
    size_t i = 2;
    while (i + 4 <= got && head[i] == 0xFF)
    {
        BYTE marker = head[i + 1];
        size_t len = ((size_t)head[i + 2] << 8) | head[i + 3];
        if (marker == 0xFE) // COM
        {
            size_t last = i + 2 + len - 1; // the segment's last byte (len counts its own two bytes)
            if (len != textLen + 3 || last >= got || head[last] != 0)
                return FALSE;
            *lengthAt = i + 2;
            *nulAt = last;
            return TRUE;
        }
        if (marker == 0xDA || len < 2) // the image data begins (no comment before it), or a broken chain
            return FALSE;
        i += 2 + len;
    }
    return FALSE;
}
