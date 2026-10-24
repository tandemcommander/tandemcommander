// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisotrack.h
//
// Which tracks of a disc image with a track table (NRG, CCD/IMG, ...) leave
// the ISO plug-in's listing incomplete (feature 334). Header-only, no
// globals; for the ISO plug-in (uniso, isoimage.cpp) and saltests.
//
// The plug-in lists a multi-session image with one folder per session and a
// single-session one by its last data track (falling back to the other
// tracks when that one does not open). A track that did not open was skipped
// without marking the listing (feature 328's "incomplete" mark, which makes a
// whole unpack fail), and a data track lying past the end of the image was
// taken as a raw data track that lists nothing - Unpack with "Delete archive
// after unpacking" then deleted the image and the files of that track.
// Feature 335: so did a data track within the image whose file system area is damaged - it is told
// from a Video CD's MPEG stream (Mode 2 Form 2 sectors) by its sector 16.
// Feature 336: and so did such a Form 2 stream that no listed file starts in.
// Feature 337: and so did a stream whose listed files read only part of it.
//
//*****************************************************************************

#include <algorithm>

// the track's kind in the image's track table
enum
{
    SAL_ISO_TRACK_DATA = 0,    // a data track (a file system, or raw data the plug-in does not list)
    SAL_ISO_TRACK_AUDIO = 1,   // an audio track
    SAL_ISO_TRACK_UNKNOWN = 2, // a type the track table does not name: never listed by any path
};

// what the listing did with the track
enum
{
    SAL_ISO_TRACK_NOT_TRIED = 0,   // not opened by this listing (a single-session listing lists one data track)
    SAL_ISO_TRACK_NOT_OPENED = 1,  // tried, its reader did not open it
    SAL_ISO_TRACK_LIST_FAILED = 2, // opened, its listing failed
    SAL_ISO_TRACK_LISTED = 3,      // opened and listed
    SAL_ISO_TRACK_LEFT_OUT = 4,    // no session of the track table covers it (the session counts are short)
};

// Feature 334: does this track leave the listing incomplete (a whole unpack then fails and "Delete
// archive after unpacking" keeps the image)?
//   - a data track: when its content is lost to every listing ('rawLost': no file system was found
//     and its volume descriptor area is not within the image file - SalIsoTrackSectorOutside - or,
//     feature 335, is not a Mode 2 Form 2 sector - SalIsoSectorIsForm2), or when the listing tried it
//     and it did not open or list, or left it out. A data track a single-session listing does not try
//     is not marked (that listing shows the last data track, whose directory holds the earlier
//     sessions' files); a raw data track in Form 2 sectors (a Video CD's MPEG track) is not marked
//     either.
//   - an audio track: always - the plug-in never extracts audio (a whole unpack skips it silently),
//     listed or not (review 1: a data + audio disc lost its audio tracks).
//   - an unknown track: always - no listing ever shows it (review 1).
//   - a kind or an outcome this rule does not know: marked (fails closed).
inline bool SalIsoTrackMarksListing(int kind, bool rawLost, int outcome)
{
    if (kind != SAL_ISO_TRACK_DATA)
        return true;
    if (rawLost)
        return true;
    return outcome != SAL_ISO_TRACK_NOT_TRIED && outcome != SAL_ISO_TRACK_LISTED;
}

// Feature 334: is the user data of a track's sector at byte offset 'at' (sectorUser bytes) outside an
// image file of 'fileSize' bytes? A negative offset (a track start read as a huge or negative number,
// or an offset that overflowed) is outside too (review 1).
inline bool SalIsoTrackSectorOutside(long long at, long long sectorUser, long long fileSize)
{
    if (at < 0 || sectorUser < 0 || fileSize < 0)
        return true;
    return at > fileSize || sectorUser > fileSize - at;
}

