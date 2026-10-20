# Fix log - 268-damaged-list-entries

Backlog item `a-damaged-viewer-editor-or-user-menu-entry-erases-the` - A damaged viewer, editor or User
Menu entry erases the entries after it. Autonomous run (`/tandem-backlog-implement`), HEAD0 `56a5f414`.

## Measurement at HEAD (before any change)

Sites (found by name at HEAD):

- `src/salamdr2.cpp`, `LoadViewers`: `while (OpenKey(viewersKey, buf, subKey))` - the entry is used only
  when `Masks` (REG_SZ, `MAX_PATH`) is readable, holds no `|` and `Type` (REG_DWORD) is readable;
  otherwise `else break;`. `itoa(++i, buf, 10); CloseKey(subKey);` run only after a used entry; the two
  low-memory `break`s (item not created / not added) also skip the `CloseKey`.
- `src/salamdr2.cpp`, `LoadEditors`: the same shape with `Masks` as the only required value.
- `src/mainwnd2.cpp`, `CMainWindow::LoadConfig`, User Menu block: required `Item Name`, `Command`
  (REG_SZ), `Execute Through Shell`, `Close Shell Window` (REG_DWORD); `else break;` and two low-memory
  `break`s, all before `itoa` / `CloseKey`.

Consumers enumerated: `LoadViewers` is called twice from `CMainWindow::LoadConfig` (`Viewers` under the
viewer masks critical section, `Alternative Viewers`), `LoadEditors` once; no other callers (Grep of
`src/`, plug-ins excluded - they do not link the core). The saves `SaveViewers` / `SaveEditors` and the
User Menu block of `CMainWindow::SaveConfig` run `ClearKey` and rewrite entries `1..Count` from the
loaded arrays, so whatever the loader did not load is erased on exit.

`IsGood()` of `CViewerMasksItem` / `CEditorMasksItem` / `CUserMenuItem` fails only when an allocation
failed (`dialogs2.cpp`, `salamdr3.cpp`) - the `item->IsGood()` / `Add` failure paths are low-memory
paths only. The viewers configuration page refuses `|` in masks (`dialogs5.cpp`, `forbiddenChar`), so
an entry with `|` comes only from outside.

Reachability: `LoadConfig` runs at every start with an existing configuration; the damaged entry comes
from a registry edit or an imported `.reg` (the dialogs and the saves always write the required values).

### Probe `probe/dmg268_probe.ps1` (new, in the style of `hlt250_probe.ps1`)

Build: `.\build.cmd` at `56a5f414` - up to date (BUILD SUCCEEDED). The probe was first written outside
`specs/` (so that the feature number was not taken before specify) and run with an explicit `-Lib`:

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log build\p268\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File build\p268\dmg268_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before"
```

Result (`probe/result_before.txt`): **PASS 30, FAIL 18**, registry restored identical (SHA-256
260702C3...).

| Row | Before |
|---|---|
| V-CONTROL, E-CONTROL, U-CONTROL | PASS - start, no box, no handle left open, saved a,b,c |
| V-NOTYPE (Viewers a, no Type, c) | FAIL - saved a; handle left open |
| V-PIPE (Viewers a, Masks with `|`, c) | FAIL - saved a; handle left open |
| V-NOMASKS (Viewers no Masks, b, c) | FAIL - saved nothing (the whole list); handle left open |
| AV-NOTYPE (Alternative Viewers a, no Type, c) | FAIL - saved a; handle left open |
| E-NOMASKS (Editors a, no Masks, c) | FAIL - saved a; handle left open |
| E-WRONGTYPE (Editors a, Masks REG_DWORD, c) | FAIL - saved a; one box "Unexpected value type."; handle left open |
| E-MULTI (Editors empty key, no Masks, c) | FAIL - saved nothing; handle left open |
| U-NONAME (User Menu a, no Item Name, c) | FAIL - saved a; handle left open |
| U-WRONGTYPE (User Menu a, Close Shell Window REG_SZ, c) | FAIL - saved a; one box; handle left open |

Every START row passes (the program starts; the wrong-type rows show the existing box once) - the
defect is the silent loss of the later entries and the leaked key, as the item says.

## Decisions

- Skip the damaged entry and continue (the item's *Expected*; feature 250 did the same).
- The low-memory paths keep ending the list (`break`) but close the entry key first (item *Notes*).
- User Menu submenus: a skipped damaged entry can leave a submenu begin without its end (or the other
  way round). The consumers already tolerate that - before the fix a list cut at a damaged entry was
  unbalanced in the same way: `FillUserMenu2` stops a level at an end, the toolbar counts levels,
  `GetSubmenuEndIndex` returns -1 and the configuration page copes. No repair of the structure (not in
  the item; conservative). Entries are kept and saved; the user can fix the structure in the dialog.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH (no second run needed). C1 (LOW, the key closure on the
low-memory paths cannot be driven) accepted - checked by reading. F1 (LOW, the spec pointed to the
highlighting import item for the import of the other lists) fixed: the settings import parsers
`SalCfgImpParseViewers` / `SalCfgImpParseUserMenu` (`src/common/salcfgimport.h`) also end their lists
at a damaged source entry - outside the item, task T009 records it in the Inbox.
