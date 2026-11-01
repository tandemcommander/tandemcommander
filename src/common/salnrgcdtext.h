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
//     (SalNrgCuexSizePlausible: 2 + 99 x 100 records), and only while the
//     image's CUEX chunks together stay within what a disc can give
//     (SalNrgCuexTotalPlausible, review 3: many chunks of the largest size).
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

// the most tracks the reader can make from all CUEX chunks of a real image: one chunk a session,
// together at most 99 tracks of index 0..99 plus a lead-in and a lead-out a session - (2 x sessions
// + 9,900) records, of which the reader takes (records / 2 - 1) a chunk: 4,950 in all; one more a
// session (99) as a margin
#define SAL_NRG_CUEX_MAX_IMAGE_ENTRIES (4950 + 99)

// feature 350 (review 3): true when a CUEX chunk of 'entries' entries may add its tracks to the
// 'tracks' the image already has - every chunk within SalNrgCuexSizePlausible, but 1,270 chunks of
// the largest size (96 MiB) still built a track per 16 bytes of them (1563 MB, 178 s); a chunk past
// the bound is skipped as damaged
inline bool SalNrgCuexTotalPlausible(unsigned long long tracks, unsigned long long entries)
{
    return tracks <= SAL_NRG_CUEX_MAX_IMAGE_ENTRIES && entries <= SAL_NRG_CUEX_MAX_IMAGE_ENTRIES - tracks;
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

// Feature 365: the track-at-once tables of an NRG image - ETNF (Nero v1, 20 bytes a track: start and
// length in bytes as 32 bits at 0 / 4, the mode byte at 11, the track's first disc sector at 12) and
// ETN2 (the 64-bit form, 32 bytes a track: start / length at 0 / 8, mode at 19, first sector at 20); all
// big-endian (libmirage's NRG_ETN_Block). The reader took the stored sector size of an ETNF track from
// bit 0 of the mode byte (raw Mode 1 = 0x05 became 2336 bytes, raw Mode 2 = 0x06 2048) and read only the
// first ETN2 entry of a chunk, with Mode 1 / 2048, first sector 0 and an end equal to its length.
#define SAL_NRG_ETNF_ENTRY 20      // bytes of an ETNF entry
#define SAL_NRG_ETN2_ENTRY 32      // bytes of an ETN2 entry
#define SAL_NRG_ETN_MAX_ENTRIES 99 // a disc holds at most 99 tracks

// true for a Nero mode byte whose stored sector size is known (libmirage's
// mirage_parser_nrg_decode_mode): 0x00 Mode 1 / 2048, 0x02 Mode 2 Form 1 / 2048, 0x03 Mode 2 / 2336,
// 0x05 Mode 1 / 2352, 0x06 Mode 2 / 2352, 0x07 audio / 2352. The subchannel modes 0x0F / 0x10 / 0x11 are
// not: how their track-at-once data stores the 96 subchannel bytes is not known
inline bool SalNrgModeVerified(unsigned char mode)
{
    return mode == 0x00 || mode == 0x02 || mode == 0x03 || mode == 0x05 || mode == 0x06 || mode == 0x07;
}

// the stored bytes a sector of an ETNF ('v2' false) or ETN2 ('v2' true) track of Nero mode 'mode'; a mode
// SalNrgModeVerified does not know keeps the size the reader gave it before (ETNF: 2336 when bit 0 is
// set, else 2048; ETN2: 2048)
inline unsigned int SalNrgEtnSectorSize(unsigned char mode, bool v2)
{
    switch (mode)
    {
    case 0x00:
    case 0x02:
        return 2048;
    case 0x03:
        return 2336;
    case 0x05:
    case 0x06:
    case 0x07:
        return 2352;
    }
    if (v2)
        return 2048;
    return (mode & 1) != 0 ? 2336 : 2048;
}

struct SalNrgEtnEntry
{
    unsigned long long Start;  // byte of the image the track's data starts at
    unsigned long long Length; // bytes of the track's data
    unsigned char Mode;        // Nero's mode byte
    unsigned long Sector;      // the track's first disc sector
};

// the big-endian unsigned number of 'bytes' bytes at 'p'
inline unsigned long long SalNrgBigEndian(const unsigned char* p, int bytes)
{
    unsigned long long v = 0;
    int i;
    for (i = 0; i < bytes; i++)
        v = (v << 8) | p[i];
    return v;
}

// decodes the ETNF ('v2' false, SAL_NRG_ETNF_ENTRY bytes at 'p') or ETN2 ('v2' true, SAL_NRG_ETN2_ENTRY
// bytes) entry at 'p'
inline void SalNrgEtnDecode(const unsigned char* p, bool v2, SalNrgEtnEntry& e)
{
    if (v2)
    {
        e.Start = SalNrgBigEndian(p, 8);
        e.Length = SalNrgBigEndian(p + 8, 8);
        e.Mode = p[19];
        e.Sector = (unsigned long)SalNrgBigEndian(p + 20, 4);
    }
    else
    {
        e.Start = SalNrgBigEndian(p, 4);
        e.Length = SalNrgBigEndian(p + 4, 4);
        e.Mode = p[11];
        e.Sector = (unsigned long)SalNrgBigEndian(p + 12, 4);
    }
}

// the byte after a track that starts at 'start' and holds 'length' bytes - start + length, at most the
// largest signed 64-bit value (the track record keeps signed positions)
inline unsigned long long SalNrgEtnEnd(unsigned long long start, unsigned long long length)
{
    const unsigned long long top = 0x7FFFFFFFFFFFFFFFull;
    if (start >= top || length > top - start)
        return top;
    return start + length;
}

// the whole entries an ETNF / ETN2 chunk of 'size' bytes holds (the bytes after the last are not read)
inline unsigned long long SalNrgEtnEntryCount(unsigned long long size, bool v2)
{
    return size / (v2 ? SAL_NRG_ETN2_ENTRY : SAL_NRG_ETNF_ENTRY);
}

// true when an ETN2 chunk of 'size' bytes holds no more tracks than a disc can (99) - the reader made one
// track a chunk before feature 365; a larger chunk is skipped as damaged rather than make one track per
// 32 bytes of it (as features 331 / 350 skip CDTX / CUEX chunks)
inline bool SalNrgEtn2ChunkPlausible(unsigned long long size)
{
    return SalNrgEtnEntryCount(size, true) <= SAL_NRG_ETN_MAX_ENTRIES;
}
