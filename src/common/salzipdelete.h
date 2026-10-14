// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salzipdelete.h
//
// Feature 164: deleting many members from a large ZIP archive in time n log n
// instead of n x d. Header-only, no globals (the ZIP plug-in cannot compile a
// shared .cpp file), checked by saltests against the per-member algorithm it
// replaces.
//
// The ZIP plug-in's DeleteFiles (del.cpp) moves the data of the kept members
// down over the deleted ones, in the order of their local headers on disk.
// For every deleted member it walked the whole central directory twice: once
// for the bound of feature 113 (SalZipNextMemberOffset - where the next member
// on disk begins) and once to update it (UpdateCentrDir - the deleted record
// removed with a memmove of the rest, the offsets of the records between this
// member and the next deleted one lowered by the bytes removed so far). With
// 30,000 members and 15,000 of them deleted that took 22 s (Debug).
//
// Here the same results come from one sorted array of the offsets, built once
// (SalZipBuildOffsetIndex + SalZipNextFromIndex), and from one pass over the
// directory after the loop (SalZipApplyDeletions) with the members processed
// so far. They are equal when the deleted members' offsets strictly ascend
// (the caller sorts them; duplicates take the old path):
//   - the bound: the per-member walk saw the directory after the earlier
//     steps, but those only removed records below the current member and
//     lowered offsets that stayed below it - the smallest offset above the
//     member is the one of the original directory;
//   - the update: a record whose original offset lies between processed
//     member k and the next deleted member is lowered exactly once, by
//     delta[k], at step k (afterwards it lies below every later member); a
//     record whose offset equals a processed member's is removed; the rest
//     is kept byte for byte.
//
//*****************************************************************************

#include <stdlib.h>
#include <string.h>
#include <algorithm>

#include "salzipmember.h"

// The sorted local header offsets of every record of the central directory
// 'dir' ('dirLen' bytes): 1 and *offs (malloc'ed, the caller frees it) with
// *count entries; 0 when a record is incomplete or its offset cannot be read
// (SalZipNextMemberOffset would fail - the caller keeps the old path, which
// refuses); -1 when memory is low (the caller keeps the old path).
inline int SalZipBuildOffsetIndex(const unsigned char* dir, size_t dirLen, unsigned long long** offs, size_t* count)
{
    *offs = NULL;
    *count = 0;
    if (dir == NULL && dirLen != 0)
        return 0;
    size_t n = 0;
    for (size_t p = 0; p < dirLen;)
    {
        size_t len = SalZipCentralRecordLen(dir + p, dirLen - p);
        unsigned long long o;
        if (len == 0 || !SalZipCentralRecordOffset(dir + p, len, &o))
            return 0;
        n++;
        p += len;
    }
    unsigned long long* a = (unsigned long long*)malloc((n ? n : 1) * sizeof(unsigned long long));
    if (a == NULL)
        return -1;
    size_t i = 0;
    for (size_t p = 0; p < dirLen; i++)
    {
        size_t len = SalZipCentralRecordLen(dir + p, dirLen - p);
        SalZipCentralRecordOffset(dir + p, len, &a[i]);
        p += len;
    }
    std::sort(a, a + n);
    *offs = a;
    *count = n;
    return 1;
}

// SalZipNextMemberOffset on the index: the smallest offset above 'after', or
// 'limit' when none is lower
inline unsigned long long SalZipNextFromIndex(const unsigned long long* offs, size_t count, unsigned long long after,
                                              unsigned long long limit)
{
    const unsigned long long* p = std::upper_bound(offs, offs + count, after);
    return (p != offs + count && *p < limit) ? *p : limit;
}

// Applies the deletions of 'm' processed members to the central directory 'dir'
// ('dirLen' bytes; every record complete - SalZipBuildOffsetIndex returned 1):
// cur[k] the member's original local header offset (strictly ascending), nxt[k]
// the next deleted member's offset (~0ULL for the last one), delta[k] the bytes
// removed below the data that followed it. Records are read as the plug-in's
// UpdateCentrDir read them: the 32-bit field, or the zip64 value found by its id
// when the field holds the marker (a marker without a value is never lowered).
// Returns the new length; *removed = the records removed.
inline size_t SalZipApplyDeletions(unsigned char* dir, size_t dirLen, const unsigned long long* cur,
                                   const unsigned long long* nxt, const unsigned long long* delta, size_t m,
                                   size_t* removed)
{
    using namespace salzipmember_detail;
    *removed = 0;
    if (dir == NULL || m == 0)
        return dirLen;
    size_t r = 0; // read position
    size_t w = 0; // write position (records kept, moved down over the removed ones)
    while (r < dirLen)
    {
        unsigned char* rec = dir + r;
        size_t recLen = SALZIP_CENTRAL_FIXED + (size_t)Get16(rec + 28) + Get16(rec + 30) + Get16(rec + 32);
        unsigned long long v = Get32(rec + 42);
        size_t pos = 42;
        bool noOffset = false;
        if (v == 0xFFFFFFFFULL)
        {
            size_t avail = dirLen - r;
            size_t p = SalZipCentralRecordOffsetPos(rec, recLen <= avail ? recLen : avail);
            if (p != 0 && p != 42)
            {
                pos = p;
                v = (unsigned long long)Get32(rec + p) | ((unsigned long long)Get32(rec + p + 4) << 32);
            }
            else
                noOffset = true;
        }
        // the last processed member at or below v
        const unsigned long long* k = std::upper_bound(cur, cur + m, v);
        if (k != cur)
        {
            size_t i = (size_t)(k - cur) - 1;
            if (cur[i] == v)
            {
                (*removed)++;
                r += recLen;
                continue;
            }
            if (!noOffset && v > cur[i] && (nxt[i] == ~0ULL || v < nxt[i])) // ~0: no next (as !nextFile)
            {
                v -= delta[i];
                if (pos == 42)
                    Put32(rec + 42, (unsigned long)v); // was 32-bit, still is (as UpdateCentrDir wrote it)
                else
                    Put64(rec + pos, v);
            }
        }
        if (w != r)
            memmove(dir + w, rec, recLen);
        w += recLen;
        r += recLen;
    }
    return w;
}
