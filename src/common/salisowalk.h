// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisowalk.h
//
// The folder walk of the ISO plug-in's readers (ISO 9660, UDF, Xbox) after a
// folder that cannot be read - feature 400. Header-only; for the ISO plug-in
// (uniso: iso9660.cpp, udf.cpp, xdvdfs.cpp) and saltests.
//
// A walk descended a listed folder only while nothing in its directory and
// below had failed ("descend only when everything is OK"), and a failure was
// passed to every ancestor: after one folder that could not be read (its
// directory past the end of the image, a record failing the safety checks),
// every later folder of the image was listed empty - readable files could not
// be viewed or extracted. Now a walk descends every listed folder unless out
// of memory stopped it; a failure below still makes the directory (and the
// listing, feature 330) incomplete; and the walk shows its error box once
// (a damaged or crafted image with many such folders showed one box before,
// because the walk ended its descents).
//
//*****************************************************************************

// The result of a directory's walk - the same values as the plug-in's ERR_OK,
// ERR_CONTINUE and ERR_TERMINATE (isoimage.h; each reader asserts it): the
// directory was walked whole; it was walked but something in it or below could
// not be listed; it could not go on (its read failed, a record failed the
// checks, out of memory).
enum
{
    SAL_ISO_WALK_OK = 0,
    SAL_ISO_WALK_CONTINUE = 1,
    SAL_ISO_WALK_TERMINATE = 2
};

// One walk of one file system of an image (reset when its listing starts).
struct SalIsoWalk
{
    bool Stopped;  // out of memory met: no later folder of the walk is descended
    bool BoxShown; // the walk's error box was shown

    SalIsoWalk() : Stopped(false), BoxShown(false) {}
};

// Feature 400: may the walk descend a folder the listing took? Yes - also after
// a folder that could not be read - unless out of memory stopped the walk
// (going on would fail again in every later folder).
inline bool SalIsoWalkDescends(const SalIsoWalk& walk)
{
    return !walk.Stopped;
}

// Feature 400: a directory's walk result 'ret' after a folder in it was walked
// with the result 'child'. A failure below makes the directory incomplete
// (CONTINUE) and is never forgotten by a later folder that walks whole (the old
// code assigned the child's result - harmless only while nothing was descended
// after a failure); it never ends the directory itself.
inline int SalIsoWalkAfterChild(int ret, int child)
{
    if (ret == SAL_ISO_WALK_TERMINATE)
        return ret;
    return child == SAL_ISO_WALK_OK ? ret : SAL_ISO_WALK_CONTINUE;
}

// Feature 400: is this error box of the walk to be quiet? A quiet walk (the ISO
// 9660 reader's fit check and count walks, feature 328) stays quiet and does not
// use up the box; otherwise the walk's first box is shown and every later one is
// quiet (the listing is marked incomplete by the caller as before).
inline bool SalIsoWalkBoxQuiet(SalIsoWalk& walk, bool quiet)
{
    if (quiet || walk.BoxShown)
        return true;
    walk.BoxShown = true;
    return false;
}
