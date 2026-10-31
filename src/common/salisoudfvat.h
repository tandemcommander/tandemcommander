// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisoudfvat.h
//
// The virtual allocation table (VAT) of a UDF volume on a sequentially written
// medium (CD-R, DVD-R, BD-R; mkudffs --media-type=cdr) - feature 358.
// Header-only; for the ISO plug-in (uniso: udf.cpp) and saltests.
//
// Every block of such a volume's file set lies in its virtual partition and is
// found through the VAT: entry n holds the physical sector of virtual block n.
// The ISO plug-in's UDF reader opened a volume whose VAT it did not find (an
// image with data past the volume) without a table and then read entry 0
// through a NULL pointer - Tandem Commander closed with an access violation.
// It also accepted the block number equal to the entry count (one past the
// table) and took a VAT 2.00 header length from the table without checking
// it against the table's size (a longer one made the count wrap). Now the
// volume does not open without its VAT, and these rules decide the rest.
//
//*****************************************************************************

// Feature 358: may virtual block 'lbNum' be translated through a VAT of
// 'entries' entries? Only when a table was read and the block is one of its
// entries (0 .. entries - 1).
inline bool SalIsoUdfVatTranslates(unsigned long long lbNum, unsigned long long entries, bool hasTable)
{
    return hasTable && lbNum < entries;
}

// Feature 358: the entry count of a UDF 2.00+ VAT (the file of type 248): its
// file's information length 'infoLen' less the header length 'headerLen' (the
// table's first 16-bit value), in 4-byte entries. 'tableLen' is the number of
// bytes the reader holds for the table. False - the sector is not taken as a
// VAT - when the table holds fewer bytes than the file claims, or the header
// claims more than the file; the count then never reaches past the table.
inline bool SalIsoUdfVat200Entries(unsigned long long infoLen, unsigned long long headerLen,
                                   unsigned long long tableLen, unsigned long long& entries)
{
    entries = 0;
    if (infoLen > tableLen || headerLen > infoLen)
        return false;
    entries = (infoLen - headerLen) / 4;
    return true;
}

// Feature 359: the VAT search's fallback to the track's last sectors. The
// reader looks for the VAT's file entry in a window around the partition's
// claimed end; when a read there fails, it looks at the last 7 sectors of the
// track (the file, or the file's part up to the next track) instead - once.
// The reader reads its search position 'vatLoc' at the track sector
// partStart + vatLoc (32-bit, wrapping) and subtracts the track's extent
// offset from its numbers: in a later session the partition descriptor's start
// is an address on the disc, past the track's own sectors.
//   trackSectors  the track's length in 2048-byte sectors
//   partStart     the partition descriptor's start (PD.Start)
//   extentOffset  the track's first sector on the disc (ExtentOffset)
//   failed        the search position whose read failed
//   taken         the fallback was taken already in this search
// True and the new window [first, last) of search positions when the search
// continues there. False - the search ends with "Error reading virtual
// allocation table" - when the fallback was taken already, when the track ends
// at or before the partition's start in the track (it holds no partition
// sector), when the failed read was not more than 7 sectors past the track's
// end (inside the track, or just past it),
// or when no window position is left. The reader used to compute this in
// 32 bits without a limit: a failed read at a fallback position below 7
// wrapped "failed - 7", the same window was set again and the search never
// ended (Tandem Commander stopped answering - a raw 2352-byte dump cut short,
// whose sectors are counted in 2048 bytes). 'first' < 'last' < 2^32.
inline bool SalIsoUdfVatFallback(unsigned long long trackSectors, unsigned long long partStart,
                                 unsigned long long extentOffset, unsigned long long failed, bool taken,
                                 unsigned long long& first, unsigned long long& last)
{
    const unsigned long long mask = 0xFFFFFFFFull;
    first = last = 0;
    if (taken)
        return false;
    // where the partition starts in the track
    unsigned long long start = partStart >= extentOffset ? partStart - extentOffset : 0;
    if (trackSectors <= start)
        return false;
    // the track sector the failed read asked for (the reader's sum wraps in 32 bits)
    unsigned long long failedAt = (partStart + failed) & mask;
    if (trackSectors + 7 >= failedAt)
        return false;
    unsigned long long from = trackSectors >= start + 7 ? trackSectors - 7 : start;
    // positions below partStart wrap to the top of the 32-bit range: the window must not cross 0
    if (from < partStart && partStart <= trackSectors)
        from = partStart;
    if (from >= trackSectors)
        return false;
    first = (from - partStart) & mask;
    last = (trackSectors - partStart) & mask;
    return first < last;
}

