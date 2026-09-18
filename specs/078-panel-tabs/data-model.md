# Data Model: Panel Tabs

**Feature**: 078 · **Date**: 2026-09-18 · **Spec**: [spec.md](spec.md) ·
**Research**: [research.md](research.md) · **Contracts**: [contracts/](contracts/)

Four entities: the persisted **tab record**, the in-memory **tab** (record +
session state), the per-panel **tab set**, and the global **option**. The
panel itself (`CFilesWindow`) is unchanged as an entity: at every moment it
*is* the active tab of its side (spec FR-022).

## 1. Tab record (persisted) — `CSalTabRecord`, `src/common/saltabs.h`

Plain data, no owned resources; assignable; the unit-tested part.

| Field | Type | Registry value | Meaning / rule |
|---|---|---|---|
| `Location` | `char[2 * SAL_MAX_PATH_UTF8]`, UTF-8 (WTF-8) | `Path` (REG_SZ) | The location as the Change Directory dialog would show it: disk path, `archive\inside`, or `fsname:userpart` in the plugin's **external** form (research R2). Never a password. Empty = invalid record. |
| `ViewTemplateIndex` | `int` | `View Type` (REG_DWORD) | Index into `MainWindow->ViewTemplates`; must be ≥ 1; validated with `IsViewTemplateValid` at apply time (a blanked template falls back to Detailed, index 2, as `SelectViewTemplate` does). |
| `SortType` | `int` (`CSortType`) | `Sort Type` (REG_DWORD) | Clamped to `[stName, stAttr]` on load (the `LoadPanelConfig` rule). |
| `ReverseSort` | `BOOL` | `Reverse Sort` (REG_DWORD) | |
| `FilterEnabled` | `BOOL` | `Enable Filter` (REG_DWORD) | |
| `FilterMasks` | `char[MAX_GROUPMASK]`, UTF-8 | `Filter` (REG_SZ) | Applied with `SetMasksString` + `PrepareMasks`; an unparsable mask falls back to `*.*` (the `LoadPanelConfig` rule). |

**Derived**: `Title` = `SalTabTitleFromLocation(Location)` (spec FR-007):
trailing separator removed; the last `\` or `/` component; a drive root
(`C:\`) and a UNC root (`\\server\share`) are returned whole; for
`fsname:userpart` the last component of the user part, or the whole user part
when it has no component (e.g. `ftp://user@server`). Titles are for display
only and are never stored.

## 2. Tab (in memory) — `CPanelTab`, `src/paneltabs.h`

`CPanelTab` = `CSalTabRecord` + session state. Owned by the tab set; never
copied (it owns a `CPathHistory` and a `CNames`, neither of which has copy
semantics).

