// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// paneltabs.h
//
// Panel tabs - the panel-side model (feature 078-panel-tabs).
//
// Each CFilesWindow owns a CPanelTabs: an ordered list of CPanelTab records
// plus the index of the active one. The panel itself is always the active
// tab; a background tab holds nothing open - it is the remembered view state
// (location text, view, sort, filter, cursor, selection, scroll, its own
// Back/Forward history). Switching tabs is an ordinary path change of the
// panel (CFilesWindow::SwitchToTab in paneltabs.cpp), so every command,
// dialog and plugin sees only the active tab. The pure rules (title, index
// arithmetic, record clamping) live in src/common/saltabs.h.
//
// Included from fileswnd.h after CTopIndexMem; relies on salamand.h (CNames,
// CPathHistory) and the common headers being available through precomp.h.
//

static_assert(SAL_TAB_FILTER_MAX == MAX_GROUPMASK, "SAL_TAB_FILTER_MAX must match CMaskGroup capacity");

class CPathHistory;

class CPanelTab : public CSalTabRecord
{
public:
    // session state (data-model.md section 2); never persisted
    char FocusName[SAL_FIND_NAME_U8]; // caret item name at leave time; empty = none
    int TopIndex;                     // list box top index at leave time; -1 = none
    int XOffset;                      // horizontal offset (detailed view) at leave time; 0 = none
    CNames Selection;                 // selected names at leave time (Sort()ed)
    CTopIndexMem TopIndexMem;         // parent-directory scroll memory
    BOOL UserWorkedOnThisPath;        // whether the leaving path enters the Working Directories list
    CPathHistory* PathHistory;        // this tab's Back/Forward history (owned)
    BOOL Visited;                     // FALSE for a record restored from the registry until first activated

    CPanelTab();
    explicit CPanelTab(const CSalTabRecord& rec);
    ~CPanelTab();

    // forgets cursor, selection, scroll and the "worked here" flag (a fresh tab)
    void ResetSession();

private:
    CPanelTab(const CPanelTab&);            // owns a history and names - never copied
    CPanelTab& operator=(const CPanelTab&); // dtto
};

class CPanelTabs
{
public:
    TIndirectArray<CPanelTab> Tabs; // in strip order; at least one entry
    int ActiveIndex;                // the tab the panel shows
    int ContextTabIndex;            // tab under the open context menu, -1 otherwise
    BOOL SwitchInProgress;          // re-entrancy latch for SwitchToTab

    CPanelTabs();
    ~CPanelTabs();

    int Count() { return Tabs.Count; }
    CPanelTab* At(int index) { return (index >= 0 && index < Tabs.Count) ? Tabs[index] : NULL; }
    CPanelTab* Active() { return At(ActiveIndex); }

    // inserts a new tab built from 'rec' after 'afterIndex' (-1 = append);
    // returns the new tab or NULL when out of memory
    CPanelTab* Add(const CSalTabRecord& rec, int afterIndex);

    // deletes tab 'index' (with its history) and fixes ActiveIndex per
    // SalTabsIndexAfterClose; the caller never removes the active tab without
    // having switched away first
    void Remove(int index);

    // reorders; ActiveIndex follows the moved tab
    void Move(int from, int to);
};
