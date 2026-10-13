// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salexifthumb.h
//
// The thumbnail of an Exif block replaced without touching anything else in
// the block (feature 135). Plain C (EXIF.DLL's exif.c includes it) and C++
// (saltests, saljpegkeep.h); no globals.
//
// PictView's Update Thumbnail used to hand the Exif block to the old libexif:
// parsed into its tags and serialised again. Measured on 91 real camera files:
// for 30 of the 82 with Exif the result differed in more than the thumbnail -
// the maker's block (MakerNote) came back shorter or changed (a Nikon block of
// 28,378 bytes as 1,413), tags of IFD0 were lost, and where the block kept its
// bytes it had moved, which breaks the makers whose block holds offsets counted
// from the start of the Exif data.
//
// An Exif block is a TIFF structure: a header, IFD0 (with pointers to the Exif,
// GPS and Interop IFDs), and IFD1, which describes the thumbnail - a JPEG
// picture at JPEGInterchangeFormat (0x0201) of JPEGInterchangeFormatLength
// (0x0202) bytes. Everything refers to everything else by offsets from the
// header. So the rule of the writer here: NO BYTE MOVES.
//   - Usual case: the old thumbnail is a JPEG picture at the very end of the
//     block. The block is cut there, the new picture is appended, the length in
//     IFD1 is corrected in place.
//   - Otherwise (no IFD1, an uncompressed thumbnail, a thumbnail in the middle):
//     the whole block is kept, a new IFD1 with the new picture is appended and
//     IFD0's link is set to it. The old IFD1's other entries are carried over
//     (their values stay where they are). The old JPEG picture's bytes are
//     overwritten with zeros: people update a thumbnail after cropping or
//     retouching, and the old picture must not stay readable in the file.
// A block is "understood" only when its IFD1 and its thumbnail lie apart from
// everything IFD0 leads to (IFD0 itself, the Exif / GPS / Interop IFDs and all
// their values): files with a wrong length or a link into another structure
// exist, and both the cut and the check would otherwise take real data for
// thumbnail bytes.
// A block that is not understood, or a result over the 64 KB a JPEG segment can
// hold, is refused - the caller leaves the file alone.
//
// SalExifRewriteKeepsData is the other half: the check, independent of whoever
// wrote the new block, that every byte of the original outside its IFD0 link,
// its IFD1 and its old thumbnail is in the new block at the same place.
//
//*****************************************************************************

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define SALEXIF_MAX_TIFF 65527 // a JPEG segment holds 65533 payload bytes; 6 are "Exif\0\0"
#define SALEXIF_MAX_IFD1 60    // entries of an IFD1 this code carries over; more = not understood

typedef struct
{
    int LittleEndian;
    size_t Ifd0;       // offset of IFD0
    size_t Ifd0Link;   // offset of IFD0's 4-byte "next IFD" link
    size_t Ifd1;       // offset of IFD1, 0 = none
    size_t Ifd1Count;  // its number of entries
    size_t ThumbOff;   // the JPEG thumbnail IFD1 describes; 0 / 0 = none
    size_t ThumbLen;
    size_t ThumbLenEntry; // offset of the 12-byte entry 0x0202, 0 = none
    int ThumbLenType;     // its TIFF type (3 SHORT, 4 LONG)
    int Compression;      // IFD1's Compression (0x0103), 0 = absent; 6 = JPEG
} CSalExifLayout;

static unsigned long SalExifGet16(const unsigned char* p, int le)
{
    return le ? (unsigned long)p[0] | ((unsigned long)p[1] << 8) : ((unsigned long)p[0] << 8) | (unsigned long)p[1];
}

