// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The sort arrow of a list header painted by the program itself (feature 407)
//
// The dark theme's header items are painted by the program (features 044 and
// 049: the dark header theme keeps black label text), which skipped the sort
// arrow Windows draws for HDF_SORTUP / HDF_SORTDOWN - the Find window's sorted
// column showed nothing in the dark theme (review 2 of feature 407). The arrow
// is drawn as Windows draws it in the light theme: a chevron at the top centre
// of the item, in the label colour.
//
// SalSortArrowChevron - the three points of the chevron (a polyline) for the
//                     item rectangle [left, right) x [top, bottom) and the
//                     height of the header's font: half width k = fontHeight / 4,
//                     at least 3; it starts one pixel below the top. Up: the apex
//                     at the top; down: the apex at the bottom. FALSE (nothing is
//                     drawn) when the item is narrower than the chevron or lower
//                     than its height plus two pixels.
//
//*****************************************************************************

struct CSalArrowPoints
{
    int X[3];
    int Y[3];
};

inline bool SalSortArrowChevron(int left, int top, int right, int bottom, int fontHeight, bool up, CSalArrowPoints* out)
{
    int k = fontHeight / 4;
    if (k < 3)
        k = 3;
    if (right - left < 2 * k + 1 || bottom - top < k + 2)
        return false;
    int cx = left + (right - left) / 2;
    int y0 = top + 1;     // the edge at the top
    int y1 = top + 1 + k; // the edge k pixels lower
    out->X[0] = cx - k;
    out->X[1] = cx;
    out->X[2] = cx + k;
    out->Y[0] = up ? y1 : y0;
    out->Y[1] = up ? y0 : y1;
    out->Y[2] = up ? y1 : y0;
    return true;
}
