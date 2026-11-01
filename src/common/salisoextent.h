// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisoextent.h
//
// ISO 9660 files stored in several extents (feature 368). Header-only; for the
// ISO plug-in (uniso: iso9660.cpp, isoimage.cpp) and saltests.
//
// ISO 9660 level 3 stores a file in several extents (file sections): the
// directory holds one record per extent, all with the file's identifier, and
// every record but the last has the multi-extent bit (bit 7) of its file flags
// set (ECMA-119 9.1.6). A file of 4 GiB or more is always stored so - one
// record's data length is a 32-bit number. The file's content is the extents'
// data in record order, each its record's data length.
//
// The ISO plug-in listed each record as a file of its own name, and an unpack
// wrote them one over the other (only the last part was left). Now a directory
// walk keeps a chain (SalIsoExtentChain): the records of one chain are listed
// as one file of the summed size once its last record is met; a chain that
// ends otherwise (another identifier, a folder, the end of the directory) is
// broken - the caller leaves the file out and reports it (never a cut file
// extracted as if whole). SalIsoChainReadable decides whether the plug-in's
// reader can read a complete chain; SalIsoExtentSectors / SalIsoExtentSectorBytes
// give what the reader writes of each sector of an extent.
//
//*****************************************************************************

#include <cstddef>
#include <string>
#include <vector>

const unsigned SAL_ISO_FILE_FLAG_DIRECTORY = 0x02;
const unsigned SAL_ISO_FILE_FLAG_MULTI_EXTENT = 0x80;
const unsigned long long SAL_ISO_EXTENT_SECTOR = 2048; // the logical block of an extent

struct SalIsoExtent
{
    unsigned long Location; // the extent's first sector (disc address, as the record stores it)
    unsigned long Length;   // the record's data length in bytes
};

// a record continues its file in the next record: a file record (not a folder) with the multi-extent bit; the
// bit on a folder record means nothing (the folder is listed as before)
inline bool SalIsoRecordContinues(unsigned flags)
{
    return (flags & SAL_ISO_FILE_FLAG_DIRECTORY) == 0 && (flags & SAL_ISO_FILE_FLAG_MULTI_EXTENT) != 0;
}

// the sectors an extent of 'length' bytes spans (2048-byte logical blocks, rounded up; 0 for 0)
inline unsigned long long SalIsoExtentSectors(unsigned long long length)
{
    return length / SAL_ISO_EXTENT_SECTOR + (length % SAL_ISO_EXTENT_SECTOR != 0 ? 1 : 0);
}

// the bytes of the file sector 'sector' (0-based) of an extent of 'length' bytes holds: 2048, or the rest of the
// extent in its last sector; 0 past the extent
inline unsigned long SalIsoExtentSectorBytes(unsigned long long length, unsigned long long sector)
{
    unsigned long long at = sector * SAL_ISO_EXTENT_SECTOR;
    if (sector >= SalIsoExtentSectors(length) || at >= length)
        return 0;
    unsigned long long rest = length - at;
    return (unsigned long)(rest < SAL_ISO_EXTENT_SECTOR ? rest : SAL_ISO_EXTENT_SECTOR);
}

// the file's size: the sum of its extents' lengths (64-bit - a file of 4 GiB or more)
inline unsigned long long SalIsoExtentsSize(const SalIsoExtent* e, size_t n)
{
    unsigned long long size = 0;
    for (size_t i = 0; e != NULL && i < n; i++)
        size += e[i].Length;
    return size;
}

// the open chain of one directory walk
struct SalIsoExtentChain
{
    bool Open;                         // a record with the bit was met and its chain has not ended
    size_t FirstOffset;                // the offset of the chain's first record in the directory data (it names the file)
    std::string Id;                    // the raw identifier of the first record
    std::vector<SalIsoExtent> Extents; // the extents met so far, in record order

    SalIsoExtentChain() : Open(false), FirstOffset(0) {}
};

