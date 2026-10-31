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
// Feature 340: the session counts of an NRG image (one SINF chunk a session) are bounded by the
// track table: a count above the tracks left read past it.
// Feature 352: a CloneCD .ccd's rows, entry session numbers and session layout are checked before
// the reader indexes its tables with them.
// Feature 353: a CloneCD .img opened without its .ccd is listed by the plain detection (the volume at
// its sector 16 - the first session); a raw image that holds room for a later volume past that one
// leaves the listing incomplete.
// Feature 354: so does a cooked (2048-byte sector) image of the plain detection whose rest past the
// volume at its sector 16 is not shown to be zero bytes beyond room for a later volume.
// Feature 356: and so does a cooked UDF-only image (no ISO 9660 descriptor at sector 16) whose file holds
// more than its UDF volume - the volume's end read from its anchors, descriptor sequences and partitions.
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

// Feature 351: the kind of a CloneCD track by the MODE of its [TRACK n] section in the .ccd file - 0
// audio, 1 / 2 a Mode 1 / Mode 2 data track (its file system is detected), any other value unknown
// (never detected nor listed; it marks the listing). The reader gave only audio a type: a data
// track kept what the heap held, and in the Release build that was often "unknown" - the image did
// not open.
inline int SalIsoCcdTrackKind(int ccdMode)
{
    if (ccdMode == 0)
        return SAL_ISO_TRACK_AUDIO;
    if (ccdMode == 1 || ccdMode == 2)
        return SAL_ISO_TRACK_DATA;
    return SAL_ISO_TRACK_UNKNOWN;
}

// Feature 352: the integer value of a .ccd row ("MODE=1", "Point=0xa0", "PLBA=-150"), read as the
// reader's sscanf("%d") / sscanf("%x") read a valid value - leading blanks, an optional sign, for hex an
// optional "0x", then digits; text after the digits is ignored - but a value with no number ("x", "")
// fails instead of leaving the field uninitialised, and so does one outside 32 bits (decimal: the int
// range; hex: up to 0xFFFFFFFF, stored as the int sscanf gave). 'out' is written only on success.
inline bool SalIsoCcdReadInt(const char* value, bool hex, int& out)
{
    if (value == nullptr)
        return false;
    const char* s = value;
    while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n' || *s == '\v' || *s == '\f')
        s++;
    bool neg = false;
    if (*s == '+' || *s == '-')
    {
        neg = *s == '-';
        s++;
    }
    auto digit = [hex](char c) -> int
    {
        if (c >= '0' && c <= '9')
            return c - '0';
        if (hex && c >= 'a' && c <= 'f')
            return c - 'a' + 10;
        if (hex && c >= 'A' && c <= 'F')
            return c - 'A' + 10;
        return -1;
    };
    if (hex && s[0] == '0' && (s[1] == 'x' || s[1] == 'X') && digit(s[2]) >= 0)
        s += 2;
    const long long base = hex ? 16 : 10;
    const long long limit = hex ? 0xFFFFFFFFLL : (neg ? 0x80000000LL : 0x7FFFFFFFLL);
    long long v = 0;
    int n = 0;
    for (; digit(*s) >= 0; s++, n++)
    {
        v = v * base + digit(*s);
        if (v > limit)
            return false;
    }
    if (n == 0)
        return false;
    if (hex)
    {
        unsigned int u = (unsigned int)v;
        if (neg)
            u = 0u - u;
        out = (int)u;
    }
    else
        out = (int)(neg ? -v : v);
    return true;
}

// Feature 352: the needed rows of one .ccd section ([TRACK n]: MODE, INDEX 1; [Entry n]: Session,
// Point, PLBA, ADR; [Session n]: PreGapMode, PreGapSubC). The reader counted a row whether its value
// parsed or not, so a row repeated while another was missing, or a value that did not parse, left a
// field uninitialised. Each needed row must now appear once and parse.
struct CSalIsoCcdFields
{
    unsigned int Seen = 0; // the fields (one bit each) whose row was read
    bool Bad = false;      // a row repeated or not parsed

