// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salzipcount.h
//
// Feature 165: the entry counts of a ZIP archive's end records. Header-only,
// no globals (the ZIP plug-in cannot compile a shared .cpp file), checked by
// saltests.
//
// The end of central directory record holds the number of entries (in all and
// on this disk) in 16 bits; 0xFFFF there means "see the zip64 end record"
// (APPNOTE 4.4.21-22), which holds them in 64 bits. The ZIP plug-in kept the
// counts in the 16-bit fields only: reading an archive of 65,535 or more
// entries kept 0xFFFF and every deletion counted down from it (100,000 -> 50,000
// members wrote 15,535), adding counted up past 65,535 and wrapped, and the
// zip64 end record was written only for a directory's size or offset. Now the
// plug-in counts in 64 bits and derives what it writes from them here.
//
//*****************************************************************************

#include "salzipmember.h"

// The 16-bit fields for 'total' entries in all and 'disk' on this disk: the
// count, or 0xFFFF from 0xFFFF on. TRUE when the zip64 end record is needed
// for the counts (one of them does not fit).
inline bool SalZipEndRecordCounts(unsigned long long total, unsigned long long disk, unsigned short* total16,
                                  unsigned short* disk16)
{
    *total16 = (unsigned short)(total >= 0xFFFFULL ? 0xFFFF : total);
    *disk16 = (unsigned short)(disk >= 0xFFFFULL ? 0xFFFF : disk);
    return total >= 0xFFFFULL || disk >= 0xFFFFULL;
}

// The count a reader takes from an archive's end records: the zip64 value when
// a zip64 end record was read and the 16-bit field says so (0xFFFF, APPNOTE
// 4.4.22), else the 16-bit field.
inline unsigned long long SalZipReadEntryCount(unsigned short field16, bool hasZip64, unsigned long long zip64Value)
{
    return (hasZip64 && field16 == 0xFFFF) ? zip64Value : field16;
}

// The records of the central directory 'dir' ('dirLen' bytes) into *count -
// the count an archive that is changed is written with (its end record may be
// wrong: an earlier version wrote 4,464 for 70,000 entries). false when the
// directory does not end with a whole record (*count: the whole ones before).
inline bool SalZipCountCentralRecords(const unsigned char* dir, size_t dirLen, unsigned long long* count)
{
    *count = 0;
    if (dir == NULL)
        return dirLen == 0;
    size_t p = 0;
    while (p < dirLen)
    {
        size_t len = SalZipCentralRecordLen(dir + p, dirLen - p);
        if (len == 0)
            return false;
        (*count)++;
        p += len;
    }
    return true;
}
