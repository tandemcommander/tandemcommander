// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnrgcdtext.h
//
// The bounds of the NRG (Nero image) chunks the ISO plug-in reads for audio
// tracks (feature 331). Header-only, no globals; for the ISO plug-in (uniso,
// nrg.cpp, audio.cpp) and saltests.
//
// The CD-Text chunk (CDTX) holds 18-byte packs of a 4-byte header, 12 text
// bytes and a 2-byte CRC; the reader skips 4 bytes, then takes 12 and skips
// 6 (the CRC and the next pack's header) - "4 flag bytes and 18-byte blocks"
// below. The text is the volume label and one label per track, each
// 0-terminated. The chunk's size, the DAOX chunk's track numbers and the
// labels' lengths all come from the image:
//
//   - a chunk is read only when its bytes lie within the image
//     (SalNrgChunkFits) - the reader sized its buffer as Size + 1 + tracks in
//     32-bit arithmetic, which wraps for a size near 4 GiB;
//   - the text is gathered from the blocks only within the chunk
//     (SalNrgCdTextGather; for a size that is not a whole number of packs the
//     old loop read up to 4 bytes past it) and split
//     by length (SalNrgCdTextNext; a label without a terminator ends at the
//     text's end) - no terminator area past the text;
//   - a DAOX entry applies only to a track the CUEX chunk added
//     (SalNrgDaoTrackInRange, numbers 1..count);
//   - an audio track's listed name is built on the heap whole, never cut
//     (SalNrgAudioTrackNameAlloc; it was formatted into char[MAX_PATH]) -
//     the panel listing's rule then lists it or leaves it out (feature 329);
//   - the CUEX chunk: Nero writes 8-byte index records (the lead-in, per track
//     index 0 and each index 1..99, the lead-out); the reader takes the first
//     16 bytes as a header and makes one audio track per following 16 bytes
//     (an "entry" - one track only when every track has index 0 and 1; with
//     more index points it makes extra tracks the DAOX chunk does not fill,
//     as before). The chunk gives only the whole entries its own size holds
//     (SalNrgCuexEntryCount, feature 350; (Size - 16) / 16 in 32 bits
//     underflowed for a chunk under 16 bytes to 268 million entries, one track
//     built from every 16 bytes up to the end of the file) and is read only
//     when it lies within the image and is no larger than a disc's CUEX can be
//     (SalNrgCuexSizePlausible: 2 + 99 x 100 records).
//
//*****************************************************************************

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SAL_NRG_CDTX_FLAGS 4  // bytes of flags before the first block
#define SAL_NRG_CDTX_TEXT 12  // text bytes of a block
#define SAL_NRG_CDTX_BLOCK 18 // bytes of a block (text + other data)

// true when a chunk of 'size' bytes starting at 'pos' lies within a file of 'fileSize' bytes
inline bool SalNrgChunkFits(unsigned long long pos, unsigned long long size, unsigned long long fileSize)
{
    return pos <= fileSize && size <= fileSize - pos;
}

// the number of text bytes a CD-Text chunk of 'size' bytes holds (never more than 'size')
inline size_t SalNrgCdTextLen(size_t size)
{
    if (size <= SAL_NRG_CDTX_FLAGS)
        return 0;
    size_t body = size - SAL_NRG_CDTX_FLAGS;
    size_t rest = body % SAL_NRG_CDTX_BLOCK;
    return (body / SAL_NRG_CDTX_BLOCK) * SAL_NRG_CDTX_TEXT + (rest < SAL_NRG_CDTX_TEXT ? rest : SAL_NRG_CDTX_TEXT);
}

