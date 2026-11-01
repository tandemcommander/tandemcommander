// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisoudfentry.h
//
// The allocation descriptors of a UDF file entry, as the ISO plug-in's general
// file-entry reader walks them (uniso: CUDF::ReadFileEntry(data, bEFE, part,
// icbTag, ad, maxAds) - the root folder, every sub-folder, a file at unpack,
// the metadata partition) - feature 361. Header-only; for uniso and saltests.
//
// The reader took the descriptors' area of the 2048-byte sector at 176 (+40 in
// an extended entry) + L_EA, L_AD bytes long, in 32 bits without comparing it
// with the sector, and walked it with a switch on the ICB's descriptor type
// that had no case for the reserved types 4 - 7: such an entry never advanced
// the walk (Tandem Commander stopped answering while the image was listed or
// unpacked), and a large L_EA or L_AD read past the sector buffer (an access
// violation, or bytes past the buffer taken as descriptors or as the data of
// a small file). The questions are the ones feature 360 decided for the VAT's
// entry (salisoudfvat.h); its rules decide them here too.
//
//*****************************************************************************

#include "salisoudfvat.h"

// May the reader walk the descriptors of a file entry in a sector of
// 'sectorLen' bytes - an extended entry or not, with lEA bytes of extended
// attributes, lAD bytes of descriptors and the ICB descriptor type 'type'
// (flags & 7)? True with the area [first, end) and the size of one descriptor
// (8 short, 16 long, 20 extended; 0 - data embedded in the entry, the whole
// area is the data). False - the entry is refused - when the area does not
// lie in the sector (computed without wrap), the type is reserved (4 - 7, also
// with an empty area: the entry is invalid), or the area is not a whole number
// of descriptors (one would be cut by the area's end). The walk
// "for (p = first; p < end; p += size)" then always ends and reads only the
// sector's bytes.
inline bool SalIsoUdfEntryDescs(unsigned long long sectorLen, bool extended, unsigned long long lEA,
                                unsigned long long lAD, unsigned int type, unsigned long long& first,
                                unsigned long long& end, int& size)
{
    first = end = 0;
    size = -1;
    int s = SalIsoUdfVatDescSize(type);
    if (s < 0)
        return false;
    unsigned long long f, e;
    if (!SalIsoUdfVatDescArea(sectorLen, extended, lEA, lAD, f, e))
        return false;
    if (s > 0 && lAD % (unsigned long long)s != 0)
        return false;
    first = f;
    end = e;
    size = s;
    return true;
}

// May the ISO plug-in walk a FOLDER whose file entry the reader above read with
// room for one descriptor - 'stored' is the reader's result: the number of
// descriptors stored (> 0), -1 for data embedded in the entry (only for a
// non-empty area), 0 for no descriptor at all (L_AD 0, of any valid type, also
// an embedded entry), or the refusal (another negative value); 'firstLen' is
// the byte length the first descriptor gives (its extent length without the
// type bits; the embedded data's length) - feature 362.
// A folder always holds at least the identifier of its parent (ECMA-167
// 4/14.4: a File Identifier Descriptor of 38 bytes + its names, padded to 4 -
// 40 in every image measured; the root one pointing to itself), so an entry
// whose first extent cannot hold one is damaged - no descriptor, a first
// extent of length 0 (which ends the descriptor sequence, ECMA-167 4/12,
// review 1) or shorter than an identifier (review 2: 20 bytes): it was walked
// over that length, listed empty without a mark, and a whole unpack with
// "Delete archive after unpacking" deleted the image. False sends it down the
// unreadable-folder path (the root "Bad root ICB", a sub-folder listed empty
// with the listing incomplete - feature 330).
const unsigned long long SAL_ISO_UDF_MIN_FID = 38;
inline bool SalIsoUdfFolderEntryWalkable(int stored, unsigned long long firstLen)
{
    return (stored > 0 || stored == -1) && firstLen >= SAL_ISO_UDF_MIN_FID;
}

// May the folder walk read the File Identifier Descriptor at position 'pos' of
// a buffer of 'held' bytes, whose name length is lFI (8 bits) and whose
// implementation-use length is lIU (16 bits), both from the image? True with
// 'len' = the identifier's length padded to 4 bytes (ECMA-167 4/14.4:
// 38 + L_IU + L_FI, the step to the next identifier) when the whole padded
// identifier lies in [pos, held); false with 'len' 0 otherwise (computed in
// 64 bits by subtracting from what is left, so nothing wraps) -
// feature 363. The walk (uniso: CUDF::ScanDir, two sectors, each identifier
// read at most one sector in) took the name at 38 + L_IU, L_FI bytes, and the
// next position without comparing them with its buffer: an L_IU of 0xFFFF read
// the name 64 KB past it, listed the entry as "_" and went on, and a whole
// unpack with "Delete archive after unpacking" deleted the image. UDF limits
// an identifier to one logical block (2.01, 2.3.4), so a valid one read at most
// one sector into two sectors always fits; false sends the folder down the
// invalid-tag path (its walk ends, the listing is incomplete - feature 330).
inline bool SalIsoUdfFidLength(unsigned long long held, unsigned long long pos, unsigned long long lFI,
                               unsigned long long lIU, unsigned long long& len)
{
    len = 0;
    if (pos > held)
        return false;
    unsigned long long rest = held - pos; // the bytes from the identifier to the buffer's end
    if (rest < SAL_ISO_UDF_MIN_FID)
        return false;
    rest -= SAL_ISO_UDF_MIN_FID;
    if (lIU > rest)
        return false;
    rest -= lIU;
    if (lFI > rest)
        return false;
    rest -= lFI;
    unsigned long long n = SAL_ISO_UDF_MIN_FID + lIU + lFI; // <= held: no wrap
    unsigned long long pad = (4 - n % 4) % 4;
    if (pad > rest)
        return false;
    len = n + pad;
    return true;
}
