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
// The subheader is file, channel, submode, coding - twice; both copies of the submode must carry the
// Form 2 bit (0x20). A file system's volume descriptors are never in Form 2 sectors (no ECC layer; on a
// Video CD / SVCD only the MPEG stream tracks are Form 2), so a data track whose sector 16 is Form 2 is a
// stream, not a lost file system. Anything else - Mode 1, Form 1, a destroyed sync or header, one copy
// only, too few bytes - is not Form 2 (the caller then marks the track: fails closed).
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
    return (raw[sub + 2] & 0x20) != 0 && (raw[sub + 6] & 0x20) != 0;
}
