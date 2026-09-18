// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// saltabs.h
//
// Panel tabs - the pure part (feature 078-panel-tabs).
//
// Each file panel can hold several tabs; a tab is the remembered view state
// of that panel (location, view, sort, filter, ...). The panel-facing model
// lives in src/paneltabs.h; this module holds what needs no window: the
// persisted record, the title derivation (spec FR-007) and the index rules
// of the tab list (close, cycle, move), so that saltests can cover them.
// All strings are UTF-8 (WTF-8 for names with unpaired surrogates).
//

// an archive path plus the path inside it, or "fsname:userpart" - the longest
// text CFilesWindow::GetGeneralPath() can produce (same bound as CTopIndexMem)
#define SAL_TAB_LOCATION_MAX (2 * SAL_MAX_PATH_UTF8)

// == MAX_GROUPMASK (src/plugins/shared/spl_gen.h), the capacity of the panel's
// CMaskGroup; paneltabs.h checks the equality with a static_assert
#define SAL_TAB_FILTER_MAX 1001

// the persisted part of a tab (data-model.md section 1)
struct CSalTabRecord
{
    char Location[SAL_TAB_LOCATION_MAX]; // external form, as the Change Directory dialog shows it; empty = invalid
    int ViewTemplateIndex;               // index into the view templates; >= 1 (0 = tree, unsupported)
    int SortType;                        // CSortType value (0 = by name)
    BOOL ReverseSort;
    BOOL FilterEnabled;
    char FilterMasks[SAL_TAB_FILTER_MAX]; // "*.*" when no filter was ever set
};

// empty location, detailed view (index 2), sort by name, "*.*", filter off
void SalTabRecordInit(CSalTabRecord* rec);

// brings a loaded record into range: sort into [0, maxSortType] (else 0), view
// index < 1 -> 2 (detailed); returns FALSE when the record must be dropped
// (empty location)
BOOL SalTabRecordClamp(CSalTabRecord* rec, int maxSortType);

// the tab title for a location (spec FR-007): the last path component after a
// trailing separator is dropped; a drive root ("C:\") and a UNC root
// ("\\server\share") are returned whole; for "fsname:userpart" the last
// component of the user part, or the whole user part when it is a root
// ("ftp://user@server"). Never splits a UTF-8 sequence; 'titleSize' includes
// the terminator.
void SalTabTitleFromLocation(const char* location, char* title, int titleSize);

// the active index after tab 'closed' is removed from a list of 'count' tabs:
// a tab left of the active one shifts it down; closing the active tab makes
// its right neighbour active, or the left one when there is none (spec FR-017)
int SalTabsIndexAfterClose(int count, int closed, int active);

// next (forward) or previous tab with wrap-around
int SalTabsCycle(int count, int active, BOOL forward);

// moves tab 'from' so that it lands at index 'to'; '*active' follows the
// moved tab or shifts with the others
void SalTabsMove(int count, int from, int to, int* active);
