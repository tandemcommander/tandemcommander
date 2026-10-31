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
