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

//*****************************************************************************
//
// feature 312: the tab key table, Reopen Closed Tab, the Tabs configuration page
//
// One table of keys (contract specs/312-tabs-browser-keys/contracts/tab-keys.md)
// serves the key dispatch of the panel and the command line, the key shown in
// menu labels and tooltips, and the list on Configuration > Tabs. The classic
// mode is the 0.1.10 behaviour; the browser-like mode (an opt-in option) is in
// effect only while tabs are on.
//

enum CSalTabKeyAction
{
    stkaNone = 0,      // not a key of the table / no action
    stkaNewTab,        // New Tab
    stkaCloseTab,      // Close Tab
    stkaNextTab,       // Next Tab
    stkaPrevTab,       // Previous Tab
    stkaReopenTab,     // Reopen Closed Tab
    stkaRestoreSel,    // Restore Selection
    stkaGoToShortcut,  // Go to Shortcut or Link Target
    stkaEnterFocused,  // go into the focused folder or archive (classic Ctrl+Page Down)
    stkaParentDir,     // go to the parent folder (classic Ctrl+Page Up)
    stkaCommandLine,   // go to the command line (Ctrl+Tab)
};

// modifier bits of a table key (Alt is never part of a row)
#define SAL_TABKEY_CTRL 0x01
#define SAL_TABKEY_SHIFT 0x02
#define SAL_TABKEY_ALT 0x04

struct CSalTabKeyRow
{
    int Vk;     // virtual key; 0 = no key (the "Reopen Closed Tab" row of the classic mode)
    int Mods;   // SAL_TABKEY_* bits
    int Action; // CSalTabKeyAction in the mode the row was produced for
};

// the browser-like mode is in effect: tabs on and the option on
BOOL SalTabKeysBrowserLike(BOOL tabsOn, BOOL optionOn);

// what the key does in the mode (stkaNone for a key outside the table or with Alt)
int SalTabKeyMeaning(int vk, int mods, BOOL browserLike);

// the action the tab code runs for the key in the mode, or stkaNone when the
// existing handling of the key continues (keys outside the table, keys whose
// meaning is their classic non-tab meaning, Ctrl+Tab, anything with Alt); call
// only while tabs are on
int SalTabKeyDispatch(int vk, int mods, BOOL browserLike);

// the rows of the list on the Tabs page for the mode, in display order; returns
// the number of rows written (at most 'max')
int SalTabKeyRows(BOOL browserLike, CSalTabKeyRow* rows, int max);

// the key shown for an action in the mode (the first row whose action it is);
// FALSE when the action has no key in that mode
BOOL SalTabKeyForAction(int action, BOOL browserLike, int* vk, int* mods);

// "Ctrl+Shift+Page Down" (the English 078 form used in the menu strings of all
// languages); empty for vk == 0; 'size' includes the terminator; FALSE when it
// does not fit (out is then empty)
BOOL SalTabKeyText(int vk, int mods, char* out, int size);

// a label with its key part replaced by 'keyText' (empty = no key):
// "Text\tKey" -> "Text\t<keyText>" (or "Text"); "Text (Key)" -> "Text (<keyText>)"
// (or "Text"); "Text" -> "Text\t<keyText>" (or "Text"). FALSE when the result
// does not fit 'size' (out is then empty and the caller keeps the original label)
BOOL SalTabLabelWithKey(const char* label, const char* keyText, char* out, int size);

// the most closed tabs a panel remembers for Reopen Closed Tab
#define SAL_TABS_CLOSED_MAX 10

// where a reopened tab goes: its old index, at most the current count (= append)
int SalTabsReopenIndex(int count, int closedIndex);

// Configuration > Tabs is page 7 (after Appearance); a remembered page index
// written before feature 312 is moved past it
int SalCfgPageIndexFrom311(int index);
