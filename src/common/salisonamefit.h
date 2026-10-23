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

private:
    std::vector<unsigned int> Ids; // sorted, unique
};
