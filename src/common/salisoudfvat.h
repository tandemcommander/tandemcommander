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

// Feature 359: the VAT search's fallback to the file's last sectors. The
// reader looks for the VAT's file entry in a window of partition sectors
// around the partition's claimed end; when a read there fails, it looks at
// the last 7 partition sectors the file holds instead - once.
//   fileSectors  the file's (track's) length in 2048-byte sectors
//   partStart    the partition's first sector
//   failed       the partition sector whose read failed
//   taken        the fallback was taken already in this search
// True and the new window [first, last) of partition sectors when the search
// continues there. False - the search ends with "Error reading virtual
// allocation table" - when the fallback was taken already, when the file ends
// at or before the partition start (it holds no partition sector), or when
// the failed sector lies within 7 sectors past the file's partition sectors.
// The reader used to compute this in 32 bits without a limit: a failed read at
// a fallback sector below 7 wrapped "failed - 7", the same window was set
// again and the search never ended (Tandem Commander stopped answering - a raw
// 2352-byte dump cut short, whose sectors are counted in 2048 bytes).
// 'first' < 'last' <= 'failed', so both fit the reader's 32-bit sector numbers.
inline bool SalIsoUdfVatFallback(unsigned long long fileSectors, unsigned long long partStart,
                                 unsigned long long failed, bool taken,
                                 unsigned long long& first, unsigned long long& last)
{
    first = last = 0;
    if (taken || fileSectors <= partStart)
        return false;
    unsigned long long n = fileSectors - partStart; // the partition's sectors in the file, at least 1
    if (n + 7 >= failed)
        return false;
    first = n >= 7 ? n - 7 : 0;
    last = n;
    return true;
}
