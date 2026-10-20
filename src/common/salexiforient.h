// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salexiforient.h
//
// Feature 267: how PictView turns a picture by its Exif orientation tag (tag 274
// of IFD0) - a pure rule, so saltests can check it.
//
// The tag says where the stored picture's row 0 and column 0 belong when it is
// shown (Exif 2.3 / TIFF 6.0):
//   1 as stored               2 mirrored left-right       3 turned 180
//   4 mirrored top-bottom     5 transposed (row 0 = left, column 0 = top)
//   6 turned 90 clockwise     7 transversed (row 0 = right, column 0 = bottom)
//   8 turned 90 counter-clockwise
// The viewer has a quarter turn (CMD_ROTATE_RIGHT / CMD_ROTATE_LEFT, it turns
// the image) and two mirrors (CMD_MIRROR_HOR / CMD_MIRROR_VERT, view flags). Its
// turn reverses its direction while a mirror is active, so the result here is
// applied in this order: the quarter turn first, then the mirrors of the turned
// picture. A value outside 1..8 (absent, damaged) is "as stored".
//
// The old table (Open Salamander, dead since feature 006: the engine never
// reported PVFF_EXIF) mirrored 4 left-right and turned 5 and 7 without the
// mirror. The pixel size recorded in the Exif block is not consulted (the old
// exception "recorded size portrait or different - do not turn" showed half of
// the standard orientation samples wrong; panel thumbnails never applied it).
//
// Header-only: PictView and saltests share it.
//
//*****************************************************************************

// what to do with a picture of the orientation tag 'orient': Quarter = +1 a quarter turn
// clockwise, -1 counter-clockwise, 0 none; then MirrorHor (left-right) and MirrorVert
// (top-bottom) of the turned picture
struct CSalExifTurn
{
    int Quarter;
    bool MirrorHor;
    bool MirrorVert;
};

inline CSalExifTurn SalExifOrientTurn(int orient)
{
    CSalExifTurn t = {0, false, false};
    switch (orient)
    {
    case 2:
        t.MirrorHor = true;
        break;
    case 3:
        t.MirrorHor = t.MirrorVert = true;
        break;
    case 4:
        t.MirrorVert = true;
        break;
    case 5:
        t.Quarter = 1;
        t.MirrorHor = true;
        break;
    case 6:
        t.Quarter = 1;
        break;
    case 7:
        t.Quarter = 1;
        t.MirrorVert = true;
        break;
    case 8:
        t.Quarter = -1;
        break;
    }
    return t;
}