// Feature 335: is a track's sector a CD-ROM XA Mode 2 Form 2 sector? 'raw' holds the first 'len' bytes
// of the sector as the image stores it, in sectors of 'sectorRawSize' bytes:
//   - 2352 bytes or more (a raw sector, also with subchannel data after it): the sync pattern
//     (00 FF x 10 00), the mode byte at 15 = 2 and the subheader at 16..23;
//   - 2336 bytes (a Mode 2 sector without sync and header): the subheader at 0..7;
//   - any other size (only the 2048 bytes of user data): a Form 2 sector's 2324 bytes cannot be stored -
//     never Form 2.
// The subheader is file, channel, submode, coding - twice. It counts only when it is a valid CD-ROM XA
// subheader - both copies equal, the channel number below 32, at most one of the data / audio / video
// submode bits (0x08 / 0x04 / 0x02) - and its submode carries the Form 2 bit (0x20): a 2336-byte sector
// has no sync to check, and a sector overwritten with 0xFF or text could otherwise pass (review 1).
// A file system's volume descriptors are never in Form 2 sectors (no ECC layer; on a Video CD / SVCD
// only the MPEG stream tracks are Form 2), so a data track whose sector 16 is Form 2 is a stream, not a
// lost file system. Anything else - Mode 1, Form 1, a destroyed sync or header, one copy only, too few
// bytes - is not Form 2 (the caller then marks the track: fails closed). A whole track is decided by
// SalIsoForm2SectorsToCheck below.
inline bool SalIsoSectorIsForm2(const unsigned char* raw, long long len, long long sectorRawSize)
{
    if (raw == nullptr || len < 0)
        return false;
    int sub; // offset of the subheader in 'raw'
    if (sectorRawSize >= 2352)
    {
        if (len < 24)
            return false;
        if (raw[0] != 0x00 || raw[11] != 0x00)
            return false;
        for (int i = 1; i < 11; i++)
        {
            if (raw[i] != 0xFF)
                return false;
        }
        if (raw[15] != 2)
            return false;
        sub = 16;
    }
    else if (sectorRawSize == 2336)
    {
        if (len < 8)
            return false;
        sub = 0;
    }
    else
        return false;
    for (int i = 0; i < 4; i++)
    {
        if (raw[sub + i] != raw[sub + 4 + i])
            return false;
    }
    if (raw[sub + 1] >= 32)
        return false;
    unsigned char type = raw[sub + 2] & 0x0E;
    if (type != 0 && type != 0x08 && type != 0x04 && type != 0x02)
        return false;
    return (raw[sub + 2] & 0x20) != 0;
}

// Feature 335 (reviews 2, 3): which sectors decide whether a raw data track is a Form 2 stream. A track
// is a stream only when every sector from its sector 16 on, up to SAL_ISO_FORM2_STREAM_SECTORS of them,
// is Form 2 (SalIsoSectorIsForm2) - review 2: a sector 16 overwritten with UTF-16 text that starts with
// spaces ("20 00 20 00" twice) is a valid Form 2 subheader, the Form 1 sectors after it are not; a Video
// CD's MPEG track is Form 2 throughout (its front margin, then the stream).
// Returns how many sectors, from sector 16 on, to read: those whose stored sector ('sectorRawSize' bytes
// from 'sector16At' on, the next ones following it) lies wholly within the image file of 'fileSize' bytes
// and, when the track's end is known ('trackEnd' after 'trackStart'), within the track. 0 = sector 16
// itself is not there (review 3: a short track before a stream would read the stream's sectors; a
// negative offset or size) - the track is not a stream.
const int SAL_ISO_FORM2_STREAM_SECTORS = 16;
inline int SalIsoForm2SectorsToCheck(long long sector16At, long long sectorRawSize, long long trackStart,
                                     long long trackEnd, long long fileSize)
{
    if (sector16At < 0 || sectorRawSize <= 0 || fileSize < 0)
        return 0;
    long long limit = fileSize;
    if (trackEnd > trackStart && trackEnd < limit)
        limit = trackEnd;
    int n = 0;
    long long at = sector16At;
    while (n < SAL_ISO_FORM2_STREAM_SECTORS && at <= limit && sectorRawSize <= limit - at)
    {
        n++;
        at += sectorRawSize;
    }
    return n;
}