static unsigned long SalExifGet32(const unsigned char* p, int le)
{
    return le ? (unsigned long)p[0] | ((unsigned long)p[1] << 8) | ((unsigned long)p[2] << 16) | ((unsigned long)p[3] << 24)
              : ((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) | ((unsigned long)p[2] << 8) | (unsigned long)p[3];
}

static void SalExifPut16(unsigned char* p, int le, unsigned long v)
{
    p[le ? 0 : 1] = (unsigned char)(v & 0xFF);
    p[le ? 1 : 0] = (unsigned char)((v >> 8) & 0xFF);
}

static void SalExifPut32(unsigned char* p, int le, unsigned long v)
{
    if (le)
    {
        p[0] = (unsigned char)(v & 0xFF);
        p[1] = (unsigned char)((v >> 8) & 0xFF);
        p[2] = (unsigned char)((v >> 16) & 0xFF);
        p[3] = (unsigned char)((v >> 24) & 0xFF);
    }
    else
    {
        p[3] = (unsigned char)(v & 0xFF);
        p[2] = (unsigned char)((v >> 8) & 0xFF);
        p[1] = (unsigned char)((v >> 16) & 0xFF);
        p[0] = (unsigned char)((v >> 24) & 0xFF);
    }
}

// the value of a SHORT or LONG entry with count 1 (the 12-byte entry at 'e'); 0 = another shape
static int SalExifEntryNumber(const unsigned char* e, int le, unsigned long* value)
{
    unsigned long type = SalExifGet16(e + 2, le);
    if (SalExifGet32(e + 4, le) != 1)
        return 0;
    if (type == 3)
        *value = SalExifGet16(e + 8, le);
    else if (type == 4)
        *value = SalExifGet32(e + 8, le);
    else
        return 0;
    return 1;
}

static int SalExifRangesMeet(size_t a1, size_t a2, size_t b1, size_t b2)
{
    return a1 < b2 && b1 < a2;
}

// does anything the IFD at 'ifd' leads to - the IFD itself, the values of its entries, the
// Exif / GPS / Interop IFDs under it - share a byte with [from, to)?
static int SalExifIfdMeets(const unsigned char* tiff, size_t size, int le, size_t ifd, int depth, size_t from, size_t to)
{
    static const unsigned char typeSize[14] = {1, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8, 4};
    size_t n, i, end;
    if (ifd < 8 || size < 2 || ifd > size - 2)
        return 0;
    n = SalExifGet16(tiff + ifd, le);
    end = ifd + 2 + 12 * n + 4;
    if (end > size)
        end = size;
    if (SalExifRangesMeet(ifd, end, from, to))
        return 1;
    for (i = 0; i < n && ifd + 2 + 12 * (i + 1) <= size; i++)
    {
        const unsigned char* e = tiff + ifd + 2 + 12 * i;
        unsigned long tag = SalExifGet16(e, le);
        unsigned long type = SalExifGet16(e + 2, le);
        unsigned long count = SalExifGet32(e + 4, le);
        unsigned long value = SalExifGet32(e + 8, le);
        size_t unit = type < 14 ? typeSize[type] : 1;
        if (count > 4 / unit) // the value is not in the entry: it lies at 'value'
        {
            size_t bytes = count > SALEXIF_MAX_TIFF ? SALEXIF_MAX_TIFF : (size_t)count * unit;
            size_t vEnd = value < size ? (bytes < size - value ? value + bytes : size) : 0;
            if (vEnd != 0 && SalExifRangesMeet(value, vEnd, from, to))
                return 1;
        }
        if ((tag == 0x8769 || tag == 0x8825 || tag == 0xA005) && type == 4 && count == 1 && depth < 3 &&
            SalExifIfdMeets(tiff, size, le, value, depth + 1, from, to))
            return 1;
    }
    return 0;
}

// reads where things are in the TIFF data of an Exif block; 0 = not understood
static int SalExifReadLayout(const unsigned char* tiff, size_t size, CSalExifLayout* l)
{
    size_t i, ifd1End;
    unsigned long v;
    int seenCompression = 0, seenOffset = 0, seenLength = 0;
    memset(l, 0, sizeof(*l));
    if (tiff == NULL || size < 14 || size > SALEXIF_MAX_TIFF)
        return 0;
    if (tiff[0] == 'I' && tiff[1] == 'I')
        l->LittleEndian = 1;
    else if (tiff[0] == 'M' && tiff[1] == 'M')
        l->LittleEndian = 0;
    else
        return 0;
    if (SalExifGet16(tiff + 2, l->LittleEndian) != 42)
        return 0;
    l->Ifd0 = SalExifGet32(tiff + 4, l->LittleEndian);
    if (l->Ifd0 < 8 || l->Ifd0 > size - 2) // (not "Ifd0 + 2 > size": that wraps where size_t has 32 bits)
        return 0;
    {
        size_t n = SalExifGet16(tiff + l->Ifd0, l->LittleEndian);
        if (12 * n + 6 > size - l->Ifd0)
            return 0;
        l->Ifd0Link = l->Ifd0 + 2 + 12 * n;
    }
    l->Ifd1 = SalExifGet32(tiff + l->Ifd0Link, l->LittleEndian);
    if (l->Ifd1 == 0)
        return 1;
    if (l->Ifd1 < 8 || l->Ifd1 > size - 2)
        return 0;
    l->Ifd1Count = SalExifGet16(tiff + l->Ifd1, l->LittleEndian);
    if (12 * l->Ifd1Count + 6 > size - l->Ifd1)
        return 0;
    ifd1End = l->Ifd1 + 2 + 12 * l->Ifd1Count + 4;
    // IFD1 must lie apart from everything IFD0 leads to (a link into IFD0 or into the Exif IFD
    // would make this code - and the check - treat real data as "the thumbnail's IFD")
    if (SalExifIfdMeets(tiff, size, l->LittleEndian, l->Ifd0, 0, l->Ifd1, ifd1End))
        return 0;
    for (i = 0; i < l->Ifd1Count; i++)
    {
        const unsigned char* e = tiff + l->Ifd1 + 2 + 12 * i;
        unsigned long tag = SalExifGet16(e, l->LittleEndian);
        // an entry given twice: readers disagree which one counts - not understood
        if ((tag == 0x0103 && seenCompression++) || (tag == 0x0201 && seenOffset++) || (tag == 0x0202 && seenLength++))
            return 0;
        if (tag == 0x0103 && SalExifEntryNumber(e, l->LittleEndian, &v))
            l->Compression = (int)v;
        else if (tag == 0x0201 && SalExifEntryNumber(e, l->LittleEndian, &v))
            l->ThumbOff = v;
        else if (tag == 0x0202 && SalExifEntryNumber(e, l->LittleEndian, &v))
        {
            l->ThumbLen = v;
            l->ThumbLenEntry = (size_t)(e - tiff);
            l->ThumbLenType = (int)SalExifGet16(e + 2, l->LittleEndian);
        }
    }
    if (l->ThumbOff == 0 || l->ThumbLen == 0 || l->ThumbOff < 8 || l->ThumbOff > size || l->ThumbLen > size - l->ThumbOff ||
        // the declared picture shares bytes with IFD1 or with something IFD0 leads to (a wrong
        // length that runs over the Exif IFD, a range laid over the maker's block)
        SalExifRangesMeet(l->ThumbOff, l->ThumbOff + l->ThumbLen, l->Ifd1, ifd1End) ||
        SalExifIfdMeets(tiff, size, l->LittleEndian, l->Ifd0, 0, l->ThumbOff, l->ThumbOff + l->ThumbLen))
    {
        // no usable JPEG thumbnail: treated as none - its bytes are neither cut nor allowed to change
        l->ThumbOff = 0;
        l->ThumbLen = 0;
        l->ThumbLenEntry = 0;
    }
    return 1;
}

// tags of an old IFD1 that describe its old picture and are not carried into a new IFD1
static int SalExifIsThumbnailTag(unsigned long tag)
{
    static const unsigned short tags[] = {0x0100, 0x0101, 0x0102, 0x0103, 0x0106, 0x0111, 0x0115, 0x0116,
                                          0x0117, 0x011C, 0x0200, 0x0201, 0x0202, 0x0211, 0x0212, 0x0213};
    size_t i;
    for (i = 0; i < sizeof(tags) / sizeof(tags[0]); i++)
        if (tags[i] == tag)
            return 1;
    return 0;
}

// The TIFF data 'tiff' of an Exif block with the JPEG picture 'thumb' as its thumbnail, in a
// malloc'd buffer '*out' of '*outSize' bytes. Returns 1; 0 = refused (the block is not understood,
// the result does not fit a JPEG segment, low memory) - '*out' is NULL then.
static int SalExifReplaceThumbnail(const unsigned char* tiff, size_t size, const unsigned char* thumb, size_t thumbSize,
                                   unsigned char** out, size_t* outSize)
{
    CSalExifLayout l;
    unsigned char* buf;
    *out = NULL;
    *outSize = 0;
    if (thumb == NULL || thumbSize == 0 || thumbSize > SALEXIF_MAX_TIFF || !SalExifReadLayout(tiff, size, &l))
        return 0;

    if (l.Ifd1 != 0 && (l.Compression == 6 || l.Compression == 0) && l.ThumbLen >= 2 && l.ThumbOff + l.ThumbLen == size &&
        tiff[l.ThumbOff] == 0xFF && tiff[l.ThumbOff + 1] == 0xD8 && // a JPEG picture is there
        (l.ThumbLenType == 4 || thumbSize <= 0xFFFF) &&
        // the picture is behind both IFDs, so cutting the block there cuts no structure
        l.ThumbOff >= l.Ifd0Link + 4 && l.ThumbOff >= l.Ifd1 + 2 + 12 * l.Ifd1Count + 4)
    {
        // the usual case: the old picture is the end of the block
        size_t newSize = l.ThumbOff + thumbSize;
        if (newSize > SALEXIF_MAX_TIFF)
            return 0;
        buf = (unsigned char*)malloc(newSize);
        if (buf == NULL)
            return 0;
        memcpy(buf, tiff, l.ThumbOff);
        memcpy(buf + l.ThumbOff, thumb, thumbSize);
        if (l.ThumbLenType == 4)
            SalExifPut32(buf + l.ThumbLenEntry + 8, l.LittleEndian, (unsigned long)thumbSize);
        else
            SalExifPut16(buf + l.ThumbLenEntry + 8, l.LittleEndian, (unsigned long)thumbSize);
        *out = buf;
        *outSize = newSize;
        return 1;
    }
    else
    {
        // a new IFD1 behind everything; the old one (if any) stays as unused bytes
        unsigned char entries[(SALEXIF_MAX_IFD1 + 3) * 12];
        size_t count = 0, i, j, at, picture, newSize;
        if (l.Ifd1Count > SALEXIF_MAX_IFD1)
            return 0;
        for (i = 0; i < l.Ifd1Count; i++)
        {
            const unsigned char* e = tiff + l.Ifd1 + 2 + 12 * i;
            if (!SalExifIsThumbnailTag(SalExifGet16(e, l.LittleEndian)))
                memcpy(entries + 12 * count++, e, 12);
        }
        at = size + (size & 1); // IFDs start at an even offset
        picture = at + 2 + 12 * (count + 3) + 4;
        newSize = picture + thumbSize;
        if (newSize > SALEXIF_MAX_TIFF)
            return 0;
        {
            static const unsigned short newTags[3] = {0x0103, 0x0201, 0x0202};
            unsigned long newValues[3];
            newValues[0] = 6;
            newValues[1] = (unsigned long)picture;
            newValues[2] = (unsigned long)thumbSize;
            for (i = 0; i < 3; i++)
            {
                unsigned char* e = entries + 12 * count++;
                memset(e, 0, 12);
                SalExifPut16(e, l.LittleEndian, newTags[i]);
                SalExifPut16(e + 2, l.LittleEndian, i == 0 ? 3 : 4); // SHORT, LONG, LONG
                SalExifPut32(e + 4, l.LittleEndian, 1);
                if (i == 0)
                    SalExifPut16(e + 8, l.LittleEndian, newValues[i]);
                else
                    SalExifPut32(e + 8, l.LittleEndian, newValues[i]);
            }
        }
        // entries in the order of their tags (an insertion sort of at most 63 entries)
        for (i = 1; i < count; i++)
        {
            unsigned char e[12];
            memcpy(e, entries + 12 * i, 12);
            j = i;
            while (j > 0 && SalExifGet16(entries + 12 * (j - 1), l.LittleEndian) > SalExifGet16(e, l.LittleEndian))
            {
                memcpy(entries + 12 * j, entries + 12 * (j - 1), 12);
                j--;
            }
            memcpy(entries + 12 * j, e, 12);
        }
        buf = (unsigned char*)malloc(newSize);
        if (buf == NULL)
            return 0;
        memcpy(buf, tiff, size);
        if (at != size)
            buf[size] = 0;
        // the old JPEG picture is not left readable in the file (it is unreferenced from now on;
        // its range is known to lie apart from every other structure)
        if (l.ThumbLen >= 2 && tiff[l.ThumbOff] == 0xFF && tiff[l.ThumbOff + 1] == 0xD8)
            memset(buf + l.ThumbOff, 0, l.ThumbLen);
        SalExifPut16(buf + at, l.LittleEndian, (unsigned long)count);
        memcpy(buf + at + 2, entries, 12 * count);
        SalExifPut32(buf + at + 2 + 12 * count, l.LittleEndian, 0); // no further IFD
        memcpy(buf + picture, thumb, thumbSize);
        SalExifPut32(buf + l.Ifd0Link, l.LittleEndian, (unsigned long)at);
        *out = buf;
        *outSize = newSize;
        return 1;
    }
}

// Is 'fresh' the Exif TIFF data 'orig' with nothing changed but the thumbnail? Every byte of
// 'orig' outside its IFD0 link, its IFD1 (count, entries, link) and its old thumbnail picture
// must be in 'fresh' at the same offset, and 'fresh' must be a block this code understands that
// has a JPEG thumbnail. Returns 1 / 0; a block that is not understood is never "kept".
static int SalExifRewriteKeepsData(const unsigned char* orig, size_t origSize, const unsigned char* fresh, size_t freshSize)
{
    CSalExifLayout lo, lf;
    size_t i, ifd1End;
    if (!SalExifReadLayout(orig, origSize, &lo) || !SalExifReadLayout(fresh, freshSize, &lf))
        return 0;
    if (lo.LittleEndian != lf.LittleEndian || lf.Ifd1 == 0 || lf.ThumbLen == 0)
        return 0;
    ifd1End = lo.Ifd1 != 0 ? lo.Ifd1 + 2 + 12 * lo.Ifd1Count + 4 : 0;
    for (i = 0; i < origSize; i++)
    {
        if (i >= lo.Ifd0Link && i < lo.Ifd0Link + 4)
            continue;
        if (lo.Ifd1 != 0 && i >= lo.Ifd1 && i < ifd1End)
            continue;
        if (lo.ThumbLen != 0 && i >= lo.ThumbOff && i < lo.ThumbOff + lo.ThumbLen)
            continue;
        if (i >= freshSize || orig[i] != fresh[i])
            return 0;
    }
    return 1;
}
