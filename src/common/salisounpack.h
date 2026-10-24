// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisounpack.h
//
// When a whole unpack of a disc image may count as done (feature 338).
// Header-only; for the ISO plug-in (uniso: isoimage.cpp, uniso.cpp and the
// readers' UnpackFile) and saltests.
//
// The core deletes an image after Unpack with "Delete archive after
// unpacking" only when the plug-in reports success. The ISO plug-in reported
// success whenever the user did not cancel: a file skipped after a read error
// (Skip, Skip all, or the silent skips that follow), a file it could not
// create, a folder it could not create, a file written over by another listed
// file of the same name - each image was deleted with the only copy of what
// was not extracted. Now:
//   - a reader's UnpackFile reports a file it did not write whole as an error
//     (SalIsoFileUnpackResult), also when no box was shown;
//   - the whole unpack keeps a tally (CSalIsoWholeUnpackTally) and succeeds
//     only when every file and folder it was asked for was extracted whole and
//     no written file was written over by the same unpack
//     (SalIsoWholeUnpackSucceeded);
//   - the files the unpack wrote are remembered by the file system's identity
//     (CSalIsoWrittenFiles, salsamefile.h), so a later file that lands on one
//     of them - two records of one name, names that differ only in case or
//     are made equal by cleaning - is noticed; what cannot be told fails
//     closed (the image is kept).
//
//*****************************************************************************

#include <windows.h>
#include <new>
#include <string>
#include <unordered_set>

#include "salsamefile.h"

// the results of the ISO plug-in's unpack calls (uniso isoimage.h UNPACK_* asserts the same values)
enum
{
    SAL_ISO_UNPACK_ERROR = 0,       // not extracted (skipped, failed); the operation goes on
    SAL_ISO_UNPACK_OK = 1,          // extracted whole
    SAL_ISO_UNPACK_CANCEL = 2,      // the operation stops
    SAL_ISO_UNPACK_AUDIO_UNSUP = 3, // an audio track entry: never extracted
};

// a reader's result for one file: 'ret' as the reader set it, 'complete' FALSE when the file was not
// written whole (a read error met without a box - after Skip all - left 'ret' at OK)
inline int SalIsoFileUnpackResult(int ret, BOOL complete)
{
    return (ret == SAL_ISO_UNPACK_OK && !complete) ? SAL_ISO_UNPACK_ERROR : ret;
}

// was an asked-for entry extracted whole?
inline BOOL SalIsoUnpackItemWhole(int ret)
{
    return ret == SAL_ISO_UNPACK_OK;
}

struct CSalIsoWholeUnpackTally
{
    BOOL Cancelled = FALSE;    // the user cancelled (or an error stopped the unpack)
    BOOL NotWhole = FALSE;     // a file asked for was not extracted whole, or a folder was not created
    BOOL WroteOverOwn = FALSE; // a file was written over a file this unpack wrote

    // one file's result ('ret' of CISOImage::UnpackFile); TRUE = go on
    BOOL File(int ret)
    {
        if (ret == SAL_ISO_UNPACK_CANCEL)
        {
            Cancelled = TRUE;
            return FALSE;
        }
        if (!SalIsoUnpackItemWhole(ret))
            NotWhole = TRUE;
        return TRUE;
    }
};

// the whole unpack's result: success only when nothing was cancelled, left unextracted or written over,
// and the listing behind it was complete (features 328 - 337)
inline BOOL SalIsoWholeUnpackSucceeded(const CSalIsoWholeUnpackTally& t, BOOL listingLeftOut)
{
    return !t.Cancelled && !t.NotWhole && !t.WroteOverOwn && !listingLeftOut;
}

// The files a whole unpack wrote, by the file system's identity (the SalFileIdMatch order: the 128-bit id
// where usable, else volume serial + 64-bit index). A key of the other kind can also match (a 64-bit index
// equal under different 128-bit ids) - that only keeps an image (fails closed).
class CSalIsoWrittenFiles
{
public:
    // remembers a file this unpack wrote; 'read' FALSE = its identity could not be read
    void Note(BOOL read, const CSalFileIdentity& id)
    {
        Count++;
        try
        {
            std::string k128, k64;
            BOOL has128 = read && id.Valid && Key128(id, k128);
            BOOL has64 = read && id.Valid && Key64(id, k64);
            if (!has128 && !has64)
            {
                Lost = TRUE; // nothing to tell it by: from now on every existing target may be ours
                return;
            }
            if (has128)
                Keys.insert(k128);
            if (has64)
                Keys.insert(k64);
        }
        catch (const std::bad_alloc&)
        {
            Lost = TRUE;
        }
    }

    // is the existing target with identity 'id' ('read' FALSE = not read) a file this unpack wrote?
    // TRUE also when that cannot be told (not everything checked = it may be)
    BOOL WrittenBefore(BOOL read, const CSalFileIdentity& id) const
    {
        if (Count == 0)
            return FALSE;
        if (Lost || !read || !id.Valid)
            return TRUE;
        try
        {
            std::string k128, k64;
            BOOL has128 = Key128(id, k128);
            BOOL has64 = Key64(id, k64);
            if (!has128 && !has64)
                return TRUE;
            return (has128 && Keys.count(k128) != 0) || (has64 && Keys.count(k64) != 0);
        }
        catch (const std::bad_alloc&)
        {
            return TRUE;
        }
    }

    BOOL IsLost() const { return Lost; }

private:
    static BOOL Key128(const CSalFileIdentity& id, std::string& k)
    {
        if (!id.Has128 || !SalIdIsUsable(id.Id128, 16))
            return FALSE;
        k.assign(1, 'Q');
        k.append((const char*)&id.Vsn64, sizeof(id.Vsn64));
        k.append((const char*)id.Id128, 16);
        return TRUE;
    }
    static BOOL Key64(const CSalFileIdentity& id, std::string& k)
    {
        if (!id.Has64 || !SalIdIsUsable((const BYTE*)&id.Index64, 8))
            return FALSE;
        k.assign(1, 'D');
        k.append((const char*)&id.Vsn32, sizeof(id.Vsn32));
        k.append((const char*)&id.Index64, sizeof(id.Index64));
        return TRUE;
    }

    std::unordered_set<std::string> Keys;
    unsigned long long Count = 0; // files noted
    BOOL Lost = FALSE;            // a written file could not be remembered
};