// copies the text bytes of the CD-Text chunk 'chunk' ('size' bytes) to 'out' in order and returns
// their number (SalNrgCdTextLen(size)); 'out' may be 'chunk' itself (the write position never passes
// the read position); no byte outside chunk[0, size) is read
inline size_t SalNrgCdTextGather(const unsigned char* chunk, size_t size, unsigned char* out)
{
    size_t n = 0;
    for (size_t pos = SAL_NRG_CDTX_FLAGS; pos < size;)
    {
        size_t left = size - pos;
        size_t take = left < SAL_NRG_CDTX_TEXT ? left : SAL_NRG_CDTX_TEXT;
        memmove(out + n, chunk + pos, take);
        n += take;
        if (left <= SAL_NRG_CDTX_BLOCK)
            break;
        pos += SAL_NRG_CDTX_BLOCK;
    }
    return n;
}

// the next 0-terminated string of text[0, len) from 'pos': its start and length (without the
// terminator; a string without one ends at 'len'), 'pos' moved past it; false when the text is
// exhausted (the label is empty)
inline bool SalNrgCdTextNext(const unsigned char* text, size_t len, size_t& pos, size_t& start, size_t& strLen)
{
    if (pos >= len)
        return false;
    const void* z = memchr(text + pos, 0, len - pos);
    size_t end = z != NULL ? (size_t)((const unsigned char*)z - text) : len;
    start = pos;
    strLen = end - pos;
    pos = end < len ? end + 1 : len;
    return true;
}

#define SAL_NRG_CUEX_HEADER 16 // bytes the reader takes as the CUEX chunk's header (2 records)
#define SAL_NRG_CUEX_ENTRY 16  // bytes the reader makes one audio track of (2 records)

// feature 350: the number of whole entries a CUEX chunk of 'size' bytes holds after its header
// (0 for a chunk under 16 + 16 bytes; never more than size / 16)
inline unsigned long long SalNrgCuexEntryCount(unsigned long long size)
{
    if (size < SAL_NRG_CUEX_HEADER)
        return 0;
    return (size - SAL_NRG_CUEX_HEADER) / SAL_NRG_CUEX_ENTRY;
}

#define SAL_NRG_CUEX_RECORD 8 // bytes of a Nero CUEX index record
// the most records a disc's CUEX chunk holds (Red Book: 99 tracks of index 0..99, plus the lead-in
// and the lead-out) - 79,216 bytes, 4,950 of the reader's entries
#define SAL_NRG_CUEX_MAX_RECORDS (2 + 99 * 100)

// feature 350 (reviews 1 and 2): true when a CUEX chunk of 'size' bytes is no larger than any disc's
// can be - a chunk that lies within the image could still claim one track per 16 bytes of it (a
// 96 MiB chunk built 6.3 million tracks, 1.5 GB, 3 minutes); a larger chunk is skipped as damaged.
// (Review 2: a bound of 99 entries refused real discs with index points - 2 tracks of index 1..99
// are 100 entries.)
inline bool SalNrgCuexSizePlausible(unsigned long long size)
{
    return size <= (unsigned long long)SAL_NRG_CUEX_MAX_RECORDS * SAL_NRG_CUEX_RECORD;
}

// true when the DAOX track number 'number' (1-based) names one of the 'trackCount' tracks
inline bool SalNrgDaoTrackInRange(int number, int trackCount)
{
    return number >= 1 && number <= trackCount;
}

// the listed name of audio track 'number' (1-based) with the label 'label' (0-terminated, "" = none):
// "NN label" or "Audio Track NN", whole, in a buffer of malloc() (the caller frees it); NULL when out
// of memory or the name cannot be formatted
inline char* SalNrgAudioTrackNameAlloc(int number, const char* label)
{
    int n = *label != 0 ? snprintf(NULL, 0, "%02d %s", number, label) : snprintf(NULL, 0, "Audio Track %02d", number);
    if (n < 0)
        return NULL;
    char* name = (char*)malloc((size_t)n + 1);
    if (name == NULL)
        return NULL;
    if (*label != 0)
        snprintf(name, (size_t)n + 1, "%02d %s", number, label);
    else
        snprintf(name, (size_t)n + 1, "Audio Track %02d", number);
    return name;
}
