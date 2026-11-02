// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisoxboxentry.h
//
// The bounds of an entry of an Xbox (XDVDFS) directory, as the ISO plug-in's
// folder walk reads it (uniso: CXDVDFS::ScanDir) - feature 402. Header-only;
// for uniso and saltests.
//
// The walk holds a directory in a buffer of the size its parent entry (or the
// volume descriptor, for the root) gives. An entry is a 14-byte head - left
// and right subtree offsets (2 + 2), start sector (4), file size (4),
// attributes (1), name length (1) - then the name; the next entry starts at
// the end of the name rounded up to 4. The walk checked only that the head
// lies in the buffer and then copied the name's length from it: a damaged or
// crafted image whose last entry's name runs past the directory's end gave a
// name made of the bytes after the buffer (measured: the Debug heap's 0xFD
// guard bytes in the listed and extracted names), the listing not marked, and
// a whole unpack with "Delete archive after unpacking" deleted the image.
//
//*****************************************************************************

// The size of an entry's head (up to and including the name length).
enum
{
    SAL_ISO_XBOX_ENTRY_HEAD = 14
};

// Does the head of the entry at 'offset' lie in a directory of 'size' bytes?
// Computed without wrap (an offset past the size is false).
inline bool SalIsoXboxEntryHeadFits(unsigned long long size, unsigned long long offset)
{
    return offset <= size && size - offset >= SAL_ISO_XBOX_ENTRY_HEAD;
}

// Does the entry at 'offset' lie whole in a directory of 'size' bytes - its
// head and its name of 'nameLen' bytes? True with 'next' = the offset of the
// next entry (the name's end rounded up to 4; it may lie past 'size' by up to
// 3 - the walk then ends, its head does not fit). False - a damaged record:
// the name would be read past the directory's bytes - with 'next' = 0. All in
// 64 bits: no 32-bit offset wraps near the end of a 4 GiB directory (rounding
// 0xFFFFFFFF up to 4 in 32 bits gives 0 and would restart the walk).
inline bool SalIsoXboxEntryFits(unsigned long long size, unsigned long long offset, unsigned int nameLen,
                                unsigned long long& next)
{
    next = 0;
    if (!SalIsoXboxEntryHeadFits(size, offset))
        return false;
    if (size - offset - SAL_ISO_XBOX_ENTRY_HEAD < nameLen)
        return false;
    next = (offset + SAL_ISO_XBOX_ENTRY_HEAD + nameLen + 3) / 4 * 4;
    return true;
}