| Field | Type | Meaning |
|---|---|---|
| `FocusName` | `char[SAL_FIND_NAME_U8]` | Name of the item the caret was on (`GetCaretIndex()`); empty = none. |
| `TopIndex` | `int` | List box top index at leave time; `-1` = none. |
| `XOffset` | `int` | Horizontal offset (Detailed view) at leave time; `0` = none. |
| `Selection` | `CNames` | Names of selected items at leave time, `Sort()`ed, case sensitivity per the location's panel type (`IsCaseSensitive()`). |
| `TopIndexMem` | `CTopIndexMem` | The parent-directory scroll memory (plain arrays, copied both ways; `ChangeDir` clears the panel's, so it is restored *after* the switch). |
| `UserWorkedOnThisPath` | `BOOL` | Whether the leaving path enters the global *List of Working Directories* (`CloseCurrentPath`, `fileswn2.cpp:1428-1434`). |
| `PathHistory` | `CPathHistory*` (owned) | The tab's Back/Forward history; the panel's `PathHistory` pointer is swapped to the active tab's object. Freed with the tab. |
| `Visited` | `BOOL` | `FALSE` for a record restored from the registry until it is first activated (lazy open, spec FR-028); `TRUE` otherwise. |

**Not carried** (per visit, as today): `HiddenNames`, `OldSelection`
(research R3).

## 3. Tab set (per panel) — `CPanelTabs`, `src/paneltabs.h`

| Field | Type | Rule |
|---|---|---|
| `Tabs` | `TIndirectArray<CPanelTab>` | Ordered as shown in the strip; **at least one entry** while the option is on. |
| `ActiveIndex` | `int` | `0 ≤ ActiveIndex < Tabs.Count`; the panel shows this tab. |
| `ContextTabIndex` | `int` | Tab under the right-click menu while it is open; `-1` otherwise (research R10). |
| `SwitchInProgress` | `BOOL` | Re-entrancy latch for `SwitchToTab` (research R4). |

Owned by `CFilesWindow` (member), so *Swap Panels* exchanges the two sets
with the two panel pointers (`mainwnd3.cpp:4312-4350`) and nothing else is
needed.

**Operations** (pure index rules in `src/common/saltabs.h`, tested):

| Operation | Rule |
|---|---|
| `Add(record, afterIndex)` | Insert after `afterIndex` (`-1` = append). New Tab appends; Duplicate inserts after the original (FR-016). |
| `IndexAfterClose(count, closed, active)` | Closing a background tab: `active` shifts down when `closed < active`. Closing the active tab: the tab to its right becomes active, or the left one when there is none (FR-017). |
| `Cycle(count, active, forward)` | Next/Previous wrap around (US4-2). |
| `Move(count, from, to, &active)` | Reorder; `active` follows the moved record (US5-3). |
| `CloseOthers(active)` / `CloseRight(active)` | Remove background records only. |
| `Clamp(record)` | Sort into range; view index ≥ 1; empty location → reject record. |

**Invariants**

- The panel's current view/sort/filter/location are *authoritative* for the
  active tab; the active record is refreshed from the panel at every snapshot
  (switch, save, option change), never the other way round while it is active.
- Two tabs may hold the same location (spec Edge Cases). Two tabs on the same
  plugin-file-system path resolve to the same single interface; whichever is
  active owns it (research R15).
- The last tab of a panel cannot be closed (FR-012).

## 4. State transitions of a tab

```
                 +----------------+   first SwitchToTab (ChangeDir of Location)   +--------+
restored from -->|  Unvisited     |----------------------------------------------->| Active |
registry         | (record only)  |                                                +--------+
                 +----------------+                                                   |  ^
                                                                                      |  |
 New Tab / Duplicate / middle click --> +------------+  SwitchToTab (other tab)       |  |  SwitchToTab (this tab)
 (record + fresh session state)         | Background |<-------------------------------+  |
                                        +------------+---------------------------------+
                                              |
                                              | Close (any) / Close Others / Close Right / option turned off
                                              v
                                         (deleted; history freed; nothing else touched)
```

- **Active → Background** = the panel leaves the location exactly as when
  navigating away today (archive closed with its prompts; plugin FS closed or
  detached by the plugin's rule). A refusal keeps the tab Active and the panel
  intact (FR-020).
- **Background → Active** = `ChangeDir(Location)`: the listing is re-read; a
  detached FS is re-attached by path; an unreachable location falls back
  (FR-021) and the record's `Location` is re-captured from the panel.
- **Closing the Active tab** = first make a neighbour Active (may be refused
  → the tab stays), then delete.

## 5. Option — `Configuration.PanelTabs`

| Field | Type | Registry | Default | Meaning |
|---|---|---|---|---|
| `PanelTabs` | `int` | `Configuration\Panel Tabs` (REG_DWORD) | `TRUE` | Tab strips shown, tab commands offered, tab shortcuts active. Missing value keeps the default (no `THIS_CONFIG_VERSION` bump). |

**Lifecycle**: constructor default → `LoadConfig` → Appearance page
`Transfer` / `Validate` (the FR-005 confirmation when clearing with extra
tabs open) → post-OK `SetTabsEnabled` on both panels → `SaveConfig`.

## 6. Registry layout (per side)

```
HKCU\Software\Tandem Commander\0.1\
  Configuration\
    Panel Tabs              REG_DWORD   1 | 0
  Left Panel\                            (same under Right Panel)
    Path, View Type, Sort Type, Reverse Sort, Directory Line, Status Line,
    Header Line, Enable Filter, Filter    <- unchanged; describe the ACTIVE tab
    Active Tab              REG_DWORD   index into Tabs (absent -> 0; clamped)
    Tabs\
      0\  Path, View Type, Sort Type, Reverse Sort, Enable Filter, Filter
      1\  ...
```

Rules (research R14): written only by `SaveConfig`; `Tabs` is emptied
(`ClearKey`) and rewritten so no stale entry survives; read only inside the
existing `Path` gate of `LoadPanelConfig`; absent or empty `Tabs` → one
record from the legacy values; records that fail `Clamp` are dropped;
`Active Tab` clamped to the surviving count. The legacy `Path` keeps today's
disk-only rule, so an older build and the option-off state read the panel
exactly as before (FR-029). Export/Import carries the subkey automatically.
