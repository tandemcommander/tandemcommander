// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisowalk.h
//
// The folder walk of the ISO plug-in's readers (ISO 9660, UDF, Xbox) after a
// folder that cannot be read - feature 400. Header-only; for the ISO plug-in
// (uniso: iso9660.cpp, udf.cpp, xdvdfs.cpp) and saltests.
//
// A walk descended a listed folder only while nothing in its directory and
// below had failed ("descend only when everything is OK"), and a failure was
// passed to every ancestor: after one folder that could not be read (its
// directory past the end of the image, a record failing the safety checks),
// every later folder of the image was listed empty - readable files could not
// be viewed or extracted. Now a walk descends every listed folder unless out
// of memory stopped it; a failure below still makes the directory (and the
// listing, feature 330) incomplete; and the walk shows its error box once
// (a damaged or crafted image with many such folders showed one box before,
// because the walk ended its descents).
//
//*****************************************************************************

// The result of a directory's walk - the same values as the plug-in's ERR_OK,
// ERR_CONTINUE and ERR_TERMINATE (isoimage.h; each reader asserts it): the
// directory was walked whole; it was walked but something in it or below could
// not be listed; it could not go on (its read failed, a record failed the
// checks, out of memory).
enum
{
    SAL_ISO_WALK_OK = 0,
    SAL_ISO_WALK_CONTINUE = 1,
    SAL_ISO_WALK_TERMINATE = 2
};

// One walk of one file system of an image (reset when its listing starts).
struct SalIsoWalk
{
    bool Stopped;  // out of memory met: no later folder of the walk is descended
    bool BoxShown; // the walk's error box was shown

    SalIsoWalk() : Stopped(false), BoxShown(false) {}
};

// Feature 400: may the walk descend a folder the listing took? Yes - also after
// a folder that could not be read - unless out of memory stopped the walk
// (going on would fail again in every later folder).
inline bool SalIsoWalkDescends(const SalIsoWalk& walk)
{
    return !walk.Stopped;
}

// Feature 400: a directory's walk result 'ret' after a folder in it was walked
// with the result 'child'. A failure below makes the directory incomplete
// (CONTINUE) and is never forgotten by a later folder that walks whole (the old
// code assigned the child's result - harmless only while nothing was descended
// after a failure); it never ends the directory itself.
inline int SalIsoWalkAfterChild(int ret, int child)
{
    if (ret == SAL_ISO_WALK_TERMINATE)
        return ret;
    return child == SAL_ISO_WALK_OK ? ret : SAL_ISO_WALK_CONTINUE;
}

// Feature 400: is this error box of the walk to be quiet? A quiet walk (the ISO
// 9660 reader's fit check and count walks, feature 328) stays quiet and does not
// use up the box; otherwise the walk's first box is shown and every later one is
// quiet (the listing is marked incomplete by the caller as before).
inline bool SalIsoWalkBoxQuiet(SalIsoWalk& walk, bool quiet)
{
    if (quiet || walk.BoxShown)
        return true;
    walk.BoxShown = true;
    return false;
}

// Feature 401: the key by which a walk recognises a folder it met before - the
// start of the folder's directory (block or sector) and its length together.
// Every folder record of an image gives its own length: two records naming one
// start with different lengths read different bytes, and a key by the start
// alone listed the second folder empty without a mark (its later files lost, the
// image deleted by a whole unpack - 400's Xbox walk, 328's ISO 9660 walk). A
// walk stays bounded: each pair is walked once, and the pairs come from the
// image's records - at most one walk per folder record, so a crafted image of N
// records naming one directory with N lengths lists N copies of it (work and
// memory grow with N squared; 401 review 1: N = 2,000 took 19 s, 525 MB - its
// real content, a listing budget is an Inbox item).
inline unsigned long long SalIsoFolderVisitKey(unsigned long start, unsigned long length)
{
    return ((unsigned long long)length << 32) | (unsigned long long)start;
}

// Feature 403: the largest length the ISO 9660 walk takes as a directory's length. A
// 2048-byte sector holds about 6 (long Rock Ridge names) to 40 (short ISO names)
// records, so 256 MiB is far more than any real folder holds; a larger length (and
// every length of 2 GiB or more - the walk held it as a signed int, and the core's
// allocator offered only to end the program) comes from a damaged or crafted record.
const unsigned long long SAL_ISO_DIR_MAX_LENGTH = 256ULL * 1024 * 1024;

// Feature 403: may the ISO 9660 walk allocate and read a directory of 'length' bytes
// (a folder record's data length)? Only 1 .. SAL_ISO_DIR_MAX_LENGTH; any other length
// is a folder that cannot be read (features 330 / 400: the walk's box once, the listing
// incomplete, later folders walked). A length of 0 is decided by the caller as before.
inline bool SalIsoDirLengthReadable(unsigned long long length)
{
    return length > 0 && length <= SAL_ISO_DIR_MAX_LENGTH;
}

// Feature 403: the last sector of a directory of 'length' bytes that starts at sector
// 'block', with 'sectorSize' bytes a sector, in 64-bit (no wrap). False - the directory
// cannot be read - when the length or the sector size is 0, or the last sector lies past
// sector 0xFFFFFFFF (the image is read by 32-bit sector numbers). The walk reads that
// sector before it allocates the directory's buffer: a directory past the end of the
// image is a folder that cannot be read without first taking its memory.
inline bool SalIsoDirLastBlock(unsigned long long block, unsigned long long length, unsigned long long sectorSize,
                               unsigned long long* last)
{
    if (length == 0 || sectorSize == 0 || block > 0xFFFFFFFFULL)
        return false;
    unsigned long long more = (length - 1) / sectorSize; // the sectors after the first
    if (more > 0xFFFFFFFFULL - block)                    // compared with the room left: no wrap
        return false;
    if (last != nullptr)
        *last = block + more;
    return true;
}

// Feature 403 (review 1): the walk holds a folder's buffer while it walks the folders
// below, so a chain of nested folders, each readable and within the limit, held one
// buffer per level at once (measured: 256 MiB more per level; ~125 levels fit the
// listing's path) - the core's memory box again. 'held' is the bytes of the buffers the
// walk holds now (count walks inside it included). Takes 'length' and returns true when
// the folder may be read: its length is readable (SalIsoDirLengthReadable) and all held
// buffers together stay within SAL_ISO_DIR_MAX_LENGTH; false - a folder that cannot be
// read, 'held' unchanged.
inline bool SalIsoDirTake(unsigned long long& held, unsigned long long length)
{
    if (!SalIsoDirLengthReadable(length) || held > SAL_ISO_DIR_MAX_LENGTH || length > SAL_ISO_DIR_MAX_LENGTH - held)
        return false;
    held += length;
    return true;
}

// Feature 403 (review 1): gives back what SalIsoDirTake took (the folder's buffer freed).
inline void SalIsoDirGive(unsigned long long& held, unsigned long long length)
{
    held = length <= held ? held - length : 0;
}
