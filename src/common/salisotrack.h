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
//
//*****************************************************************************

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
