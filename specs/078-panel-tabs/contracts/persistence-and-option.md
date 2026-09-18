# Contract: persistence, the option and the Configuration page

**Feature**: 078 · **Research**: R12, R14, R19 · **Spec**: FR-001–FR-005,
FR-027–FR-029, Clarifications Q1, Q5

## 1. Option `Panel Tabs`

| Item | Value |
|---|---|
| Field | `int CConfiguration::PanelTabs` (`src/cfgdlg.h`, next to `ShowPanelCaption`) |
| Default | `TRUE` (`CConfiguration::CConfiguration()`, `src/dialogs4.cpp`) |
| Registry | `HKCU\Software\Tandem Commander\0.1\Configuration\Panel Tabs`, REG_DWORD; name constant `CONFIG_PANELTABS_REG = "Panel Tabs"` (`src/mainwnd2.cpp` table) |
| Save / load | next to `CONFIG_SHOWPANELCAPTION_REG` (`src/mainwnd2.cpp:1630` / `:3170`); a missing value keeps the default — **no `THIS_CONFIG_VERSION` bump** |
| Export | automatic (branch dump; the name does not end in `.hidden`) |

Effect: on → strips exist, tab commands offered, tab shortcuts active; off →
none of the three (FR-003).

## 2. Configuration page (Appearance, `IDD_CFGPAGE_APPEARANCE`)

- Control: `CONTROL "Show ta&bs in panels",IDC_PANELTABS,"Button",BS_AUTOCHECKBOX | WS_TABSTOP,1,75,169,12`
  in the free row between `IDC_PANELZOOM` (y=63) and the Panel Font group
  (y=81); id `IDC_PANELTABS = 6235`, `_APS_NEXT_CONTROL_VALUE` → 6236
  (`src/lang/lang.rh:711`). Accelerator `b`: the page already uses
  `r h c S p m F o T` (`&Thumbnails` takes `T`, so `&tabs` would collide);
  the translation merge re-checks uniqueness per language.
- `CCfgPageAppearance::Transfer`: `ti.CheckBox(IDC_PANELTABS, Configuration.PanelTabs);`
- `CCfgPageAppearance::Validate` (FR-005): when the checkbox is unchecked
  **and** `Configuration.PanelTabs` is currently on **and**
  `LeftPanel->Tabs.Count + RightPanel->Tabs.Count > 2`, show
  `SalMessageBox(HWindow, <IDS_TABS_CLOSECONFIRM with the number of tabs that will close>, LoadStr(IDS_QUESTION), MB_YESNO | MB_ICONQUESTION)`;
  on *No*: `ti.ErrorOn(IDC_PANELTABS)` (the dialog stays open, the checkbox
  keeps focus). Composed with a `LoadStrU8` template (encoding guard).
- Post-OK (`WM_USER_CONFIGURATION`, `src/mainwnd3.cpp:1949-2034`): snapshot
  `BOOL oldPanelTabs = Configuration.PanelTabs;` before the dialog; after
  `IDOK`, if changed:
  `LockWindowUpdate(HWindow); LeftPanel->SetTabsEnabled(Configuration.PanelTabs); RightPanel->SetTabsEnabled(...); LayoutWindows(); LockWindowUpdate(NULL);`
  — immediate, no restart (FR-001).

## 3. `CFilesWindow::SetTabsEnabled(BOOL on)`

| on | Behaviour |
|---|---|
| `TRUE` | Ensure the tab set has ≥ 1 record (capture from the panel if empty); create the strip (`ToggleTabStrip`). |
| `FALSE` | Delete every record except the active one (histories freed; nothing else touched — a detached plugin connection stays listed as today); destroy the strip. |

Idempotent; called from `WM_CREATE` (after `LoadConfig` has run — i.e. from
the start-up sequence once the option is known), from the post-OK handler,
and never from plugins.

## 4. Per-panel persistence (`Left Panel` / `Right Panel`)

```
<side key>\
  Path, View Type, Sort Type, Reverse Sort, Directory Line, Status Line,
  Header Line, Enable Filter, Filter         <- unchanged (active tab; Path = GetPath(), disk)
  Active Tab                REG_DWORD        <- index into Tabs; absent -> 0
  Tabs\<n>\Path             REG_SZ (UTF-8)   <- CSalTabRecord.Location (external form)
  Tabs\<n>\View Type        REG_DWORD
  Tabs\<n>\Sort Type        REG_DWORD
  Tabs\<n>\Reverse Sort     REG_DWORD
  Tabs\<n>\Enable Filter    REG_DWORD
  Tabs\<n>\Filter           REG_SZ (UTF-8)
```

**Writer** — `CMainWindow::SavePanelConfig` (`src/mainwnd2.cpp:1193`):

1. Refresh the active record from the panel (`CaptureActiveTab()`).
2. Write the legacy values exactly as today.
3. `CreateKey(actKey, "Tabs", tabsKey)`; `ClearKey(tabsKey)`; for each record
   `CreateKey(tabsKey, "<n>", k)` + six `SetValue`s (`REG_SZ` with `-1`
   length → UTF-8 through the W8 facade); `CloseKey`.
4. `SetValue(actKey, "Active Tab", REG_DWORD, …)`.

Called only from `SaveConfig` (*Save configuration on exit*, *Save
Configuration*, the export prompt) — never on a tab change (Clarification Q5).
With the option off the list has exactly one record.

**Reader** — `CMainWindow::LoadPanelConfig` (`src/mainwnd2.cpp:2242`), inside
the existing `if (GetValue(actKey, PANEL_PATH_REG, …))` gate:

1. Legacy values as today (they configure the panel and become record 0's
   view/sort/filter).
2. If `OpenKey(actKey, "Tabs", tabsKey)`: read `0`, `1`, … until a missing
   subkey; each record passes `SalTabRecordClamp` or is dropped (empty
   `Path`, sort out of range, view index < 1).
3. If the result is empty → one record from the legacy values.
4. `Active Tab` read and clamped to `[0, count-1]`.
5. Records other than the active one are `Visited = FALSE`; the active
   record's `Location` is **overwritten from the panel after the start-up
   listing** (the existing code at `src/mainwnd2.cpp:3897-3926` still applies
   the legacy disk `Path`, and command-line `-l/-r/-a` still win).

**Compatibility** (FR-029): an older build ignores `Tabs`/`Active Tab` and
reads the panel exactly as before; a configuration without them yields one
tab per panel; `THIS_CONFIG_VERSION` stays 105.

## 5. Start-up sequence (unchanged order, one insertion)

`WM_CREATE` creates the panels → `LoadConfig` (reads the option and the tab
lists) → panel paths applied as today → **`SetTabsEnabled(Configuration.PanelTabs)`
on both panels** (creates the strips, captures record 0 from the panel) →
`FocusPanel`, window placement, etc. as today.
