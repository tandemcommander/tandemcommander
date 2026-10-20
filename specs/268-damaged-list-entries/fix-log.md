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

## Fix

- `src/salamdr2.cpp`, `LoadViewers` and `LoadEditors`: the `else break;` after the required-value test
  is gone - a damaged entry falls through to `itoa(++i, buf, 10)` and `CloseKey(subKey)`, so it is
  closed and skipped; the two low-memory `break`s (item not created / not added) now close the key
  first and still end the list. The body for a readable entry is unchanged.
- `src/mainwnd2.cpp`, `CMainWindow::LoadConfig`, User Menu loop: the same change.
- clang-format (VS 2022 LLVM): no change on the edited lines (two pre-existing differences elsewhere in
  `salamdr2.cpp`, not touched).

## After

- `.\build.cmd` - BUILD SUCCEEDED (exit 0).
- Probe (`probe/result_after.txt`):

  ```
  powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\268-damaged-list-entries\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\268-damaged-list-entries\probe\dmg268_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
  ```

  **PASS 48, FAIL 0** (before 30 / 18), registry restored identical (SHA-256 260702C3...). Saved lists:
  V-NOTYPE a,c; V-PIPE a,c; V-NOMASKS b,c; AV-NOTYPE a,c; E-NOMASKS a,c; E-WRONGTYPE a,c; E-MULTI c;
  U-NONAME a,c; U-WRONGTYPE a,c; the CONTROL rows a,b,c. No KEYS row reports a handle left open. The
  wrong-type rows show the existing box once, as before.
- The low-memory paths (key closed before the `break`) cannot be driven; checked by reading.
- `python tools/check_encoding.py --strict` - TOTAL: 0 finding(s).
- `saltests.exe` - saltests: 24757 checks, 0 failed.

## Inbox

- `settings-import-ends-the-viewers-editors-and-user-menu-lists` (measure:268) - the settings import's
  parsers (`src/common/salcfgimport.h`) still end these lists at a damaged source entry; the loaders now
  skip it. Related to `settings-import-ends-the-highlighting-list-at-a-damaged`.

## Review

### Review 1 (independent refute-first, general-purpose agent) - no MUST

- Re-measured: the 48 rows pass on the fixed Debug build, registry restored identical. Negative control
  on the unfixed `build\tandemcommander\Debug_x64_pre251`: 28 rows fail (every damaged row SAVED and
  KEYS). Extra rows of its own (scratch copy under `build\p268rev\`): over-long masks, five damaged in a
  row, damaged submenu beginning / end - pass on the fixed build, fail on the unfixed one.
- **SHOULD 1** (in scope - fixed): a skipped damaged submenu *beginning* leaves its end stray - a state
  the old cut list never had (a cut list can only lack an end). `FillUserMenu2` stops the top level at
  the stray end (`src/mainwnd1.cpp`, `case umitSubmenuEnd: goto ESCAPE`), so every later item is hidden
  from the User Menu; the toolbar's level goes to -1 (`src/toolbar5.cpp`), so they are not on the User
  Menu toolbar either; the configuration page cannot delete an end (`src/dialogs4.cpp`). The Decisions
  paragraph above ("the consumers already tolerate that") was wrong. Fix: the pure rule
  `src/common/salumbalance.h` (`CSalUMSubmenuBalance`) - a damaged beginning is skipped together with
  its matching end (the items inside move one level up), a damaged end is loaded as a plain end (named
  `IDS_ENDUSERSUBMENU`, empty texts - exactly as the configuration page creates one; an end's texts are
  never used), intact entries load as read (also the user's own stray end). The damaged entry's type is
  read quietly (`GetValueAux(NULL, subKey, USERMENU_TYPE_REG, REG_DWORD, ..., TRUE)`, as
  `CheckShutdownParams` in the same file reads directly) - no extra box for an entry already damaged.
  saltests `TestUserMenuBalance268`: 21 checks (intact lists as read, nested and repeated damaged
  beginnings, damaged ends, a matching damaged pair, levels beyond the 256 tracked, and a negative
  control that the rule differs from "skip the entry alone").
  Alternatives rejected: skip the whole submenu, as the settings import does for a too-long beginning
  (`SalCfgImpParseUserMenu`, `skipDepth`) - loses the items inside; skip a damaged end alone - the items
  after it fall into the submenu and leave the toolbar.
- **SHOULD 2** (fixed): probe rows for "too long" (FR-002) and the submenu cases - added V-LONG,
  U-STRAYEND (control: the user's own stray end loads as read), U-SUBBEG, U-SUBEND.
- NOTE 1 (N wrong-type entries now show N boxes before the main window, before one): the existing
  message per damaged value read (FR-004, Clarification 1); accepted.
- NOTE 2 (the damaged entry itself is still dropped on exit - a viewer lacking only Type could be
  salvaged): the item's *Expected* and feature 250's precedent (Clarification 2); accepted, named in the
  closing report.
- NOTE 3 (a numbering gap, or an entry key that exists but cannot be opened, still ends the list -
  both existed before): outside the item; the gap is in the spec's edge cases. The unopenable key
  (access denied on one subkey) needs a hand-made ACL; not recorded as an item (pre-existing, no
  report of it, same in every `while (OpenKey(...))` loop of the core).
- NOTE 4 (stale comments in `src/common/salcfgimport.h`): the Inbox item
  `settings-import-ends-the-viewers-editors-and-user-menu-lists` names them.
- NOTE 5 (closing artefacts): written at the close step.

### After the review fixes

- `.\build.cmd` - BUILD SUCCEEDED (first attempt: C2665, string literals for the `char*` parameters of
  `CUserMenuItem` - fixed with the configuration page's `static char emptyBuffer[]`).
- clang-format applied to the new lines (`salumbalance.h`, the User Menu loop and its include, the
  saltests function); no other line touched.
- `saltests.exe` - saltests: 24778 checks, 0 failed (24757 + 21).
- `python tools/check_encoding.py --strict` - TOTAL: 0 finding(s).
- Probe (`probe/result_after.txt`, 21:16): **PASS 64, FAIL 0**, registry restored identical. The four new
  cases: V-LONG a,c (the existing box "(234) More data is available" once); U-STRAYEND a,END,c;
  U-SUBBEG a,b,c; U-SUBEND a,BEG:s,b,END,c.
- Negative control of the four new cases on the unfixed `Debug_x64_pre251`
  (`-Only V-LONG,U-STRAYEND,U-SUBBEG,U-SUBEND`): PASS 10, FAIL 6 - V-LONG saved a; U-SUBBEG saved a;
  U-SUBEND saved a,BEG:s,b (each KEYS FAIL); U-STRAYEND (intact control) passes there too.
- One flaky row, recorded: the full run at 21:14 on the final build had V-NOTYPE END FAIL - the
  program started normally (main window 3.6 s), then did not answer `WM_NULL` within 10 s about 15 s
  later, so the probe ended it before the save (SAVED shows the list as written). The same build passed
  V-NOTYPE 3 of 3 alone (`-Only V-NOTYPE,V-CONTROL`) and the full probe right after (64 / 0). The hang
  came after the loaders had finished; no cause found in the loaders; not reproduced. (Copy of that
  run: `build\p268\result_after_flaky_2114.txt`, not tracked.)
- The registry hash of these runs (383EAEA4...) differs from the first runs (260702C3...): the
  configuration changed between the runs (the reviewer's probes ran in between); every run restored
  its own backup identically, and `reg query ... /f tc268` and `/f T268` find nothing in the real key.
