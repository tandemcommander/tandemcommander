// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salzipmember.h
//
// A ZIP member put back where it was meant to be replaced (feature 113).
// Header-only, no globals - the ZIP plug-in cannot compile a shared .cpp file
// (its sources find precomp.h beside themselves), and saltests checks it.
//
// When files are added into an existing archive, the ZIP plug-in leaves the
// members they replace out of the new archive before it reads the new files.
// When a new file then cannot be read and the answer is Skip, the member it
// was to replace is copied back from the original archive (which is untouched
// until the end of the operation) to the current end of the new archive's data:
// its local header, data and data descriptor byte for byte (SalZipMemberSpan
// says how many bytes that is - the same count the plug-in's DeleteFiles leaves
// out), and its central directory record byte for byte except the offset of the
// local header (SalZipRelocateCentralRecord).
//
// Layout of a central directory record (APPNOTE 4.3.12), little endian:
//   0 signature 0x02014b50   4 version made by      6 version needed
//   8 flag                  10 method               12 time, 14 date
//  16 crc                   20 compressed size      24 uncompressed size
//  28 name length           30 extra length         32 comment length
//  34 disk number start     36 internal attributes  38 external attributes
//  42 local header offset   46 name, extra field, comment
// A field that does not fit holds 0xFFFFFFFF (disk: 0xFFFF) and its value is in
// the zip64 extra block (id 0x0001), in the order uncompressed size, compressed
// size, local header offset, disk number - only the fields that are marked.
//
//*****************************************************************************

#include <stddef.h>
#include <string.h>

#define SALZIP_CENTRAL_FIXED 46         // fixed part of a central directory record
#define SALZIP_LOCAL_FIXED 30           // fixed part of a local file header
#define SALZIP_RELOCATE_GROWTH 12       // a relocated record is at most this many bytes longer
#define SALZIP_GPF_DATADESCR 0x0008     // general purpose flag: a data descriptor follows the data

namespace salzipmember_detail
{
inline unsigned Get16(const unsigned char* p) { return (unsigned)p[0] | ((unsigned)p[1] << 8); }
inline unsigned long Get32(const unsigned char* p)
{
    return (unsigned long)p[0] | ((unsigned long)p[1] << 8) | ((unsigned long)p[2] << 16) | ((unsigned long)p[3] << 24);
}
inline void Put16(unsigned char* p, unsigned v)
{
    p[0] = (unsigned char)(v & 0xFF);
    p[1] = (unsigned char)((v >> 8) & 0xFF);
}
inline void Put32(unsigned char* p, unsigned long v)
{
    for (int i = 0; i < 4; i++)
        p[i] = (unsigned char)((v >> (8 * i)) & 0xFF);
}
inline void Put64(unsigned char* p, unsigned long long v)
{
    for (int i = 0; i < 8; i++)
        p[i] = (unsigned char)((v >> (8 * i)) & 0xFF);
}
// the first zip64 block (id 1) of a complete central record: its position within the extra field
// and its data length; *wellFormed says whether the extra field is a clean list of blocks
inline bool FindZip64(const unsigned char* rec, size_t* z64, size_t* z64Len, bool* wellFormed)
{
    const size_t nameLen = Get16(rec + 28);
    const size_t extraLen = Get16(rec + 30);
    const unsigned char* extra = rec + 46 + nameLen;
    bool found = false;
    *wellFormed = true;
    size_t i = 0;
    while (i < extraLen)
    {
        if (extraLen - i < 4)
        {
            *wellFormed = false;
            break;
        }
        size_t id = Get16(extra + i);
        size_t len = Get16(extra + i + 2);
        if (len > extraLen - i - 4)
        {
            *wellFormed = false;
            break;
        }
        if (id == 1 && !found)
        {
            found = true;
            *z64 = i;
            *z64Len = len;
        }
        i += 4 + len;
    }
    return found;
}
} // namespace salzipmember_detail

// Bytes a member occupies in the archive from its local header on: the local
// header (SALZIP_LOCAL_FIXED + its own name and extra lengths), the compressed
// data, and the data descriptor when the flag says there is one (24 bytes with
// 64-bit sizes - when a size or the offset needs them - else 16, signature
// included). The same count the ZIP plug-in's DeleteFiles leaves out.
inline unsigned long long SalZipMemberSpan(unsigned localNameLen, unsigned localExtraLen,
                                           unsigned long long compSize, unsigned flag,
                                           unsigned long long size, unsigned long long locHeaderOffs)
{
    unsigned long long desc = 0;
    if (flag & SALZIP_GPF_DATADESCR)
    {
        if (size >= 0xFFFFFFFFULL || compSize >= 0xFFFFFFFFULL || locHeaderOffs >= 0xFFFFFFFFULL)
            desc = 24;
        else
            desc = 16;
    }
    return SALZIP_LOCAL_FIXED + (unsigned long long)localNameLen + localExtraLen + compSize + desc;
}