// Feature 336: the track a file's start extent (the disc address of its first sector) lies in - the rule
// of CISOImage::GetTrackFromExtent, by which the unpack picks the track it reads the file from: the track
// before the first track (from the second on) whose extent offset is above the extent, else the last
// track (-1 when there is none). 'extentOffsetOf(t)' gives track t's extent offset.
template <class TExtentOffsetOf>
inline int SalIsoTrackOfExtent(int trackCount, unsigned long extent, TExtentOffsetOf extentOffsetOf)
{
    for (int t = 1; t < trackCount; t++)
    {
        if (extent < extentOffsetOf(t))
            return t - 1;
    }
    return trackCount - 1;
}

// Feature 336: a listed file of 'size' bytes starting at 'extent' covers the track it starts in
// (covered[t] = true, 'covered' holds 'trackCount' flags). A file of zero bytes extracts nothing of the
// track and covers nothing (fails closed); so does a file whose 'extent' is not a disc address
// ('discAddress' false - review 1: an HFS+ catalog record number, a UDF partition-relative block; only
// ISO 9660 records give the disc address of a file's first sector).
// Feature 337: the rules of SalIsoNoteFileStart, returning the track (-1 = the file covers no track).
template <class TExtentOffsetOf>
inline int SalIsoFileStartTrack(int trackCount, unsigned long extent, unsigned long long size, bool discAddress,
                                TExtentOffsetOf extentOffsetOf)
{
    if (size == 0 || !discAddress)
        return -1;
    int t = SalIsoTrackOfExtent(trackCount, extent, extentOffsetOf);
    // review 2: the unpack keeps the track number in a byte (GetTrackFromExtent returns BYTE) - a file of
    // a track above 255 (a malformed track table; a CD has at most 99) is read from another track
    if (t >= 0 && t < trackCount && t <= 255)
        return t;
    return -1;
}

template <class TExtentOffsetOf>
inline void SalIsoNoteFileStart(bool* covered, int trackCount, unsigned long extent, unsigned long long size,
                                bool discAddress, TExtentOffsetOf extentOffsetOf)
{
    if (covered == nullptr)
        return;
    int t = SalIsoFileStartTrack(trackCount, extent, size, discAddress, extentOffsetOf);
    if (t >= 0)
        covered[t] = true;
}

// Feature 336: does a track leave the listing incomplete because it is a Form 2 stream (feature 335:
// no file system, sectors 16..31 Mode 2 Form 2) that no listed file starts in? A Video CD's streams are
// extracted through its AVSEQnn files, which start in them; a stream no file refers to (in a session of
// its own, or a Video CD whose directory lost the entries) is in no listing - a whole unpack then fails
// and "Delete archive after unpacking" keeps the image.
inline bool SalIsoStreamTrackMarksListing(bool form2Stream, bool fileStartsInTrack)
{
    return form2Stream && !fileStartsInTrack;
}

// Feature 337: a file that starts in a stream does not cover all of it - a damaged or crafted directory
// record shorter than its stream extracts only its part. A stream a file starts in counts as covered only
// when every sector of the track that no such file reads is an empty Form 2 sector (2324 zero bytes of
// user data) and there are at most SAL_ISO_STREAM_GAP_SECTORS of them. Measured on real vcdimager Video
// CDs / SVCDs: each AVSEQnn file starts at its track's first sector and leaves the last 150 sectors (the
// next track's pregap, the post-gap before the lead-out) uncovered - all of them empty; the files' own
// margins are inside the files. A count alone cannot tell such a disc from a 64-sector stream whose file
// reads one sector; the content can.

