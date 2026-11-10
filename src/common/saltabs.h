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

//*****************************************************************************
//
// feature 404: the variant F tab strip - colours, metrics, live drag, the
// other-panel menu items and the location kind of a tab's icon
//

// a + (b - a) * t per channel, rounded half to even as the mockup (TabMock.cs,
// Math.Round) - colours are COLORREF (0x00BBGGRR)
DWORD SalTabMix(DWORD a, DWORD b, double t);

struct CSalTabStripColors
{
    DWORD StripBk;   // the strip background
    DWORD DimText;   // the title of an inactive tab and the plus glyph
    DWORD HoverBk;   // the hover pill of an inactive tab and the plus circle
    DWORD HoverText; // the title of a hovered inactive tab and the hovered plus glyph
    DWORD Separator; // the line between two plain tabs
};

// the strip colours from the system colours of the theme (face, shadow, highlight
// = COLOR_BTNHIGHLIGHT, text = COLOR_BTNTEXT); 'hcHighlight' / 'hcHighlightText'
// (COLOR_HIGHLIGHT / COLOR_HIGHLIGHTTEXT) are used only under High Contrast, where
// nothing is mixed. DimText is the text mixed toward the strip by SALTAB_DIMTEXT_LIGHT
// (Light) / SALTAB_DIMTEXT_DARK (Dark)
void SalTabStripColorsGet(DWORD face, DWORD shadow, DWORD highlight, DWORD text, BOOL dark,
                          BOOL highContrast, DWORD hcHighlight, DWORD hcHighlightText,
                          CSalTabStripColors* out);

// feature 423: the Light theme's inactive titles were 545454 on DEDEDE (0.38, 5.63:1, washed
// out next to the black active title); 0.20 gives 2C2C2C (10.38:1), still a step lighter than
// the active / hovered title. Dark keeps 404's 0.30
#define SALTAB_DIMTEXT_LIGHT 0.20
#define SALTAB_DIMTEXT_DARK 0.30

// feature 423: the panel tab style (Configuration > Appearance > Tab style), stored as
// "Panel Tab Style" (REG_DWORD) in the configuration key
#define SALTAB_STYLE_SQUARE 0  // the default: the active tab and the hover are plain rectangles
#define SALTAB_STYLE_ROUNDED 1 // the look of feature 404: rounded top corners, outward feet, a hover pill

// the style for a stored value: 'read' FALSE (missing or of another type) or a number this
// version does not know -> Square (the number itself is kept by the caller and written back)
int SalTabStyleFromStored(BOOL read, unsigned long value);

// the close glyph over background 'bk' with foreground 'fg': the cross when not
// hovered (fg 25 % toward bk) and the hover circle (bk 14 % / Dark 20 % toward fg);
// under High Contrast the cross is fg
void SalTabCloseColors(DWORD bk, DWORD fg, BOOL dark, BOOL highContrast, DWORD* cross, DWORD* circle);

// MulDiv(px, scalePercent, 100) for the strip metrics
int SalTabScaled(int px, int scalePercent);

// the strip height: 2 + font height + 2 + 10 (scaled) - 29 px at 96 DPI with Segoe UI 9 pt
int SalTabStripHeight(int fontHeight, int scalePercent);

// the width limits of a tab: 6 / 20 average characters + 2 x 10 + 8 + 6 (scaled) + the icon
void SalTabStripWidths(int avgCharWidth, int scalePercent, int iconSize, int* minWidth, int* maxWidth);

// the slot a dragged tab takes (live reorder): 'draggedLeft' is its drawn left
// relative to the left of the run, 'from' its index in the run of 'count' equal
// tabs of 'tabWidth'; a neighbour gives way once the dragged tab's centre reaches
// the neighbour's centre: moving right tab j gives way once 'draggedLeft' is at or
// above j * tabWidth, moving left once it is at or below j * tabWidth - so both ends
// of the run are reachable with the left clamped to 0 .. (count - 1) * tabWidth
// (feature 413: "below" made the first place unreachable). Result in [0, count - 1]
int SalTabDragSlot(int count, int tabWidth, int draggedLeft, int from);