// The length of the central directory record that starts at 'rec' (at most
// 'avail' bytes readable), 0 when it is not a complete record.
inline size_t SalZipCentralRecordLen(const unsigned char* rec, size_t avail)
{
    using namespace salzipmember_detail;
    if (rec == NULL || avail < SALZIP_CENTRAL_FIXED || Get32(rec) != 0x02014B50UL)
        return 0;
    size_t len = SALZIP_CENTRAL_FIXED + (size_t)Get16(rec + 28) + Get16(rec + 30) + Get16(rec + 32);
    return len <= avail ? len : 0;
}

// Where the local header offset of the central directory record 'rec' ('recLen'
// bytes) is stored: 42 - the 32-bit field - when that field is not the zip64
// marker, else the position (from the record's start) of the 8-byte value in
// the zip64 block, FOUND BY ITS ID (any place in the extra field, after the
// marked sizes); 0 when the record is not complete or the field is marked and
// no zip64 block holds the value. (Before 113 the ZIP plug-in's UpdateCentrDir
// assumed the zip64 block was the first one.)
inline size_t SalZipCentralRecordOffsetPos(const unsigned char* rec, size_t recLen)
{
    using namespace salzipmember_detail;
    if (rec == NULL || recLen < SALZIP_CENTRAL_FIXED || SalZipCentralRecordLen(rec, recLen) != recLen)
        return 0;
    if (Get32(rec + 42) != 0xFFFFFFFFUL)
        return 42;
    const size_t offsPos = 8 * ((Get32(rec + 24) == 0xFFFFFFFFUL ? 1 : 0) + (Get32(rec + 20) == 0xFFFFFFFFUL ? 1 : 0));
    size_t z64 = 0, z64Len = 0;
    bool wellFormed;
    if (!FindZip64(rec, &z64, &z64Len, &wellFormed) || z64Len < offsPos + 8)
        return 0;
    return SALZIP_CENTRAL_FIXED + Get16(rec + 28) + z64 + 4 + offsPos;
}

// The local header offset of the central directory record 'rec' ('recLen'
// bytes) into *offs; false when it cannot be read (an incomplete record, a
// zip64 marker without a value).
inline bool SalZipCentralRecordOffset(const unsigned char* rec, size_t recLen, unsigned long long* offs)
{
    using namespace salzipmember_detail;
    size_t pos = SalZipCentralRecordOffsetPos(rec, recLen);
    if (pos == 0)
        return false;
    if (pos == 42)
        *offs = Get32(rec + 42);
    else
        *offs = (unsigned long long)Get32(rec + pos) | ((unsigned long long)Get32(rec + pos + 4) << 32);
    return true;
}

// Where the next member ON DISK after the one at 'after' begins: *next = the
// smallest local header offset above 'after' among the records of the central
// directory 'dir' ('dirLen' bytes), or 'limit' (where the members' data ends -
// the central directory) when none is lower. FAILS CLOSED: false ("unknown")
// when a record is incomplete (the directory does not end with a whole record)
// or its offset cannot be read - such a record could be the nearer member, and
// skipping it could only make the bound larger. (Review of 113, R1: the ZIP
// plug-in's DeleteFiles checked a member's computed end only against the next
// DELETED member - with a 12-byte data descriptor the next untouched member was
// moved without its first 4 bytes.)
inline bool SalZipNextMemberOffset(const unsigned char* dir, size_t dirLen, unsigned long long after,
                                   unsigned long long limit, unsigned long long* next)
{
    *next = limit;
    if (dir == NULL && dirLen != 0)
        return false;
    size_t p = 0;
    while (p < dirLen)
    {
        size_t len = SalZipCentralRecordLen(dir + p, dirLen - p);
        unsigned long long offs;
        if (len == 0 || !SalZipCentralRecordOffset(dir + p, len, &offs))
            return false;
        if (offs > after && offs < *next)
            *next = offs;
        p += len;
    }
    return true;
}