// the sectors of a stream the uncovered part may have at most: a 150-sector pregap and a 150-sector
// post-gap (2 seconds each); more are not read - the listing is marked
const long long SAL_ISO_STREAM_GAP_SECTORS = 300;
// the bytes the unpack reads from each sector of a file (ISO 9660 logical blocks)
const long long SAL_ISO_FILE_SECTOR_SIZE = 2048;
// the user data of a Mode 2 Form 2 sector
const int SAL_ISO_FORM2_PAYLOAD = 2324;

// Feature 337: how many stored sectors of 'sectorSize' bytes a stream track holds, from byte 'start' of an
// image file of 'fileSize' bytes - a last sector stored only in part counts too (review 1: its bytes are
// checked; it cannot be read whole, so it marks the listing unless a file covers it). Fails closed on a
// wrong track-table end: an end at or before the start is unknown (the image's end is taken); a next
// track ('nextStart', -1 = none; for the last track the caller passes the end of the image's sector data -
// review 2) that starts later in the file than the end extends it (an end too small - the bytes up to the
// next track are checked too); nothing past the image file counts. 0 = no sector (the caller marks the
// listing).
inline long long SalIsoStreamTrackSectors(long long start, long long end, long long nextStart, long long fileSize,
                                          long long sectorSize)
{
    if (start < 0 || sectorSize <= 0 || fileSize < 0 || start >= fileSize)
        return 0;
    long long e = end > start ? end : fileSize;
    if (nextStart > e)
        e = nextStart;
    if (e > fileSize)
        e = fileSize;
    return (e - start) / sectorSize + ((e - start) % sectorSize != 0 ? 1 : 0);
}

// Feature 337: the sectors [first, end) of a stream track (counted from its first sector, the disc address
// 'trackFirst'; 'trackSectors' sectors) that a listed file of 'size' bytes starting at disc address
// 'extent' extracts whole - floor(size / 2048) sectors from the extent on, clipped to the track. Review 1:
// the unpack reads ceil(size / 2048) sectors (CRawFS::UnpackFile) but writes only size % 2048 bytes of the
// last one - the rest of that sector is not extracted, so it is left to the gap check. False (nothing
// covered): a file of less than one sector, no sectors, an extent before the track's first sector (the
// unpack's block number would wrap) or at or after its end.
inline bool SalIsoFileSectorSpan(unsigned long extent, unsigned long long size, unsigned long trackFirst,
                                 long long trackSectors, long long* first, long long* end)
{
    if (first == nullptr || end == nullptr || trackSectors <= 0 || extent < trackFirst)
        return false;
    long long f = (long long)(extent - trackFirst);
    unsigned long long sectors = size / SAL_ISO_FILE_SECTOR_SIZE;
    if (f >= trackSectors || sectors == 0)
        return false;
    unsigned long long room = (unsigned long long)(trackSectors - f);
    *first = f;
    *end = f + (long long)(sectors < room ? sectors : room);
    return true;
}

// Feature 337: the sectors [First, End) of stream track 'Track' a listed file reads
struct SalIsoStreamSpan
{
    int Track;
    long long First;
    long long End;
};

// Feature 337: sorts 'spans' by track and first sector and merges the overlapping or adjacent spans of a
// track (empty spans are dropped); returns the number of merged spans at the start of 'spans'.
inline int SalIsoMergeStreamSpans(SalIsoStreamSpan* spans, int n)
{
    if (spans == nullptr || n <= 0)
        return 0;
    std::sort(spans, spans + n, [](const SalIsoStreamSpan& a, const SalIsoStreamSpan& b)
              { return a.Track != b.Track ? a.Track < b.Track : a.First < b.First; });
    int m = 0;
    for (int i = 0; i < n; i++)
    {
        if (spans[i].End <= spans[i].First)
            continue;
        if (m > 0 && spans[m - 1].Track == spans[i].Track && spans[i].First <= spans[m - 1].End)
        {
            if (spans[i].End > spans[m - 1].End)
                spans[m - 1].End = spans[i].End;
        }
        else
            spans[m++] = spans[i];
    }
    return m;
}

