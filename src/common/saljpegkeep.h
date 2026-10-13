// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saljpegkeep.h
//
// Is a rewritten JPEG file still the user's file? (feature 132)
// Header-only, no globals; saltests checks it.
//
// PictView's Update Thumbnail hands a JPEG file to EXIF.DLL, which reads it into
// sections, puts a new thumbnail in (the Exif APP1 block, or a JFXX APP0 block when
// the file has no Exif) and writes a new file; that file then replaces the
// original. The library reported success also when it had understood only the
// beginning of the file, when a block no longer fitted the 16-bit length of a
// segment, and it turned every APP1 block that is not Exif (XMP) into an empty
// Exif block. Nothing looked at what was written.
//
// The rule here is independent of that library: the new file may differ from the
// original ONLY in its thumbnail carriers. Precisely, with the segments before the
// first start of scan (SOS) read from both files:
//   - the segments that are not an Exif APP1 ("Exif\0\0") or a JFXX APP0
//     ("JFXX\0") are the same in both files - count, order, marker and every byte;
//   - everything from the SOS marker to the end of the file (the picture data, the
//     end marker and whatever follows it - motion photos, depth maps) is the same
//     byte for byte;
//   - a file that had an Exif block still has one;
//   - the command changes ONE thing: either one Exif block (its thumbnail), or the JFXX
//     blocks (a file without Exif) - never both, never two Exif blocks. (The library used to
//     serialise every Exif block again, dropping tags it does not know, also when it only
//     added a JFXX block.)
// Fill bytes (0xFF) before a marker are allowed and are not part of the
// comparison. A file this walker does not understand - no SOI, a marker without a
// length before the SOS, a length that leaves the file, no SOS - is NOT the same:
// the caller keeps the original (the check fails closed).
//
//*****************************************************************************

#include <stddef.h>
#include <string.h>

enum CSalJpegKeepResult
{
    sjkSame,                  // the new file may replace the original
    sjkOriginalNotUnderstood, // the original is not a JPEG file this walker can read
    sjkNewNotUnderstood,      // the new file is not
    sjkSegmentsDiffer,        // a segment other than the thumbnail carriers was lost, added or changed
    sjkImageDiffers,          // the data from the SOS marker to the end of the file differ
    sjkExifGone,              // the original had an Exif block and the new file has none (or fewer)
    sjkCarriersDiffer,        // more than one thumbnail carrier changed (two Exif blocks; Exif and JFXX)
};

struct CSalJpegSegment
{
    unsigned char Marker;
    size_t Payload;     // offset of the first byte behind the two length bytes
    size_t PayloadSize; // without the two length bytes
};

#define SALJPEG_MAX_CARRIERS 4 // Exif / JFXX blocks of one file the rule can tell apart; more = not understood

struct CSalJpegCarriers
{
    int ExifCount, JfxxCount;
    int TooMany;
    CSalJpegSegment Exif[SALJPEG_MAX_CARRIERS];
    CSalJpegSegment Jfxx[SALJPEG_MAX_CARRIERS];
};

// reads the segment at '*pos' (fill bytes allowed); returns
//   1 = a segment with a length, '*seg' is filled and '*pos' is behind it,
//   2 = the SOS marker: '*pos' is the offset of its 0xFF byte (nothing is consumed),
//   0 = not understood (end of data, a marker without a length, a length that leaves the data)
inline int SalJpegNextSegment(const unsigned char* d, size_t size, size_t* pos, CSalJpegSegment* seg)
{
    size_t o = *pos;
    if (o >= size || d[o] != 0xFF)
        return 0;
    while (o + 1 < size && d[o + 1] == 0xFF) // fill bytes: the last 0xFF belongs to the marker
        o++;
    if (o + 1 >= size)
        return 0;
    unsigned char marker = d[o + 1];
    if (marker == 0xDA)
    {
        *pos = o;
        return 2;
    }
    // before the SOS only segments with a length are expected: tables, frame headers, APPn,
    // comments; SOI/EOI/RSTn/TEM and the byte stuffing 0x00 mean another kind of data
    if (marker < 0xC0 || marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7))
        return 0;
    if (o + 4 > size)
        return 0;
    size_t len = ((size_t)d[o + 2] << 8) | d[o + 3];
    if (len < 2 || len > size - (o + 2))
        return 0;
    seg->Marker = marker;
    seg->Payload = o + 4;
    seg->PayloadSize = len - 2;
    *pos = o + 2 + len;
    return 1;
}

// TRUE for the two segments Update Thumbnail may add, remove or rewrite
inline int SalJpegIsThumbnailCarrier(const unsigned char* d, const CSalJpegSegment* seg, int* isExif)
{
    *isExif = 0;
    if (seg->Marker == 0xE1 && seg->PayloadSize >= 6 && memcmp(d + seg->Payload, "Exif\0\0", 6) == 0)
    {
        *isExif = 1;
        return 1;
    }
    return seg->Marker == 0xE0 && seg->PayloadSize >= 5 && memcmp(d + seg->Payload, "JFXX\0", 5) == 0;
}