// the minimum separation (largest channel difference) of the active tab's fill from
// the strip background and from the face colour (the directory line's band under the
// tab); the default theme's weakest pair is 31 (feature 413)
#define SALTAB_ACTIVE_MIN_CONTRAST 24

// the largest of the three channel differences of two colours
int SalTabColorDistance(DWORD a, DWORD b);

// the active tab's fill: the caption background 'capBk', or - when it is closer than
// SALTAB_ACTIVE_MIN_CONTRAST to 'stripBk' or to 'face' (the Dark theme's inactive
// panel: 45,45,45 on 36,36,36 over 45,45,45) - 'capBk' mixed toward the caption text
// colour 'capFg' by the smallest k / 100 (k <= 50) that separates it from both, else
// the step (k = 0 included) that separates it best, the smallest on a tie; never mixed
// under High Contrast (feature 413)
DWORD SalTabActiveFill(DWORD capBk, DWORD capFg, DWORD stripBk, DWORD face, BOOL highContrast);

// the WCAG 2 contrast ratio of two colours (1..21)
double SalTabContrastRatio(DWORD a, DWORD b);

// the active tab's title colour on 'fill' (from SalTabActiveFill): 'capFg' when the fill is
// the caption colour 'capBk' or when 'capFg' keeps on the fill the contrast it has on 'capBk'
// (at most 4.5:1 is asked); else 'capFg' mixed toward white (a fill darker than the title) or
// black by the smallest k / 100 that gives that contrast - toward the other pole when that one
// cannot, the better pole itself when neither can (feature 413: AAAAAA on the lifted
// 454545 was 4.13:1)
DWORD SalTabActiveText(DWORD capFg, DWORD capBk, DWORD fill);

// where tab 'index' is shown while tab 'from' is dragged to slot 'slot' (the
// order after the release is SalTabsMove(from, slot)); a cancel is slot == from
int SalTabDragPosition(int from, int slot, int index);

// ease-out progress (1 - (1 - t)^3) in 0..1000 after 'elapsedMs' of 'durationMs'
int SalTabEaseOut(int elapsedMs, int durationMs);

// Move to Other Panel: on a tab, this panel has more than one tab, the other panel shows tabs
BOOL SalTabMenuCanMoveToOther(BOOL onTab, int count, BOOL otherShowsTabs);

// New Tab as Other Panel: the other panel has a location to give
BOOL SalTabMenuCanNewAsOther(BOOL otherHasLocation);

// feature 405: after a press on a tab switched the panel, may the strip arm a drag (and take the
// capture)? 'downAtPress' / 'downAfterSwitch' = the left button's synchronous state (GetKeyState)
// when the press was handled / when the switch returned. FALSE only when the button was held at the
// press and is no longer held: a window of the switch (the FTP leave question, an error box) took the
// button-up. A press without a recorded button state (a posted message) arms as before
BOOL SalTabArmDragAfterSwitch(BOOL downAtPress, BOOL downAfterSwitch);

// the kind of a tab's location for its icon
#define SAL_TAB_KIND_UNKNOWN -1 // not derived yet
#define SAL_TAB_KIND_FOLDER 0
#define SAL_TAB_KIND_DRIVE 1    // "X:\" (or "X:")
#define SAL_TAB_KIND_UNC 2      // "\\server\share" (or with a trailing backslash)
#define SAL_TAB_KIND_ARCHIVE 3  // known only from the panel (never from the text)
#define SAL_TAB_KIND_PLUGINFS 4 // "fsname:..." - the caller confirms the file system name

// the kind from the location text alone (no file system access); a "name:"
// prefix of two or more letters, digits, '_', '-' or '.' gives SAL_TAB_KIND_PLUGINFS
// and its length in '*fsNameLen' (0 otherwise)
int SalTabLocationKind(const char* location, int* fsNameLen);

// Move to Other Panel: did the other panel open the moved location (TRUE), or fall back to
// another place (FALSE - the move is undone)? The same place by SalPathEqualOrdinalCI (ordinal
// case-insensitive, a leading / trailing backslash does not matter); NULL -> FALSE
BOOL SalTabLocationsSame(const char* a, const char* b);