// Feature 337: how many of the 'trackSectors' sectors of track 'track' no merged span (SalIsoMergeStreamSpans)
// covers.
inline long long SalIsoStreamUncovered(const SalIsoStreamSpan* merged, int n, int track, long long trackSectors)
{
    if (trackSectors <= 0)
        return 0;
    long long covered = 0;
    for (int i = 0; merged != nullptr && i < n; i++)
    {
        if (merged[i].Track != track)
            continue;
        long long f = merged[i].First < 0 ? 0 : merged[i].First;
        long long e = merged[i].End < trackSectors ? merged[i].End : trackSectors;
        if (e > f)
            covered += e - f;
    }
    return trackSectors - covered;
}

// Feature 337: the next run [*gapFirst, *gapEnd) of the sectors of track 'track' that no merged span covers, at
// or after '*cursor' (start with 0; it is moved past the run). False = no further run.
inline bool SalIsoStreamNextGap(const SalIsoStreamSpan* merged, int n, int track, long long trackSectors,
                                long long* cursor, long long* gapFirst, long long* gapEnd)
{
    if (cursor == nullptr || gapFirst == nullptr || gapEnd == nullptr)
        return false;
    long long pos = *cursor < 0 ? 0 : *cursor;
    for (int i = 0; merged != nullptr && i < n && pos < trackSectors; i++)
    {
        if (merged[i].Track != track || merged[i].End <= pos)
            continue;
        if (merged[i].First > pos)
        {
            *gapFirst = pos;
            *gapEnd = merged[i].First < trackSectors ? merged[i].First : trackSectors;
            *cursor = *gapEnd;
            return true;
        }
        pos = merged[i].End;
    }
    if (pos < trackSectors)
    {
        *gapFirst = pos;
        *gapEnd = trackSectors;
        *cursor = trackSectors;
        return true;
    }
    *cursor = pos;
    return false;
}

// Feature 337: where a stored sector of 'sectorRawSize' bytes holds its 2324 bytes of Form 2 user data
// (after the 8-byte subheader): 24 in a raw sector (2352 bytes, also with subchannel data after it), 8 in
// a 2336-byte Mode 2 sector; -1 = no Form 2 data can be stored (a stream track never has such a size).
inline long long SalIsoForm2PayloadOffset(long long sectorRawSize)
{
    if (sectorRawSize >= 2352)
        return 24;
    if (sectorRawSize == 2336)
        return 8;
    return -1;
}

// Feature 337: is a sector's Form 2 user data ('len' bytes read) empty - read whole and all zero? A short
// read is not (fails closed); a Form 1 sector's ECC lies in these bytes, so it never passes as empty.
inline bool SalIsoPayloadEmpty(const unsigned char* payload, long long len)
{
    if (payload == nullptr || len != SAL_ISO_FORM2_PAYLOAD)
        return false;
    for (int i = 0; i < SAL_ISO_FORM2_PAYLOAD; i++)
    {
        if (payload[i] != 0)
            return false;
    }
    return true;
}

// Feature 337: does a stream track that a listed file starts in leave the listing incomplete? Yes when it
// has no sector, when more than SAL_ISO_STREAM_GAP_SECTORS of its sectors are uncovered (they are not
// read), or when an uncovered sector is not empty ('gapsEmpty' false - also an unreadable one).
inline bool SalIsoStreamGapsMark(long long trackSectors, long long uncovered, bool gapsEmpty)
{
    if (trackSectors <= 0 || uncovered < 0 || uncovered > SAL_ISO_STREAM_GAP_SECTORS)
        return true;
    return !gapsEmpty;
}