// next segment that must be kept; returns as SalJpegNextSegment; the thumbnail carriers
// stepped over are noted in '*carriers'
inline int SalJpegNextKeptSegment(const unsigned char* d, size_t size, size_t* pos, CSalJpegSegment* seg,
                                  CSalJpegCarriers* carriers)
{
    for (;;)
    {
        int r = SalJpegNextSegment(d, size, pos, seg);
        if (r != 1)
            return r;
        int isExif;
        if (!SalJpegIsThumbnailCarrier(d, seg, &isExif))
            return 1;
        int* count = isExif ? &carriers->ExifCount : &carriers->JfxxCount;
        if (*count >= SALJPEG_MAX_CARRIERS)
            carriers->TooMany = 1;
        else
            (isExif ? carriers->Exif : carriers->Jfxx)[(*count)++] = *seg;
    }
}

inline int SalJpegSameSegment(const unsigned char* a, const CSalJpegSegment* sa,
                              const unsigned char* b, const CSalJpegSegment* sb)
{
    return sa->Marker == sb->Marker && sa->PayloadSize == sb->PayloadSize &&
           memcmp(a + sa->Payload, b + sb->Payload, sa->PayloadSize) == 0;
}

// does the beginning of a JPEG file ('size' bytes of it, not necessarily the whole file) hold an
// Exif block before its picture data? Update Thumbnail asks its question by this (the built-in
// engine does not report Exif)
inline int SalJpegHasExif(const unsigned char* d, size_t size)
{
    if (d == NULL || size < 4 || d[0] != 0xFF || d[1] != 0xD8)
        return 0;
    size_t pos = 2;
    CSalJpegSegment seg;
    while (SalJpegNextSegment(d, size, &pos, &seg) == 1)
    {
        int isExif;
        if (SalJpegIsThumbnailCarrier(d, &seg, &isExif) && isExif)
            return 1;
    }
    return 0;
}

inline CSalJpegKeepResult SalJpegRewriteKeepsFile(const unsigned char* orig, size_t origSize,
                                                  const unsigned char* fresh, size_t freshSize)
{
    if (orig == NULL || origSize < 4 || orig[0] != 0xFF || orig[1] != 0xD8)
        return sjkOriginalNotUnderstood;
    if (fresh == NULL || freshSize < 4 || fresh[0] != 0xFF || fresh[1] != 0xD8)
        return sjkNewNotUnderstood;
    size_t po = 2, pf = 2;
    CSalJpegCarriers co, cf;
    memset(&co, 0, sizeof(co));
    memset(&cf, 0, sizeof(cf));
    for (;;)
    {
        CSalJpegSegment so, sf;
        int ro = SalJpegNextKeptSegment(orig, origSize, &po, &so, &co);
        if (ro == 0)
            return sjkOriginalNotUnderstood;
        int rf = SalJpegNextKeptSegment(fresh, freshSize, &pf, &sf, &cf);
        if (rf == 0)
            return sjkNewNotUnderstood;
        if (ro != rf)
            return sjkSegmentsDiffer; // one file has a segment more
        if (ro == 2)
            break;
        if (!SalJpegSameSegment(orig, &so, fresh, &sf))
            return sjkSegmentsDiffer;
    }
    if (origSize - po != freshSize - pf || memcmp(orig + po, fresh + pf, origSize - po) != 0)
        return sjkImageDiffers;
    if (co.TooMany)
        return sjkOriginalNotUnderstood;
    if (cf.TooMany)
        return sjkNewNotUnderstood;
    if (cf.ExifCount < co.ExifCount)
        return sjkExifGone;
    // the one thing that changed
    int exifChanged = 0;
    if (cf.ExifCount == co.ExifCount)
    {
        for (int i = 0; i < co.ExifCount; i++)
            if (!SalJpegSameSegment(orig, &co.Exif[i], fresh, &cf.Exif[i]))
                exifChanged++;
    }
    else if (co.ExifCount == 0 && cf.ExifCount == 1)
        exifChanged = 1; // a file without Exif got its block
    else
        return sjkCarriersDiffer;
    int jfxxChanged = cf.JfxxCount != co.JfxxCount;
    for (int i = 0; !jfxxChanged && i < co.JfxxCount; i++)
        jfxxChanged = !SalJpegSameSegment(orig, &co.Jfxx[i], fresh, &cf.Jfxx[i]);
    if (exifChanged > 1 || (exifChanged == 1 && jfxxChanged))
        return sjkCarriersDiffer;
    return sjkSame;
}
