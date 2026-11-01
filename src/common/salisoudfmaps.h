// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisoudfmaps.h
//
// The partition map table of a UDF logical volume descriptor (ECMA-167
// 3/10.6), as the ISO plug-in's UDF reader takes it (uniso: CUDF::ReadLVD /
// ReadPartitionMap) - feature 378. Header-only; for uniso and saltests.
//
// The descriptor gives the table's length (MT_L, byte 264), the number of maps
// (N_PM, byte 268) and, from byte 440, the maps one after another, each giving
// its own length in its second byte. The reader took N_PM maps, moving on by
// each map's length, without comparing either with the 2048-byte sector it
// held or with MT_L: a damaged or crafted count read past the sector buffer
// (other bytes of the stack taken as partition maps), and a map length of 0
// recorded one partition map per declared map without moving on (up to 2^32
// of them). A volume whose maps do not fit is now refused before any map is
// recorded - it does not open.
//
//*****************************************************************************

// The partition maps start at this byte of the descriptor.
const unsigned long long SAL_ISO_UDF_LVD_MAPS = 440;

// The number of bytes the reader takes from a partition map of type 'type':
// type 1 (physical) its 6 bytes (the volume sequence number at 2 and the
// partition number at 4); type 2 the entity identifier at 4 (32 bytes), the
// volume sequence number at 36, the partition number at 38 and the metadata
// file location at 40 - 44 bytes (ECMA-167 makes a type 2 map 64 bytes; a
// shorter one that holds these is read as before); any other type only its
// two header bytes (type and length).
inline unsigned long long SalIsoUdfPartitionMapMinLen(unsigned int type)
{
    if (type == 1)
        return 6;
    if (type == 2)
        return 44;
    return 2;
}

// May the reader take the partition maps of the logical volume descriptor
// 'lvd', of which it holds 'held' bytes (the sector; at least the fixed part of
// 440 bytes)? The maps are read in the area [440, min(held, 440 + MT_L)) -
// inside the sector and inside the declared table. True with 'count' = N_PM
// when every declared map lies wholly in the area: its type and length bytes
// in it, a length of at least 2 and at least SalIsoUdfPartitionMapMinLen of its
// type, and its end in it (computed in 64 bits by subtracting from what is
// left, nothing wraps). False with 'count' 0 otherwise - a count larger than
// the maps that fit, a length of 0 or 1, a map running past the table or the
// sector, a map shorter than the bytes read from its type; the volume is then
// refused. A count of 0 is true (no map is read - as before). A table longer
// than the sector whose declared maps all lie in the sector is read as before.
// The walk "offset = 440; for (i < count) offset += lvd[offset + 1]" then ends
// after 'count' steps and reads only bytes of the area; it takes at most
// (held - 440) / 2 steps before it is refused.
inline bool SalIsoUdfLvdMapsFit(const unsigned char* lvd, unsigned long long held, unsigned long long& count)
{
    count = 0;
    if (lvd == nullptr || held < SAL_ISO_UDF_LVD_MAPS)
        return false;
    unsigned long long mapLen = (unsigned long long)lvd[264] | ((unsigned long long)lvd[265] << 8) |
                                ((unsigned long long)lvd[266] << 16) | ((unsigned long long)lvd[267] << 24);
    unsigned long long maps = (unsigned long long)lvd[268] | ((unsigned long long)lvd[269] << 8) |
                              ((unsigned long long)lvd[270] << 16) | ((unsigned long long)lvd[271] << 24);
    unsigned long long end = held;
    if (mapLen < held - SAL_ISO_UDF_LVD_MAPS)
        end = SAL_ISO_UDF_LVD_MAPS + mapLen;
    unsigned long long pos = SAL_ISO_UDF_LVD_MAPS;
    for (unsigned long long i = 0; i < maps; i++)
    {
        if (end - pos < 2) // pos <= end always
            return false;
        unsigned long long len = lvd[pos + 1];
        if (len < 2 || len < SalIsoUdfPartitionMapMinLen(lvd[pos]) || len > end - pos)
            return false;
        pos += len;
    }
    count = maps;
    return true;
}