    // a row of the field 'bit' was read; 'parsed' = its value parsed
    void Row(unsigned int bit, bool parsed)
    {
        if (!parsed || (Seen & bit) != 0)
            Bad = true;
        Seen |= bit;
    }

    // every field of 'required' was read once and parsed
    bool Complete(unsigned int required) const { return !Bad && (Seen & required) == required; }
};

// Feature 352: the row of the reader's per-session tables (one per [Session n] section, 'sections')
// for an [Entry n] naming session 'session' (1-based); -1 when the .ccd has no such section - the
// reader then refuses the .ccd. It used session - 1 unchecked (stored in a byte): Session=0 wrote
// before the tables, Session=200 far past them, Session=257 became session 1.
inline int SalIsoCcdSessionIndex(int session, int sections)
{
    if (sections <= 0 || session < 1 || session > sections)
        return -1;
    return session - 1;
}

// Feature 352: the reader splits the track list into sessions where a track's INDEX 1 is 0 ('splits'
// runs); the table of contents gives per-[Session n] section offsets. The row of the per-session
// tables for split 'split' (0-based), or -1 when the .ccd has fewer sections than splits (the split
// then gets no offset: 0).
inline int SalIsoCcdSplitSection(int split, int sections)
{
    if (split < 0 || split >= sections)
        return -1;
    return split;
}