// Writes to 'dst' (capacity 'dstCap'; SALZIP_RELOCATE_GROWTH more than 'recLen'
// is always enough) the central directory record 'rec' ('recLen' bytes) with
// the local header offset 'newOffs'. Everything else is kept byte for byte:
// name, comment, every extra block (AES 0x9901, time stamps, Unicode path ...),
// attributes, the host system. Returns the length written, 0 when 'rec' is not
// a complete record, its marked offset has no room in a zip64 block, the extra
// field would outgrow 65,535 bytes, or 'dst' is too small - the caller must then
// not put the member back.
//   - the offset is in the zip64 block (field 0xFFFFFFFF): the value there is
//     replaced (it stays in the block also when it would fit 32 bits - allowed)
//   - else, the new offset fits 32 bits: the field is replaced
//   - else the field becomes 0xFFFFFFFF and the offset goes into the zip64
//     block at its place (after the sizes that are there, before a disk
//     number), or a new block {0x0001, 8, offset} is put at the START of the
//     extra field (where the ZIP plug-in writes its own); "version needed to
//     extract" is raised to 4.5 (zip64) when lower.
//     This case needs a well-formed extra field (blocks that end exactly at
//     its end) - one that is not is not rewritten.
inline size_t SalZipRelocateCentralRecord(const unsigned char* rec, size_t recLen, unsigned long long newOffs,
                                          unsigned char* dst, size_t dstCap)
{
    using namespace salzipmember_detail;
    if (dst == NULL || rec == NULL || recLen < SALZIP_CENTRAL_FIXED || SalZipCentralRecordLen(rec, recLen) != recLen)
        return 0;
    const size_t nameLen = Get16(rec + 28);
    const size_t extraLen = Get16(rec + 30);
    const bool sizeIn64 = Get32(rec + 24) == 0xFFFFFFFFUL;
    const bool compIn64 = Get32(rec + 20) == 0xFFFFFFFFUL;
    const bool offsIn64 = Get32(rec + 42) == 0xFFFFFFFFUL;
    const bool diskIn64 = Get16(rec + 34) == 0xFFFF;
    const size_t offsPos = 8 * ((sizeIn64 ? 1 : 0) + (compIn64 ? 1 : 0)); // offset's place in the zip64 data

    // the zip64 block (the first one with id 1) and whether the extra field is a clean list of blocks
    size_t z64 = 0;    // position of the block's header within the extra field
    size_t z64Len = 0; // length of its data
    bool wellFormed = true;
    const bool hasZ64 = salzipmember_detail::FindZip64(rec, &z64, &z64Len, &wellFormed);

    if (offsIn64)
    {
        if (!hasZ64 || z64Len < offsPos + 8 || dstCap < recLen)
            return 0;
        memcpy(dst, rec, recLen);
        Put64(dst + SALZIP_CENTRAL_FIXED + nameLen + z64 + 4 + offsPos, newOffs);
        return recLen;
    }
    if (newOffs < 0xFFFFFFFFULL)
    {
        if (dstCap < recLen)
            return 0;
        memcpy(dst, rec, recLen);
        Put32(dst + 42, (unsigned long)newOffs);
        return recLen;
    }

    // the offset needs 64 bits and the record has no place for it yet
    if (!wellFormed)
        return 0;
    size_t insertAt; // position within the extra field where 8 (or 12) new bytes go
    size_t added;
    if (hasZ64)
    {
        // the block holds the marked sizes first; a marked disk number follows the offset
        if (z64Len < offsPos + (diskIn64 ? 4 : 0) || z64Len + 8 > 0xFFFF)
            return 0;
        insertAt = z64 + 4 + offsPos;
        added = 8;
    }
    else
    {
        // a new block goes FIRST: the ZIP plug-in writes its zip64 block first (WriteCentralHeader),
        // and readers written for that layout (its UpdateCentrDir before 113) look there only
        insertAt = 0;
        added = 12;
    }
    if (extraLen + added > 0xFFFF || dstCap < recLen + added)
        return 0;
    const size_t head = SALZIP_CENTRAL_FIXED + nameLen + insertAt; // bytes before the insertion point
    memcpy(dst, rec, head);
    unsigned char* p = dst + head;
    if (added == 12)
    {
        Put16(p, 1);
        Put16(p + 2, 8);
        p += 4;
    }
    Put64(p, newOffs);
    memcpy(p + 8, rec + head, recLen - head);
    if (added == 8)
        Put16(dst + SALZIP_CENTRAL_FIXED + nameLen + z64 + 2, (unsigned)(z64Len + 8));
    Put16(dst + 30, (unsigned)(extraLen + added));
    Put32(dst + 42, 0xFFFFFFFFUL);
    if ((Get16(dst + 6) & 0xFF) < 45)
        Put16(dst + 6, (Get16(dst + 6) & 0xFF00) | 45);
    return recLen + added;
}