// SalIsoChainRecord results
#define SAL_ISO_CHAIN_LIST 0 // list the record as it is (a folder, or a file of one extent)
#define SAL_ISO_CHAIN_HELD 1 // the record belongs to the open chain; nothing is listed yet
#define SAL_ISO_CHAIN_DONE 2 // the chain ended with this record: list it as one file (named by FirstOffset's record)

// the next record of a directory walk ('offset' in the directory data, its raw identifier, file flags, extent and
// data length). '*broke' = true when an open chain was broken by this record (another identifier, or a folder):
// the caller reports it, and the record then gets its own action. After SAL_ISO_CHAIN_DONE the caller lists
// c.Extents and closes the chain (SalIsoChainClose). May throw std::bad_alloc (the caller: out of memory).
inline int SalIsoChainRecord(SalIsoExtentChain& c, size_t offset, const unsigned char* id, size_t idLen,
                             unsigned flags, unsigned long location, unsigned long length, bool* broke)
{
    if (broke != NULL)
        *broke = false;
    bool folder = (flags & SAL_ISO_FILE_FLAG_DIRECTORY) != 0;
    if (c.Open)
    {
        bool same = !folder && idLen == c.Id.size() && (idLen == 0 || c.Id.compare(0, idLen, (const char*)id, idLen) == 0);
        if (same)
        {
            SalIsoExtent e = {location, length};
            c.Extents.push_back(e);
            return SalIsoRecordContinues(flags) ? SAL_ISO_CHAIN_HELD : SAL_ISO_CHAIN_DONE;
        }
        // the chain ends without its last record
        c.Open = false;
        c.Extents.clear();
        c.Id.clear();
        if (broke != NULL)
            *broke = true;
    }
    if (!SalIsoRecordContinues(flags))
        return SAL_ISO_CHAIN_LIST;
    c.Extents.clear();
    c.Id.assign((const char*)id, idLen);
    SalIsoExtent e = {location, length};
    c.Extents.push_back(e);
    c.FirstOffset = offset;
    c.Open = true;
    return SAL_ISO_CHAIN_HELD;
}

// closes the chain after SAL_ISO_CHAIN_DONE (or on an error of the walk)
inline void SalIsoChainClose(SalIsoExtentChain& c)
{
    c.Open = false;
    c.Extents.clear();
    c.Id.clear();
}

// the directory ended: true when a chain was still open (it is broken); the chain is closed
inline bool SalIsoChainEnd(SalIsoExtentChain& c)
{
    bool broken = c.Open;
    SalIsoChainClose(c);
    return broken;
}

// can the plug-in's reader read a complete chain of 'n' extents? It opens the track of the first extent and reads
// every sector from it 2048 bytes at a time: every extent must lie in that track (trackOf), at or after the track's
// first disc address (offsetOf), its sectors within 32-bit sector numbers, and the track must not store Mode 2
// Form 2 data ('firstTrackStoresForm2' - features 366 / 367 read such files per record; a chain there fails
// closed). 'trackCount' 0 or no extent: false.
template <class TrackOf, class TrackOffset>
inline bool SalIsoChainReadable(const SalIsoExtent* e, size_t n, int trackCount, TrackOf trackOf, TrackOffset offsetOf,
                                bool firstTrackStoresForm2)
{
    if (e == NULL || n == 0 || trackCount <= 0 || firstTrackStoresForm2)
        return false;
    int first = trackOf(e[0].Location);
    if (first < 0 || first >= trackCount)
        return false;
    unsigned long long trackStart = offsetOf(first);
    for (size_t i = 0; i < n; i++)
    {
        if (trackOf(e[i].Location) != first || e[i].Location < trackStart)
            return false;
        unsigned long long sectors = SalIsoExtentSectors(e[i].Length);
        if (sectors > 0 && (unsigned long long)e[i].Location + sectors - 1 > 0xFFFFFFFFULL)
            return false;
    }
    return true;
}