// Feature 360: the VAT's file entry, read into the table buffer. The reader
// (CUDF::ReadVAT, ReadAllocDesc) allocated the table with the file's
// information length cast to 32 bits, took the allocation descriptors' area
// of the 2048-byte sector at 176 (+40 in an extended entry) + L_EA, L_AD
// bytes long, in 32 bits without a bound, and copied each descriptor's data
// (the embedded L_AD bytes, or an extent's length read from the image) into
// the table without comparing it with the bytes left: a damaged entry wrote
// past the table (heap corruption) or read past the sector; a reserved
// descriptor type left the descriptor uninitialised and the walk never
// advanced. An entry these rules refuse is not taken as a VAT (the search
// goes on; without a VAT the volume does not open, feature 358).

// The table's length: the VAT file's information length 'infoLen'. False -
// not a VAT - over 2^32 - 1 (the reader's 32-bit buffer); never cut.
inline bool SalIsoUdfVatTableLength(unsigned long long infoLen, unsigned long& len)
{
    len = 0;
    if (infoLen > 0xFFFFFFFFull)
        return false;
    len = (unsigned long)infoLen;
    return true;
}

// The allocation descriptors' area [first, end) of the file entry in its
// sector of 'sectorLen' bytes: after the entry's fixed part (176 bytes, an
// extended entry 216) and its extended attributes (lEA bytes), lAD bytes long.
// False when the area does not lie in the sector (computed without wrap).
inline bool SalIsoUdfVatDescArea(unsigned long long sectorLen, bool extended, unsigned long long lEA,
                                 unsigned long long lAD, unsigned long long& first, unsigned long long& end)
{
    first = end = 0;
    unsigned long long fixed = extended ? 216 : 176;
    if (fixed > sectorLen || lEA > sectorLen - fixed)
        return false;
    unsigned long long f = fixed + lEA;
    if (lAD > sectorLen - f)
        return false;
    first = f;
    end = f + lAD;
    return true;
}

// The size of one allocation descriptor of the ICB tag's descriptor type
// 'type' (flags & 7): short 8, long 16, extended 20 bytes; 0 for data
// embedded in the entry (type 3 - the whole area is the data); -1 for the
// reserved types 4 - 7 (not a VAT).
inline int SalIsoUdfVatDescSize(unsigned int type)
{
    switch (type)
    {
    case 0:
        return 8;
    case 1:
        return 16;
    case 2:
        return 20;
    case 3:
        return 0;
    default:
        return -1;
    }
}

// A descriptor of 'descLen' bytes (> 0) at 'pos' lies in the area ending at
// 'end'. False for a descriptor cut by the area's end.
inline bool SalIsoUdfVatDescFits(unsigned long long pos, unsigned long long descLen, unsigned long long end)
{
    return descLen > 0 && pos <= end && descLen <= end - pos;
}

// A copy of 'length' bytes (the embedded data, or one extent) fits the table
// of 'tableLen' bytes after the 'written' bytes copied so far. False - not a
// VAT - when the descriptors claim more than the file's information length.
inline bool SalIsoUdfVatCopyFits(unsigned long long written, unsigned long long length, unsigned long long tableLen)
{
    return written <= tableLen && length <= tableLen - written;
}
