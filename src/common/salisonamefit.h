// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salisonamefit.h
//
// Which name an entry of an ISO 9660 volume is listed under, and how the
// entries the panel listing cannot take are reported (feature 328).
// Header-only, no globals; for the ISO plug-in (uniso, iso9660.cpp) and
// saltests.
//
// The panel listing takes a folder part of at most MAX_PATH - 5 bytes
// (sallistingname.h). The ISO plug-in cleared the whole listing and showed
// "Error" when it refused an entry; feature 326 listed a Rock Ridge volume
// whose names did not all fit under its ISO 9660 names as a whole. Now:
//
//   - an entry the listing refuses under every name it has is left out alone
//     (a folder with its subtree), and reported: CSalListingLeftOut keeps
//     the count and the first SAL_LISTING_LEFT_OUT_SHOWN whole paths; a
//     whole-image unpack of such a listing fails (the image is not deleted);
//   - a Rock Ridge file is listed under its Rock Ridge name when the listing
//     takes it, else under its ISO 9660 name (SalIsoPickFileName) - also when
//     its in-image path reaches MAX_PATH bytes: the core's Copy of a selected
//     folder then asks about it ("Name ... with full path is too long", a
//     skippable box counted from the panel's folder), but its name is kept
//     (review 3: a reach criterion renamed such files to 8.3 names);
//   - a Rock Ridge folder keeps its Rock Ridge name when its whole subtree
//     fits with Rock Ridge names, when that name is not longer than its ISO
//     9660 name, or when - counting its subtree with ISO 9660 names below -
//     it lists no fewer entries than the ISO 9660 name would
//     (SalIsoFolderKeepsRockRidge); the folders below decide again. The rule
//     of the listing is monotone in the length of the folder part, so every
//     folder lists at least as many entries as with ISO 9660 names below it:
//     the volume never holds fewer entries than 326's whole-volume ISO 9660
//     listing, and its shallow folders keep their Rock Ridge names.
//
// Feature 329: the plug-in's other readers (UDF, Xbox, HFS+, audio tracks)
// leave out and record a refused entry the same way. HFS+ lists its catalog
// record by record, a child under its parent's listed path - CSalLeftOutIds
// keeps the catalog IDs of left-out folders, so their contents are skipped
// rather than listed at the volume's root.
//
// Feature 349: CSalHfsFolderOrder - an HFS+ folder moved into a newer folder
// has its contents before its own record in the catalog; the listing takes
// the folders above a record first, so every entry lands in its own folder
// (and a left-out folder's subtree stays out) whatever the catalog order.
//
//*****************************************************************************

#include <stddef.h>
#include <string.h>

#include <algorithm>
#include <string>
#include <vector>

#include "sallistingname.h"

// SalIsoPickFileName results
#define SAL_ISO_NAME_LEFT_OUT 0   // the listing takes neither name
#define SAL_ISO_NAME_ROCK_RIDGE 1 // 'rr'
#define SAL_ISO_NAME_ISO9660 2    // 'iso'

// a file under 'path' ('pathLen' bytes): its Rock Ridge name 'rr' (NULL = the record has none) when the
// listing takes it, else its ISO 9660 name 'iso' (NULL = none), else left out
inline int SalIsoPickFileName(const char* path, size_t pathLen, const char* rr, const char* iso)
{
    if (rr != NULL && SalListingAcceptsFileU8(path, pathLen, rr, strlen(rr)))
        return SAL_ISO_NAME_ROCK_RIDGE;
    if (iso != NULL && SalListingAcceptsFileU8(path, pathLen, iso, strlen(iso)))
        return SAL_ISO_NAME_ISO9660;
    return SAL_ISO_NAME_LEFT_OUT;
}

// a Rock Ridge folder keeps its Rock Ridge name ('rrLen' bytes) rather than its ISO 9660 name ('isoLen'
// bytes): 'rrSubtreeFits' = the listing takes the folder and its whole subtree with Rock Ridge names;
// 'listedRr' / 'listedIso' = the entries the listing takes - the folder itself and its subtree with ISO
// 9660 names below - under each name (needed only when neither of the first two answers; a longer name
// never gives more)
inline bool SalIsoFolderKeepsRockRidge(bool rrSubtreeFits, size_t rrLen, size_t isoLen, size_t listedRr,
                                       size_t listedIso)
{
    return rrSubtreeFits || rrLen <= isoLen || listedRr >= listedIso;
}

// the whole paths a report names; more entries left out are shown as "..."
#define SAL_LISTING_LEFT_OUT_SHOWN 10

