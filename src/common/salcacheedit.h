// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salcacheedit.h
//
// Feature 112: a temporary copy with a pending edit is never thrown away by a
// flush of the disk cache.
//
// A file opened for editing from an archive (F4, Enter on an associated file -
// CFilesWindow::ExecuteFromArchive) is a temporary copy in the disk cache
// (cache.cpp) that the panel tracks in its CFileTimeStamps list until it packs
// the edit back. The copy holds one lock of that panel - its ExecuteAssocEvent -
// for exactly as long as it is tracked; since feature 112 that lock is an EDIT
// lock (crtCacheEdit, never passed by plug-ins).
//
// Before: a flush of the archive's keys (the other panel updated the archive,
// or reopened it after another program changed it) marked every copy still in
// use "out of date", the tracked one too, and the next look-up of that member
// (F3 / F4 in either panel) deleted the copy and extracted the member over it.
// The edit was lost; with an unchanged member the stamp then matched and
// nothing was offered for the update.
//
// Now a flush that meets an edit lock does not mark the copy out of date; it
// remembers "stale after the edit" instead, and the mark is set when the last
// edit lock goes - after the panel packed (or declined to pack) its edits. A
// copy without an edit lock behaves exactly as before; plug-ins never pass an
// edit lock, so their use of the cache is unchanged.
//
// Invariant: while EditLocks > 0 the record is never "out of date" (the look-up
// never re-creates it), and StaleAfterEdit implies EditLocks > 0.
//
// Header-only and pure, so the rule is covered by saltests; CCacheData (cache.h)
// holds one CSalCacheEditPin and calls it under the cache's monitor.
//
//*****************************************************************************

// what a flush does to one record of the disk cache
enum CSalCacheFlushAction
{
    scfaDelete,        // nobody uses the copy: the record and its file are deleted now
    scfaMarkOutOfDate, // in use, no edit lock: marked out of date (re-created on its next look-up)
    scfaDeferStale,    // in use with an edit lock: kept as it is, marked out of date when the last edit lock goes
};

struct CSalCacheEditPin
{
    int EditLocks;       // edit locks the record holds now
    BOOL StaleAfterEdit; // a flush arrived while edit locks were held

    CSalCacheEditPin()
    {
        EditLocks = 0;
        StaleAfterEdit = FALSE;
    }

    // a flush meets the record; 'inUse' = it has a lock or a pending request (!CCacheData::IsLocked())
    CSalCacheFlushAction OnFlush(BOOL inUse)
    {
        if (!inUse)
            return scfaDelete;
        if (EditLocks > 0)
        {
            StaleAfterEdit = TRUE;
            return scfaDeferStale;
        }
        return scfaMarkOutOfDate;
    }

    // an edit lock was added; '*outOfDate' is the record's out-of-date mark: a mark set before the
    // lock (a flush between the look-up and the lock) is turned into the deferred one - the copy now
    // holds an edit and must not be re-created under it
    void OnEditLockAdded(BOOL* outOfDate)
    {
        EditLocks++;
        if (*outOfDate)
        {
            *outOfDate = FALSE;
            StaleAfterEdit = TRUE;
        }
    }

    // a lock was removed ('wasEdit' = it was an edit lock); TRUE = the record must be marked out of
    // date now (the last edit lock went and a flush was deferred)
    BOOL OnLockRemoved(BOOL wasEdit)
    {
        if (!wasEdit)
            return FALSE;
        if (EditLocks > 0)
            EditLocks--;
        if (EditLocks == 0 && StaleAfterEdit)
        {
            StaleAfterEdit = FALSE;
            return TRUE;
        }
        return FALSE;
    }

    // the look-up's guard of the invariant: an out-of-date mark on a record with an edit lock (never
    // set by the code above) is turned into the deferred one; TRUE = the invariant was broken
    BOOL Normalize(BOOL* outOfDate)
    {
        if (*outOfDate && EditLocks > 0)
        {
            *outOfDate = FALSE;
            StaleAfterEdit = TRUE;
            return TRUE;
        }
        if (StaleAfterEdit && EditLocks == 0) // cannot happen either: the mark would have been lost
        {
            StaleAfterEdit = FALSE;
            *outOfDate = TRUE;
            return TRUE;
        }
        return FALSE;
    }
};
