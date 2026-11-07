// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// The sort of the Find window's result list (feature 407, GitHub #23)
//
// The list sorted every request ascending and remembered nothing, so a second
// click on the same column header "did nothing". Now the list remembers the
// sorted column and the direction, as the panel does:
//
// SalFindSortColumnAllowed - can the column sort the list? Attributes never;
//                     in the duplicate-search mode Path, Date and Time never,
//                     Name and Size only when the search was by both name and
//                     size (the old guards of SortItems and the View menu).
// SalFindSortNext   - the state after a request on 'column': another column
//                     (or none sorted yet) starts ascending; the same column is
//                     reversed when 'toggle' (every user request: a header
//                     click, the View menu, Ctrl+F3..F6), else ascending (an
//                     internal sort: Hide duplicate names).
// SalFindSortNextKey - the tie-break chain of the comparison: after the sorted
//                     column come Name, Path, Size, Date in this order without
//                     the sorted one; the chain ends after Date (key 3).
// SalFindSortOrder  - the final comparison of two items: folders before files
//                     in both directions (the panel's rule); within a group the
//                     column result 'columnRes' (with its tie-breaks), negated
//                     when descending - the exact reverse of the ascending order.
// SalFindSortDirected - a whole comparison result in the given direction (the
//                     duplicates key name/size/group reversed as a whole keeps
//                     each duplicate group together).
// SalFindSortGroupedDirected - the Registry Editor's Find window: the same
//                     toggle, keys kept before values where its own ascending
//                     order groups them (every column but Path).
// SalFindSortHeaderFormat - the header item format of 'headerColumn': the sort
//                     arrow bits cleared, then the up / down arrow set on the
//                     sorted column only.
//
//*****************************************************************************

// the columns of the result list
#define SAL_FIND_COL_NAME 0
#define SAL_FIND_COL_PATH 1
#define SAL_FIND_COL_SIZE 2
#define SAL_FIND_COL_DATE 3
#define SAL_FIND_COL_TIME 4
#define SAL_FIND_COL_ATTR 5

#define SAL_FIND_SORT_NONE (-1) // no column sorted (search order)

// the header sort arrows (commctrl.h HDF_SORTUP / HDF_SORTDOWN, comctl32 v6)
#define SAL_FIND_HDF_SORTUP 0x0400
#define SAL_FIND_HDF_SORTDOWN 0x0200

struct CSalFindSortState
{
    int Column;      // SAL_FIND_COL_NAME..SAL_FIND_COL_TIME or SAL_FIND_SORT_NONE
    bool Descending; // false whenever Column is SAL_FIND_SORT_NONE
};

inline CSalFindSortState SalFindSortNone()
{
    CSalFindSortState s;
    s.Column = SAL_FIND_SORT_NONE;
    s.Descending = false;
    return s;
}

inline bool SalFindSortColumnAllowed(int column, bool findDuplicates, bool dupByNameAndSize)
{
    if (column < SAL_FIND_COL_NAME || column > SAL_FIND_COL_TIME)
        return false; // attributes (and anything unknown) cannot sort
    if (!findDuplicates)
        return true;
    if (column == SAL_FIND_COL_NAME || column == SAL_FIND_COL_SIZE)
        return dupByNameAndSize;
    return false; // path, date and time are irrelevant for duplicates
}

inline CSalFindSortState SalFindSortNext(CSalFindSortState prev, int column, bool toggle)
{
    CSalFindSortState s;
    s.Column = column;
    s.Descending = toggle && prev.Column == column ? !prev.Descending : false;
    return s;
}

// the key compared after 'key' when sorting by 'sortBy'; the chain goes on while
// the result is equal and the returned key is <= SAL_FIND_COL_DATE
inline int SalFindSortNextKey(int key, int sortBy)
{
    if (key == sortBy)
        return sortBy != SAL_FIND_COL_NAME ? SAL_FIND_COL_NAME : SAL_FIND_COL_PATH;
    if (key + 1 != sortBy)
        return key + 1;
    return key + 2;
}

inline int SalFindSortOrder(bool isDir1, bool isDir2, int columnRes, bool descending)
{
    if (isDir1 != isDir2)
        return isDir1 ? -1 : 1; // folders first in both directions
    if (columnRes == 0)
        return 0;
    if (descending)
        return columnRes < 0 ? 1 : -1;
    return columnRes < 0 ? -1 : 1;
}

inline int SalFindSortDirected(int res, bool descending)
{
    if (res == 0)
        return 0;
    if (descending)
        return res < 0 ? 1 : -1;
    return res < 0 ? -1 : 1;
}

// the Registry Editor's Find (feature 407): its ascending comparison 'ascendingRes' groups keys
// before values for every column but Path ('columnGroups'); in the descending direction the keys
// stay first where the ascending order grouped them ('groupsDiffer' = one is a key, the other a
// value), every other result is reversed
inline int SalFindSortGroupedDirected(int ascendingRes, bool groupsDiffer, bool columnGroups, bool descending)
{
    if (groupsDiffer && columnGroups)
        return SalFindSortDirected(ascendingRes, false);
    return SalFindSortDirected(ascendingRes, descending);
}

inline int SalFindSortHeaderFormat(int fmt, int headerColumn, CSalFindSortState state)
{
    fmt &= ~(SAL_FIND_HDF_SORTUP | SAL_FIND_HDF_SORTDOWN);
    if (state.Column != SAL_FIND_SORT_NONE && headerColumn == state.Column)
        fmt |= state.Descending ? SAL_FIND_HDF_SORTDOWN : SAL_FIND_HDF_SORTUP;
    return fmt;
}