// the entries one listing left out
class CSalListingLeftOut
{
public:
    size_t Count;                   // entries the listing refused
    bool Incomplete;                // something is missing from the listing (also a refusal not counted)
    std::vector<std::string> Paths; // the first SAL_LISTING_LEFT_OUT_SHOWN in-image paths, whole

    CSalListingLeftOut() : Count(0), Incomplete(false) {}

    // 'name' under the listed folder part 'path' (leading '\' dropped; NULL or "" = the root)
    void Add(const char* path, const char* name)
    {
        Count++;
        Incomplete = true;
        if (Paths.size() >= SAL_LISTING_LEFT_OUT_SHOWN)
            return;
        try
        {
            std::string p;
            if (path != NULL)
            {
                while (*path == '\\')
                    path++;
                p = path;
            }
            if (!p.empty())
                p += '\\';
            p += name != NULL ? name : "";
            Paths.push_back(p);
        }
        catch (...)
        {
            // out of memory: counted, not named ("..." follows)
        }
    }

    // a refusal that is not the listing's rule (the listing is incomplete, nothing to name)
    void SetIncomplete() { Incomplete = true; }

    // 'errText', a blank line, the paths one per line, "..." when more were left out than are named
    std::string Text(const char* errText) const
    {
        std::string t = errText != NULL ? errText : "";
        if (!Paths.empty())
            t += "\n";
        for (size_t i = 0; i < Paths.size(); i++)
        {
            t += "\n";
            t += Paths[i];
        }
        if (Count > Paths.size())
            t += "\n...";
        return t;
    }
};

// CSalLeftOutIds::Under results
#define SAL_ISO_UNDER_LISTED 0
#define SAL_ISO_UNDER_SKIPPED 1
#define SAL_ISO_UNDER_NO_MEMORY 2

// feature 329: the catalog IDs of the folders a listing left out (HFS+: their contents are skipped)
class CSalLeftOutIds
{
public:
    // false = out of memory (the ID is not kept)
    bool Add(unsigned int id)
    {
        try
        {
            std::vector<unsigned int>::iterator it = std::lower_bound(Ids.begin(), Ids.end(), id);
            if (it == Ids.end() || *it != id)
                Ids.insert(it, id);
            return true;
        }
        catch (...)
        {
            return false;
        }
    }

    bool Has(unsigned int id) const { return std::binary_search(Ids.begin(), Ids.end(), id); }

    size_t Size() const { return Ids.size(); }

    // a catalog record under 'parentId' (a folder: its own ID 'folderId'), met after its parent's record:
    // SAL_ISO_UNDER_LISTED = not inside a left-out folder (the listing decides); SAL_ISO_UNDER_SKIPPED =
    // left out with its parent, not reported (a folder's ID is kept, so its contents follow);
    // SAL_ISO_UNDER_NO_MEMORY = inside, but a folder's ID could not be kept (its contents would land at
    // the volume's root - the caller ends the listing)
    int Under(unsigned int parentId, bool isFolder, unsigned int folderId)
    {
        if (Ids.empty() || !Has(parentId))
            return SAL_ISO_UNDER_LISTED;
        if (isFolder && !Add(folderId))
            return SAL_ISO_UNDER_NO_MEMORY;
        return SAL_ISO_UNDER_SKIPPED;
    }

private:
    std::vector<unsigned int> Ids; // sorted, unique
};

// CSalHfsFolderOrder::Pending results
#define SAL_HFS_PENDING_OK 0
#define SAL_HFS_PENDING_LOOP 1
#define SAL_HFS_PENDING_NO_MEMORY 2
// TN1150 kHFSFirstUserCatalogNodeID: the IDs below are reserved (1 the root's parent, 2 the root folder, ...)
#define SAL_HFS_FIRST_USER_ID 16

