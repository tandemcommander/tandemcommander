// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salsusp.h
//
// Where the Rock Ridge entries of an ISO 9660 directory record start (feature
// 326). Header-only, no globals; for the ISO plug-in (uniso, iso9660.cpp) and
// saltests.
//
// The System Use area of a directory record (the bytes after its file
// identifier and the identifier's padding byte) holds SUSP entries: a 2-byte
// signature, a length that includes the 4-byte header, a version, data. Rock
// Ridge puts the file's real name there (NM).
//
// The ISO plug-in read the NM entries of a record only when its first entry
// was RR. Rock Ridge 1.12 dropped RR; xorriso / libisofs never write it, so
// their images listed the upper-case ISO 9660 names. A volume that uses SUSP
// carries the SP entry at the very start of the System Use area of the root
// directory's first record ('.'): 'S' 'P', length 7, version 1, the check
// bytes BE EF and LEN_SKP - the bytes to skip at the start of every other
// System Use area (continuation areas are not skipped). This is how the Linux
// kernel recognises Rock Ridge too; the ER entry is not required.
//
// So a record is read as Rock Ridge when its first entry is RR (as before,
// on any volume, from byte 0), or when the volume carries SP (from LEN_SKP).
// An area too short for an entry header after that gives no Rock Ridge name.
//
// A Rock Ridge name is a POSIX name: it may hold '\', ':', '*', a trailing
// dot, or be "con.txt". Joined to a target folder as it was, "..\x" was
// written outside the folder and "12:30.txt" into an NTFS stream (review of
// feature 326). SalSuspCleanRockRidgeName makes one name safe the way feature
// 087 cleans archive item names (salarcname.h), for a single component: '\'
// and '/' are not separators here, they become '_' as well.
//
//*****************************************************************************

#include <stddef.h>
#include <string.h>

#include "salarcname.h" // SalArcNameDetail::IsReservedDeviceName (feature 087)

// The System Use area of a directory record: rec = its first byte, avail =
// the bytes readable from rec. False when the record's lengths do not fit
// (length < 34, length > avail, 33 + identifier length > length); else its
// offset in the record and its length (0 when the padding byte ends the record).
inline bool SalSuspSystemUseArea(const unsigned char* rec, size_t avail, size_t* suOffset, size_t* suLength)
{
    if (rec == NULL || avail < 34)
        return false;
    size_t len = rec[0];
    size_t fil = rec[32];
    if (len < 34 || len > avail || 33 + fil > len)
        return false;
    size_t off = 33 + fil + ((fil % 2 == 0) ? 1 : 0); // an even identifier length is followed by a padding byte
    if (off > len)
        off = len;
    *suOffset = off;
    *suLength = len - off;
    return true;
}

// True when su (len bytes) starts with a valid SP entry; *lenSkp = its LEN_SKP.
inline bool SalSuspIsSp(const unsigned char* su, size_t len, unsigned char* lenSkp)
{
    if (su == NULL || len < 7)
        return false;
    if (su[0] != 'S' || su[1] != 'P' || su[2] < 7 || su[2] > len || su[3] != 1 || su[4] != 0xBE || su[5] != 0xEF)
        return false;
    *lenSkp = su[6];
    return true;
}

// The root directory's first record ('.'): true when its System Use area
// starts with SP; *lenSkp = its LEN_SKP.
inline bool SalSuspRootHasSp(const unsigned char* rec, size_t avail, unsigned char* lenSkp)
{
    size_t off, len;
    if (!SalSuspSystemUseArea(rec, avail, &off, &len))
        return false;
    return SalSuspIsSp(rec + off, len, lenSkp);
}

// Where the Rock Ridge entries of a record's System Use area (su, len) start:
// its first entry is RR -> 0 (any volume); else, on a volume with SP, LEN_SKP
// when an entry header fits after it; else false (the plain ISO 9660 name).
inline bool SalSuspRockRidgeStart(const unsigned char* su, size_t len, bool suspVolume, unsigned lenSkp, size_t* start)
{
    if (su == NULL)
        return false;
    if (len >= 4 && su[0] == 'R' && su[1] == 'R')
    {
        *start = 0;
        return true;
    }
    if (suspVolume && lenSkp <= len && len - lenSkp >= 4)
    {
        *start = lenSkp;
        return true;
    }
    return false;
}

// One Rock Ridge name (UTF-8 or raw bytes, terminated, in a buffer of
// 'size' bytes) made safe in place: control characters, '\', '/', ':', '<',
// '>', '"', '|', '?', '*' become '_'; trailing dots and spaces become '_'
// ("." and ".." too); a reserved device name ("con", "com1.txt", ...) gets a
// '_' prefix; an empty name becomes "_". Bytes >= 0x80 are kept, so a
// multi-byte character is never split. False (the name unchanged) only when
// the prefix does not fit the buffer - never a cut name.
inline bool SalSuspCleanRockRidgeName(char* name, size_t size)
{
    // feature 327: the shared rule of salarcname.h (SalArcCleanItemName) - here a device name whose
    // prefix does not fit is refused, the caller then lists the plain ISO 9660 name
    return SalArcNameDetail::CleanOneName(name, size, false);
}
