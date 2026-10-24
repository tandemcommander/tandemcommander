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
    SAL_ISO_TRACK_NOT_TRIED = 0,   // not opened by this listing (a single-session listing lists one track)
    SAL_ISO_TRACK_NOT_OPENED = 1,  // tried, its reader did not open it
    SAL_ISO_TRACK_LIST_FAILED = 2, // opened, its listing failed
    SAL_ISO_TRACK_LISTED = 3,      // opened and listed
};

// Feature 334: does this track leave the listing incomplete? 'outsideImage' = a data track in which no
// file system was found and whose volume descriptor area (sector 16) is not within the image file -
// nothing of it can be read (a raw data track that can be read, e.g. a Video CD's MPEG track, is not
// outside and stays unmarked). An unknown track never marks (as before: no listing ever shows it); an
// audio track marks only when it was tried and did not open or list (it always opens in practice);
// an outcome value this rule does not know marks (fails closed).
inline bool SalIsoTrackMarksListing(int kind, bool outsideImage, int outcome)
{
    if (kind == SAL_ISO_TRACK_UNKNOWN)
        return false;
    if (kind == SAL_ISO_TRACK_DATA && outsideImage)
        return true;
    return outcome != SAL_ISO_TRACK_NOT_TRIED && outcome != SAL_ISO_TRACK_LISTED;
}