// Feature 349: the order in which an HFS+ listing takes its folder records. The catalog is sorted by the
// parent ID of each record (TN1150); a folder gets its ID when it is made and keeps it when it is moved,
// so a folder made first and moved (on a Mac) into a newer folder has a lower ID than its new parent - the
// records inside it come before its own record. The listing found each record's folder among the folders
// listed so far and put the rest at the volume's root (also the contents of a folder it then left out).
// Now the listing collects its folder records first (Add, Seal) and, before it takes a record, takes the
// folders above it that it has not taken yet (Pending), outermost first - each folder is listed or left
// out before anything inside it, whatever the catalog order. A walk that meets a folder twice is a loop of
// parents (a damaged catalog): none of its folders reaches the root.
class CSalHfsFolderOrder
{
public:
    // a folder record: its catalog ID, its parent's ID (both in host order), its record index (rising from
    // call to call); false = out of memory, or a record index not above the last one (nothing kept). An ID
    // below SAL_HFS_FIRST_USER_ID is reserved (TN1150: the root folder is 2) - never a folder made by a user,
    // so never moved: it is not kept (true) and a record under it has nothing pending (review 1: a damaged
    // folder record with ID 2 was taken before every record of the root and the whole volume landed in it)
    bool Add(unsigned int id, unsigned int parent, size_t record)
    {
        if (!Links.empty() && record <= Links.back().Record)
            return false;
        if (id < SAL_HFS_FIRST_USER_ID)
            return true;
        try
        {
            Link l = {id, parent, record, false, 0};
            Links.push_back(l);
            return true;
        }
        catch (...)
        {
            return false;
        }
    }

    // after the last Add; false = out of memory
    bool Seal()
    {
        try
        {
            ById.resize(Links.size());
            for (size_t i = 0; i < Links.size(); i++)
                ById[i] = i;
            const std::vector<Link>& links = Links;
            // by ID, then record (Links is in record order: a stable sort keeps it) - Find gives the
            // first record of an ID, as the listing's search of its listed folders did
            std::stable_sort(ById.begin(), ById.end(),
                             [&links](size_t a, size_t b) { return links[a].Id < links[b].Id; });
            return true;
        }
        catch (...)
        {
            return false;
        }
    }

    size_t Size() const { return Links.size(); }

    // the folder record 'record' was taken (listed, left out or skipped); a record not added is never taken
    bool IsTaken(size_t record) const
    {
        size_t i = AtRecord(record);
        return i != NONE && Links[i].Taken;
    }
    void Take(size_t record)
    {
        size_t i = AtRecord(record);
        if (i != NONE)
            Links[i].Taken = true;
    }

    // the folders above a record under 'parentId' not taken yet: SAL_HFS_PENDING_OK - 'out' = their records,
    // outermost first (empty: the parent is taken, or no folder of the table); SAL_HFS_PENDING_LOOP - the
    // walk met a folder twice: 'out' = the records of the walk, each once (none of them reaches the root);
    // SAL_HFS_PENDING_NO_MEMORY - 'out' empty. Iterative; each folder is met at most once per walk.
    int Pending(unsigned int parentId, std::vector<size_t>& out)
    {
        out.clear();
        if (++Walk == 0) // the stamps wrapped (2^32 walks): clear them
        {
            for (size_t i = 0; i < Links.size(); i++)
                Links[i].Stamp = 0;
            Walk = 1;
        }
        try
        {
            unsigned int cur = parentId;
            for (;;)
            {
                size_t i = Find(cur);
                if (i == NONE || Links[i].Taken)
                    break;
                if (Links[i].Stamp == Walk)
                    return SAL_HFS_PENDING_LOOP;
                Links[i].Stamp = Walk;
                out.push_back(Links[i].Record);
                cur = Links[i].Parent;
            }
            std::reverse(out.begin(), out.end());
            return SAL_HFS_PENDING_OK;
        }
        catch (...)
        {
            out.clear();
            return SAL_HFS_PENDING_NO_MEMORY;
        }
    }

private:
    struct Link
    {
        unsigned int Id;
        unsigned int Parent;
        size_t Record;
        bool Taken;
        unsigned int Stamp; // the walk that last met it
    };
    static const size_t NONE = (size_t)-1;

    std::vector<Link> Links;   // in record order
    std::vector<size_t> ById;  // indices into Links, by (Id, Record)
    unsigned int Walk = 0;     // the current walk's stamp

    size_t AtRecord(size_t record) const
    {
        size_t lo = 0, hi = Links.size();
        while (lo < hi)
        {
            size_t mid = lo + (hi - lo) / 2;
            if (Links[mid].Record < record)
                lo = mid + 1;
            else
                hi = mid;
        }
        return (lo < Links.size() && Links[lo].Record == record) ? lo : NONE;
    }

    // the first link of folder ID 'id' (needs Seal)
    size_t Find(unsigned int id) const
    {
        size_t lo = 0, hi = ById.size();
        while (lo < hi)
        {
            size_t mid = lo + (hi - lo) / 2;
            if (Links[ById[mid]].Id < id)
                lo = mid + 1;
            else
                hi = mid;
        }
        return (lo < ById.size() && Links[ById[lo]].Id == id) ? ById[lo] : NONE;
    }
};
