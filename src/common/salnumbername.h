// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salnumbername.h
//
// Numbered names for equal names in one list (feature 148). Header-only, no
// globals; saltests checks it. The Undelete plug-in uses it where deleted files
// of one name are restored together ("a.txt" twice -> "a (1).txt", "a (2).txt").
//
// The plug-in numbered every name of a group from 1 without looking at the other
// names of the list: two deleted "a.txt" and a deleted "a (1).txt" became
// "a (1).txt" twice, and restoring them asked to overwrite one with the other
// (Yes replaced the third file with the first one's content; every release).
// The numbers now skip every name the list will hold.
//
//   SalNumberedNameAlloc   the name with " (n)" - Undelete's rule: before an
//                          extension of exactly three characters, else at the end
//   SalPickNumberedNames   the new names of the items that need a number
//
//*****************************************************************************

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "salnameorder.h" // SalNameOrderCompareCI: equal = one name for the file system (092, 115)

// "name (n).ext" when the last dot is followed by exactly three characters, else "name (n)";
// malloc'ed, NULL on low memory (the rule of Undelete's AddNumberSuffix)
inline char* SalNumberedNameAlloc(const char* name, int n)
{
    size_t len = strlen(name);
    const char* ext = strrchr(name, '.');
    if (ext != NULL && (size_t)(ext - name) != len - 4)
        ext = NULL;
    char* ret = (char*)malloc(len + 32); // " (" + up to 11 digits + ")" + terminator
    if (ret == NULL)
        return NULL;
    if (ext == NULL)
        sprintf(ret, "%s (%d)", name, n);
    else
    {
        memcpy(ret, name, ext - name);
        sprintf(ret + (ext - name), " (%d)%s", n, ext);
    }
    return ret;
}

namespace SalNumberNameDetail
{
    inline int Cmp(const char* a, const char* b) { return SalNameOrderCompareCI(a, -1, b, -1); }

    inline int CmpPtr(const void* a, const void* b) { return Cmp(*(const char* const*)a, *(const char* const*)b); }

    // a sorted array of names (not owned)
    struct CSet
    {
        const char** Items;
        int Count;
        int Capacity;

        BOOL Has(const char* name) const
        {
            int lo = 0, hi = Count - 1;
            while (lo <= hi)
            {
                int mid = (lo + hi) / 2;
                int c = Cmp(Items[mid], name);
                if (c == 0)
                    return TRUE;
                if (c < 0)
                    lo = mid + 1;
                else
                    hi = mid - 1;
            }
            return FALSE;
        }
        // the first position whose item is not less than 'name' (binary search - review of 148: a
        // linear scan was quadratic for a large group, "x (10)" sorts before "x (2)")
        int LowerBound(const char* name) const
        {
            int lo = 0, hi = Count;
            while (lo < hi)
            {
                int mid = (lo + hi) / 2;
                if (Cmp(Items[mid], name) < 0)
                    lo = mid + 1;
                else
                    hi = mid;
            }
            return lo;
        }
        void Insert(const char* name) // Capacity is sized by the caller
        {
            int pos = LowerBound(name);
            memmove(Items + pos + 1, Items + pos, (Count - pos) * sizeof(Items[0]));
            Items[pos] = name;
            Count++;
        }
    };
} // namespace SalNumberNameDetail

// 'count' names; the items with renumber[i] TRUE get a new name in out[i] (malloc'ed; the others get
// NULL): SalNumberedNameAlloc(names[i], n) with the smallest n >= 1 whose result is none of the names
// the list will hold - the names of the items that keep theirs and the new names chosen before (in
// the items' order); "equal" is SalNameOrderCompareCI. FALSE on low memory: out[] is all NULL.
inline BOOL SalPickNumberedNames(int count, const char* const* names, const BOOL* renumber, char** out)
{
    using namespace SalNumberNameDetail;
    for (int i = 0; i < count; i++)
        out[i] = NULL;
    int nRenumber = 0;
    for (int i = 0; i < count; i++)
        if (renumber[i])
            nRenumber++;
    if (nRenumber == 0)
        return TRUE;

    CSet kept = {(const char**)malloc((count - nRenumber + 1) * sizeof(const char*)), 0, count - nRenumber};
    CSet chosen = {(const char**)malloc((nRenumber + 1) * sizeof(const char*)), 0, nRenumber};
    // the next number to try per original name (a group of N equal names tries N + skipped numbers in
    // all): the original names in a sorted set ('keys', binary search - review of 148: a linear search
    // over the groups was O(items x groups)) and their counters in 'nexts', parallel to it
    CSet keys = {(const char**)malloc((nRenumber + 1) * sizeof(const char*)), 0, nRenumber};
    int* nexts = (int*)malloc((nRenumber + 1) * sizeof(int));
    BOOL ok = kept.Items != NULL && chosen.Items != NULL && keys.Items != NULL && nexts != NULL;
    if (ok)
    {
        for (int i = 0; i < count; i++)
            if (!renumber[i])
                kept.Items[kept.Count++] = names[i];
        qsort(kept.Items, kept.Count, sizeof(kept.Items[0]), CmpPtr);

        for (int i = 0; ok && i < count; i++)
        {
            if (!renumber[i])
                continue;
            int k = keys.LowerBound(names[i]);
            if (k == keys.Count || Cmp(keys.Items[k], names[i]) != 0)
            {
                memmove(nexts + k + 1, nexts + k, (keys.Count - k) * sizeof(nexts[0]));
                nexts[k] = 1;
                keys.Insert(names[i]); // lands at k
            }
            for (int n = nexts[k];; n++)
            {
                char* cand = SalNumberedNameAlloc(names[i], n);
                if (cand == NULL)
                {
                    ok = FALSE;
                    break;
                }
                if (!kept.Has(cand) && !chosen.Has(cand))
                {
                    out[i] = cand;
                    chosen.Insert(cand);
                    nexts[k] = n + 1;
                    break;
                }
                free(cand);
                if (n == 0x7FFFFFFE)
                {
                    ok = FALSE; // not reachable with any real list
                    break;
                }
            }
        }
    }
    free(kept.Items);
    free(chosen.Items);
    free(keys.Items);
    free(nexts);
    if (!ok)
    {
        for (int i = 0; i < count; i++)
        {
            free(out[i]);
            out[i] = NULL;
        }
    }
    return ok;
}