// Feature 352: the session layout can be trusted only when the sections and the splits agree; a real
// multi-session dump whose INDEX 1 values are absolute has more sections than splits (one split) -
// read within bounds, its listing is marked incomplete (a whole unpack fails, the image is kept).
inline bool SalIsoCcdLayoutTrusted(int sections, int splits)
{
    return sections > 0 && sections == splits;
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

// Feature 340: how many tracks of the image's track table ('trackCount' tracks) a session starting at
// track 'first' gets, when the image says it holds 'declared' tracks (an NRG SINF chunk: an unsigned
// 32-bit count - read as an int before, 0xFFFFFFFF became -1). At most the tracks left from 'first' (none
// when 'first' is outside the table), so the listing never looks past the table; 'fits' = the declared
// count is no more than the tracks left (a count that does not fit leaves the listing incomplete).
inline int SalIsoSessionTracks(int first, unsigned int declared, int trackCount, bool& fits)
{
    long long left = (first >= 0 && first < trackCount) ? (long long)trackCount - first : 0;
    fits = (long long)declared <= left;
    return (int)(fits ? (long long)declared : left);
}

// Feature 353: a later session's volume descriptors start at its own sector 16, so a file holding no more
// than this many whole sectors past the listed volume cannot hold another volume.
const long long SAL_ISO_LATER_VOLUME_SECTOR = 16;
// the bytes of a primary volume descriptor SalIsoPvdVolumeSectors needs
const long long SAL_ISO_PVD_BYTES = 132;

// Feature 353: the size in sectors of the volume a primary volume descriptor describes - 'desc' holds the
// first 'len' bytes of the descriptor (the user data of the volume's sector 16). True only for a valid
// primary volume descriptor (type 1, "CD001", version 1) whose two copies of the volume space size (bytes
// 80..83 little-endian, 84..87 big-endian) agree and whose logical block size (128..129 little-endian,
// 130..131 big-endian) is 2048 - one block a CD sector; 'sectors' is left untouched otherwise.
inline bool SalIsoPvdVolumeSectors(const unsigned char* desc, long long len, unsigned long long& sectors)
{
    if (desc == nullptr || len < SAL_ISO_PVD_BYTES)
        return false;
    if (desc[0] != 1 || desc[1] != 'C' || desc[2] != 'D' || desc[3] != '0' || desc[4] != '0' || desc[5] != '1' ||
        desc[6] != 1)
        return false;
    unsigned long le = (unsigned long)desc[80] | ((unsigned long)desc[81] << 8) | ((unsigned long)desc[82] << 16) |
                       ((unsigned long)desc[83] << 24);
    unsigned long be = (unsigned long)desc[87] | ((unsigned long)desc[86] << 8) | ((unsigned long)desc[85] << 16) |
                       ((unsigned long)desc[84] << 24);
    unsigned int blockLe = (unsigned int)desc[128] | ((unsigned int)desc[129] << 8);
    unsigned int blockBe = (unsigned int)desc[131] | ((unsigned int)desc[130] << 8);
    if (le != be || blockLe != 2048 || blockBe != 2048)
        return false;
    sectors = le;
    return true;
}

// Feature 353: does an .img opened without its .ccd leave the listing incomplete? 'raw' = the .ccd could
// not be opened and the file starts with the CD sync pattern (a raw dump, as CloneCD writes it; an image of
// 2048-byte sectors is a plain disk image - never marked). The plain detection lists the volume at sector
// 16 only (a multi-session dump's first session); a later session lies past it. Marked when the volume's
// size is not known ('volumeKnown' false - fails closed), when the stored sector size is not positive, or
// when the file holds more than SAL_ISO_LATER_VOLUME_SECTOR whole sectors (of 'sectorRawSize' bytes, from
// 'dataOffset') past the volume's 'volumeSectors'. Review 1: also when the file ends within the volume the
// descriptor claims - the size cannot be trusted then (a damaged or crafted descriptor claiming more than
// the first session hides the later one); a truncated image kept loses nothing (feature 338).
inline bool SalIsoNoCcdRestMarks(bool raw, bool volumeKnown, unsigned long long volumeSectors, long long fileSize,
                                 long long dataOffset, long long sectorRawSize)
{
    if (!raw)
        return false;
    if (!volumeKnown || sectorRawSize <= 0)
        return true;
    long long whole = fileSize > dataOffset && dataOffset >= 0 ? (fileSize - dataOffset) / sectorRawSize : 0;
    return (unsigned long long)whole < volumeSectors ||
           (unsigned long long)whole > volumeSectors + (unsigned long long)SAL_ISO_LATER_VOLUME_SECTOR;
}

// Feature 354: the most sectors of a cooked image's rest past its volume that are read to see that the rest
// is zero bytes only (1 MiB: xorriso's native padding outside the volume measured 168 sectors, isohybrid
// aligns the file to 1 MiB); a longer rest is not read and marks the listing.
const long long SAL_ISO_ZERO_REST_SECTORS = 512;
// the bytes of a cooked sector
const long long SAL_ISO_COOKED_SECTOR = 2048;

// what SalIsoCookedRestDecision tells the plug-in to do with the listing
enum
{
    SAL_ISO_REST_KEEP_LISTING = 0, // the rest cannot hold a later volume (or the rule does not apply)
    SAL_ISO_REST_MARK = 1,         // mark the listing incomplete
    SAL_ISO_REST_CHECK = 2,        // read checkBytes from checkFrom; mark unless all read and all zero
};

// Feature 354: a cooked image (no CD sync pattern at its start, 2048-byte sectors from offset 0) opened by
// the plain detection lists the volume whose descriptor is at sector 16 only - a multi-session image's
// first session; a later session lies past it. 'iso9660' = sector 16 holds an ISO 9660 primary descriptor
// header (type 1, "CD001"; false for a UDF-only image - the rule does not apply, the listing is kept);
// 'volumeKnown' / 'volumeSectors' = SalIsoPvdVolumeSectors read its size; 'fileSize' = the file's bytes.
// MARK when the size is not known, the file size is negative, or the file holds fewer whole sectors than
// the volume (a size that cannot be trusted, as SalIsoNoCcdRestMarks); KEEP_LISTING when it holds at most
// SAL_ISO_LATER_VOLUME_SECTOR whole sectors past the volume; MARK when the bytes past the volume are more
// than SAL_ISO_ZERO_REST_SECTORS sectors (not all checked - fails closed); else CHECK: 'checkFrom' /
// 'checkBytes' = the bytes from the volume's end to the end of the file (a rest of zero bytes only holds
// neither a later volume, whose descriptors are not zero, nor data). The outputs are set for CHECK only.
inline int SalIsoCookedRestDecision(bool iso9660, bool volumeKnown, unsigned long long volumeSectors,
                                    long long fileSize, long long& checkFrom, long long& checkBytes)
{
    if (!iso9660)
        return SAL_ISO_REST_KEEP_LISTING;
    if (!volumeKnown || fileSize < 0)
        return SAL_ISO_REST_MARK;
    unsigned long long whole = (unsigned long long)(fileSize / SAL_ISO_COOKED_SECTOR);
    if (whole < volumeSectors)
        return SAL_ISO_REST_MARK;
    if (whole - volumeSectors <= (unsigned long long)SAL_ISO_LATER_VOLUME_SECTOR)
        return SAL_ISO_REST_KEEP_LISTING;
    // whole >= volumeSectors, so volumeSectors * 2048 <= fileSize: no overflow
    long long from = (long long)volumeSectors * SAL_ISO_COOKED_SECTOR;
    long long rest = fileSize - from;
    if (rest > SAL_ISO_ZERO_REST_SECTORS * SAL_ISO_COOKED_SECTOR)
        return SAL_ISO_REST_MARK;
    checkFrom = from;
    checkBytes = rest;
    return SAL_ISO_REST_CHECK;
}

// Feature 354: are all 'len' bytes of 'data' zero? (a null 'data' with bytes to check is not)
inline bool SalIsoBytesAllZero(const unsigned char* data, long long len)
{
    if (len <= 0)
        return true;
    if (data == nullptr)
        return false;
    for (long long i = 0; i < len; i++)
        if (data[i] != 0)
            return false;
    return true;
}

// Feature 355: the user-data bytes of each raw sector past the volume SalIsoRawRestDecision has read (one
// ISO 9660 block - a later volume's descriptor lies within them also when its sectors are Mode 2 XA and the
// opened layout is Mode 1, 8 bytes earlier)
const long long SAL_ISO_RAW_REST_READ = 2048;

// Feature 355: a raw image (the file starts with the CD sync pattern) opened by the plain detection under any
// name but an .img whose .ccd is missing (353's SalIsoNoCcdRestMarks) lists the volume whose descriptor is at
// the opened layout's sector 16 only - a multi-session image's first session; a later session, or audio
// tracks of a .bin without its .cue, lie past it. 'volumeKnown' / 'volumeSectors' = SalIsoPvdVolumeSectors of
// that descriptor; 'fileSize' = the file's bytes; 'dataOffset' / 'sectorRawSize' = the opened layout's offset
// of sector 0 and stored sector size. MARK when the size is not known (no ISO 9660 descriptor - fails
// closed), the sector size is not positive, the file size or offset is negative, or the file holds fewer
// whole sectors than the volume (a size that cannot be trusted, as 353); KEEP_LISTING when it holds at most
// SAL_ISO_LATER_VOLUME_SECTOR whole sectors past the volume; MARK when more than SAL_ISO_ZERO_REST_SECTORS lie
// past it (not all checked); else CHECK: read SAL_ISO_RAW_REST_READ bytes of user data of each of 'sectors'
// sectors from 'firstSector' at the layout, and mark unless every read is whole and zero bytes only (a raw
// sector's sync, header and error correction are never all zero, so the user data is what is checked; a
// post-gap or run-out holds zero user data, a later volume's descriptor and audio do not). A partial sector
// at the end of the file is not counted. The outputs are set for CHECK only.
inline int SalIsoRawRestDecision(bool volumeKnown, unsigned long long volumeSectors, long long fileSize,
                                 long long dataOffset, long long sectorRawSize, long long& firstSector,
                                 long long& sectors)
{
    if (!volumeKnown || sectorRawSize <= 0 || fileSize < 0 || dataOffset < 0)
        return SAL_ISO_REST_MARK;
    unsigned long long whole =
        fileSize > dataOffset ? (unsigned long long)((fileSize - dataOffset) / sectorRawSize) : 0;
    if (whole < volumeSectors)
        return SAL_ISO_REST_MARK;
    unsigned long long past = whole - volumeSectors;
    if (past <= (unsigned long long)SAL_ISO_LATER_VOLUME_SECTOR)
        return SAL_ISO_REST_KEEP_LISTING;
    if (past > (unsigned long long)SAL_ISO_ZERO_REST_SECTORS)
        return SAL_ISO_REST_MARK;
    // whole >= volumeSectors and whole fits a long long, so volumeSectors does too
    firstSector = (long long)volumeSectors;
    sectors = (long long)past;
    return SAL_ISO_REST_CHECK;
}

// Feature 357: the check of CISOImage::Open's plain detection (no table of sessions read) that opened the file,
// in the order the detection tries them
enum
{
    SAL_ISO_PLAIN_NONE = 0, // no check opened the file
    SAL_ISO_PLAIN_ISO,      // CheckForISO - at the detected layout (without a raw start: cooked from offset 0, 354)
    SAL_ISO_PLAIN_NRG,      // CheckForNRG - sector 0 at 0x4B000
    SAL_ISO_PLAIN_2336,     // CheckFor2336 - Mode 2 sectors of 2336 bytes
    SAL_ISO_PLAIN_NCD,      // CheckForNCD - sector 0 at 0x16E4E
    SAL_ISO_PLAIN_PDI,      // CheckForPDI - sector 0 at 0x130
    SAL_ISO_PLAIN_ECDC,     // CheckForECDC - Easy CD Creator: 2352-byte sectors, sync and header zeroed
    SAL_ISO_PLAIN_CIF,      // CheckForCIF - RIFF chunks, then sectors of 2056 bytes
    SAL_ISO_PLAIN_C2D,      // CheckForC2D - WinOnCD (0x20000; 0x76220 Mode 2) and Roxio (0x120)
    SAL_ISO_PLAIN_CIF2332,  // CheckForCIF2332 - sectors of 2332 bytes
    SAL_ISO_PLAIN_XBOX,     // CheckForXbox - XDVDFS
    SAL_ISO_PLAIN_MDF,      // CheckForMDF - needs the sync pattern at offset 0
    SAL_ISO_PLAIN_HFS,      // CheckForHFS
    SAL_ISO_PLAIN_APFS,     // CheckForAPFS
};

// Feature 357: does feature 355's rule of the rest past the listed volume (SalIsoRawRestDecision at the opened
// layout) apply to an image the plain detection opened? 'rawStart' = the file starts with the CD sync pattern;
// 'ccdMissing' = an .img whose .ccd could not be opened; 'layout' = SAL_ISO_PLAIN_*. A raw start applies as 355
// decided (any layout) unless the .ccd is missing (353's rule). Without a raw start the rule applies to the CD
// layouts whose listed volume is an ISO 9660 volume at the layout's sector 16 and whose sectors carry the user
// data at a fixed place - NRG offset, 2336, NCD, PDI, ECDC, CIF, C2D, CIF 2332: a later session of a
// multi-session disc lies past that volume. Not to ISO (cooked from offset 0 - 354's rule), Xbox (XDVDFS: no ISO
// 9660 size, no sessions), HFS, APFS (no CD sessions), MDF (always a raw start) or an unknown value.
inline bool SalIsoPlainRawRuleApplies(bool rawStart, bool ccdMissing, int layout)
{
    if (rawStart)
        return !ccdMissing;
    switch (layout)
    {
    case SAL_ISO_PLAIN_NRG:
    case SAL_ISO_PLAIN_2336:
    case SAL_ISO_PLAIN_NCD:
    case SAL_ISO_PLAIN_PDI:
    case SAL_ISO_PLAIN_ECDC:
    case SAL_ISO_PLAIN_CIF:
    case SAL_ISO_PLAIN_C2D:
    case SAL_ISO_PLAIN_CIF2332:
        return true;
    default:
        return false;
    }
}

// Feature 356: a cooked image whose sector 16 holds the UDF volume recognition sequence and no ISO 9660
// primary descriptor (a UDF-only image - IMAPI2FS, mkudffs, Blu-ray) is listed from its UDF descriptors (the
// plug-in's CUDF reads 2048-byte blocks, the anchor at sector 256 first). Feature 354's rule needs the
// volume's size; here it is read from the UDF structures (ECMA-167 / OSTA UDF), all in 2048-byte sectors:
//   - the anchor volume descriptor pointer at sector 256 names the main and the reserve volume descriptor
//     sequence; a closed volume has its own anchors also at its last sector and 256 before it;
//   - the partition descriptors of the main sequence give each partition's start and length;
//   - a volume with a virtual partition (VAT, sequentially written media) claims the whole medium in its
//     partition descriptor, and its last recorded sector is the VAT's (extended) file entry.
// Measured (fix-log of 356): every plain image ends with its own anchor at its last sector or, VAT (open or
// closed), with its VAT there; IMAPI2FS fills the sectors past its reserve sequence with its own anchors.

// the anchor's sector; the most sectors of the main descriptor sequence read for its partition descriptors
const long long SAL_ISO_UDF_ANCHOR_SECTOR = 256;
const long long SAL_ISO_UDF_VDS_READ = 64;
// descriptor tag identifiers
const unsigned int SAL_ISO_UDF_TAG_ANCHOR = 2;
const unsigned int SAL_ISO_UDF_TAG_PARTITION = 5;
const unsigned int SAL_ISO_UDF_TAG_LOGICAL_VOLUME = 6;
const unsigned int SAL_ISO_UDF_TAG_TERMINATING = 8;
const unsigned int SAL_ISO_UDF_TAG_FILE_ENTRY = 261;
const unsigned int SAL_ISO_UDF_TAG_EXT_FILE_ENTRY = 266;

inline unsigned long SalIsoUdfLe32(const unsigned char* p)
{
    return (unsigned long)p[0] | ((unsigned long)p[1] << 8) | ((unsigned long)p[2] << 16) |
           ((unsigned long)p[3] << 24);
}

// Is the descriptor tag in the first 16 of 'len' bytes of 'sec' a valid tag of identifier 'id' recorded at
// 'location'? The identifier (bytes 0-1), the checksum (byte 4 = the sum of bytes 0-3 and 5-15, modulo 256)
// and the tag location (bytes 12-15) are checked; the descriptor CRC is not (as the plug-in's UDF reader).
inline bool SalIsoUdfTagValid(const unsigned char* sec, long long len, unsigned int id, unsigned long long location)
{
    if (sec == nullptr || len < 16)
        return false;
    if (((unsigned int)sec[0] | ((unsigned int)sec[1] << 8)) != id)
        return false;
    unsigned int sum = 0;
    for (int i = 0; i < 16; i++)
        if (i != 4)
            sum += sec[i];
    if ((sum & 0xFF) != sec[4])
        return false;
    return (unsigned long long)SalIsoUdfLe32(sec + 12) == location;
}

// the descriptor sequences an anchor names (extent lengths in bytes, locations in sectors)
struct SalIsoUdfAnchor
{
    unsigned long MainLength;
    unsigned long MainLocation;
    unsigned long ReserveLength;
    unsigned long ReserveLocation;
};

// Is 'sec' (its first 'len' bytes) a valid anchor recorded at sector 'at'? Fills 'a' only then.
inline bool SalIsoUdfReadAnchor(const unsigned char* sec, long long len, unsigned long long at, SalIsoUdfAnchor& a)
{
    if (len < 32 || !SalIsoUdfTagValid(sec, len, SAL_ISO_UDF_TAG_ANCHOR, at))
        return false;
    a.MainLength = SalIsoUdfLe32(sec + 16);
    a.MainLocation = SalIsoUdfLe32(sec + 20);
    a.ReserveLength = SalIsoUdfLe32(sec + 24);
    a.ReserveLocation = SalIsoUdfLe32(sec + 28);
    return true;
}

// Is 'sec' an anchor of the volume whose anchor at sector 256 is 'vol' - valid at sector 'at' and naming the
// same two descriptor sequences? (A later or joined volume's anchors name its own sequences.)
inline bool SalIsoUdfAnchorOf(const unsigned char* sec, long long len, unsigned long long at, const SalIsoUdfAnchor& vol)
{
    SalIsoUdfAnchor a;
    return SalIsoUdfReadAnchor(sec, len, at, a) && a.MainLength == vol.MainLength &&
           a.MainLocation == vol.MainLocation && a.ReserveLength == vol.ReserveLength &&
           a.ReserveLocation == vol.ReserveLocation;
}

// the sector after an extent of 'lengthBytes' bytes from sector 'location'
inline unsigned long long SalIsoUdfExtentEnd(unsigned long location, unsigned long lengthBytes)
{
    return (unsigned long long)location + ((unsigned long long)lengthBytes + 2047) / 2048;
}

// the sector after the anchor at 256 and both descriptor sequences it names
inline unsigned long long SalIsoUdfDescriptorsEnd(const SalIsoUdfAnchor& a)
{
    unsigned long long end = (unsigned long long)SAL_ISO_UDF_ANCHOR_SECTOR + 1;
    end = (std::max)(end, SalIsoUdfExtentEnd(a.MainLocation, a.MainLength));
    end = (std::max)(end, SalIsoUdfExtentEnd(a.ReserveLocation, a.ReserveLength));
    return end;
}

// Is 'sec' a valid partition descriptor recorded at sector 'at'? Then 'start' = its starting sector and
// 'end' = the sector after its last (start + length, bytes 188-191 and 192-195).
inline bool SalIsoUdfPartition(const unsigned char* sec, long long len, unsigned long long at, unsigned long& start,
                               unsigned long long& end)
{
    if (len < 196 || !SalIsoUdfTagValid(sec, len, SAL_ISO_UDF_TAG_PARTITION, at))
        return false;
    start = SalIsoUdfLe32(sec + 188);
    end = (unsigned long long)start + SalIsoUdfLe32(sec + 192);
    return true;
}

// Is 'sec' a valid logical volume descriptor recorded at sector 'at' with a virtual partition map - a type 2
// map (byte 0 = 2, byte 1 = its length) whose partition type identifier (bytes 5.. of the map) is
// "*UDF Virtual Partition"? The maps (from byte 440, the table's length at 264, their count at 268) are
// walked within 'len' bytes only.
inline bool SalIsoUdfLvdHasVirtualMap(const unsigned char* sec, long long len, unsigned long long at)
{
    if (len < 440 || !SalIsoUdfTagValid(sec, len, SAL_ISO_UDF_TAG_LOGICAL_VOLUME, at))
        return false;
    static const char virt[] = "*UDF Virtual Partition";
    const long long idLen = (long long)sizeof(virt) - 1;
    unsigned long count = SalIsoUdfLe32(sec + 268);
    long long end = 440 + (long long)SalIsoUdfLe32(sec + 264);
    if (end > len)
        end = len;
    long long off = 440;
    for (unsigned long i = 0; i < count && off + 2 <= end; i++)
    {
        long long mapLen = sec[off + 1];
        if (mapLen < 2 || off + mapLen > end)
            break;
        if (sec[off] == 2 && 5 + idLen <= mapLen)
        {
            bool same = true;
            for (long long k = 0; k < idLen && same; k++)
                same = sec[off + 5 + k] == (unsigned char)virt[k];
            if (same)
                return true;
        }
        off += mapLen;
    }
    return false;
}

// Is 'sec' a valid (extended) file entry of the partition starting at 'partitionStart', read from sector
// 'at'? (Its tag location is the logical block within the partition.) The VAT of an open VAT volume.
inline bool SalIsoUdfFileEntryAt(const unsigned char* sec, long long len, unsigned long partitionStart,
                                 unsigned long long at)
{
    if (at < partitionStart)
        return false;
    unsigned long long block = at - partitionStart;
    return SalIsoUdfTagValid(sec, len, SAL_ISO_UDF_TAG_FILE_ENTRY, block) ||
           SalIsoUdfTagValid(sec, len, SAL_ISO_UDF_TAG_EXT_FILE_ENTRY, block);
}

// Feature 356: does the file end with the volume - is its last whole sector 'last' (its first 'len' bytes in
// 'sec') an anchor of the volume (never the anchor at 256 itself) or, for a volume with a virtual partition
// map, a file entry of the partition starting at 'partitionStart' (an open VAT volume's VAT)? Only the last
// sector counts: the sector 256 before it is no proof - IMAPI2FS fills every sector past its reserve
// sequence with the volume's anchors, so data appended after such a volume would find one there (review 1).
inline bool SalIsoUdfClosesFile(const unsigned char* sec, long long len, unsigned long long last,
                                const SalIsoUdfAnchor& vol, bool virtualMap, unsigned long partitionStart)
{
    if (last <= (unsigned long long)SAL_ISO_UDF_ANCHOR_SECTOR || len != SAL_ISO_COOKED_SECTOR)
        return false; // a sector not read whole proves nothing
    return SalIsoUdfAnchorOf(sec, len, last, vol) ||
           (virtualMap && SalIsoUdfFileEntryAt(sec, len, partitionStart, last));
}

// What the plug-in read of a UDF-only cooked image:
//   AnchorKnown    the anchor at sector 256 is valid (Anchor = its sequences)
//   PartitionKnown the main sequence (at most SAL_ISO_UDF_VDS_READ sectors) holds a valid partition
//                  descriptor (PartitionStart = the first one's start)
//   DescriptorsEnd the sector after the anchor at 256, both sequences and every partition found
//   ClosedAtEnd    SalIsoUdfClosesFile of the file's last whole sector: the volume ends where the file ends
//   VirtualMap     the logical volume descriptor has a virtual partition map (a VAT volume)
struct SalIsoUdfVolume
{
    bool AnchorKnown;
    SalIsoUdfAnchor Anchor;
    bool PartitionKnown;
    unsigned long PartitionStart;
    unsigned long long DescriptorsEnd;
    bool ClosedAtEnd;
    bool VirtualMap;
};

// Feature 356: what to do with the listing of a UDF-only cooked image of 'fileSize' bytes. MARK when the
// anchor at 256 or a partition descriptor is not known (the volume's end cannot be read - fails closed) or
// the file size is negative; KEEP_LISTING when the volume closes at the file's end; MARK for a VAT volume
// that does not (its partition claims the whole medium, so the descriptors do not tell where it ends -
// review 2); else feature 354's rule with the descriptors' end as the volume's size (more than 16 whole
// sectors past it are read, up to 512; fewer whole sectors than it mark). For CHECK, every sector of the rest
// must pass SalIsoUdfRestSectorEmpty.
inline int SalIsoUdfRestDecision(const SalIsoUdfVolume& v, long long fileSize, long long& checkFrom,
                                 long long& checkBytes)
{
    if (!v.AnchorKnown || !v.PartitionKnown || fileSize < 0)
        return SAL_ISO_REST_MARK;
    if (v.ClosedAtEnd)
        return SAL_ISO_REST_KEEP_LISTING;
    if (v.VirtualMap)
        return SAL_ISO_REST_MARK;
    return SalIsoCookedRestDecision(true, true, v.DescriptorsEnd, fileSize, checkFrom, checkBytes);
}

// Feature 356: is a sector of the rest past a UDF volume empty - zero bytes only, or a whole sector holding
// an anchor of this volume (as IMAPI2FS fills the rest) at its own sector 'at'? Anything else (data, a later
// volume, a sparing table) is not.
inline bool SalIsoUdfRestSectorEmpty(const unsigned char* sec, long long len, unsigned long long at,
                                     const SalIsoUdfAnchor& vol)
{
    if (SalIsoBytesAllZero(sec, len))
        return true;
    return len == SAL_ISO_COOKED_SECTOR && SalIsoUdfAnchorOf(sec, len, at, vol);
}
