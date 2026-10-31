# Fix log - 346 Shift+F6 renames the focused item in place

Backlog item `shift-f6-renames-the-focused-item-in-place-without-the`. Branch
`346-shift-f6-inplace-rename`, from `main` at e0c3690d.

## Measured before (main e0c3690d)

Reading:
- `IDA_MAINACCELS1` / `IDA_MAINACCELS2` (`src/salamand.rc`): no Shift+F6 row (F6 Move, Ctrl+F6
  sort by size, Alt+F6 Unpack, Ctrl+Shift+F6 Restore Selection).
- `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`): no F6 case; plug-in hot keys
  (`Plugins.HandleKeyDown`) are the last thing it tries. The accelerators run before it, in the
  message loop (`src/salamdr1.cpp`, `TranslateAccelerator(AccelTable1/2)`).
- `IsSalHotKey` (`src/keyboard.cpp`) VK_F6: NONE, CONTROL, ALT, CONTROL_SHIFT reserved - Shift+F6
  free, so a user may have bound a plug-in command to it.
- `QuickRenameBegin` - its only live caller is the mouse timer `IDT_QUICKRENAMEBEGIN`;
  `QuickRenameOnIndex` exists only in a comment.

Probe (`probe/rip346_probe.ps1`, written for this feature, run from the session scratch folder with
`-Lib` pointing at `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\rip_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <repo>\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result `probe/result_before.txt`: S6-UPDIR PASS (trivially), S6-FILE / S6-ESC / S6-ENTER / S6-FOCUS
/ S6-DIR / S6-UTF8 FAIL ("no edit"), then the Ctrl+Shift+F6 row: `WM_KEYDOWN timed out` (30 s) -
the run ended there (ERROR row). Registry restored identical. To be explained in the after run.

## Decisions

- The key is recognised in the panel key handler after the plug-in hot keys (research R1), not as an
  accelerator: an existing plug-in binding of Shift+F6 keeps running.
- `IsSalHotKey` reserves Shift+F6, `IsSalHotKeyKeptAtLoad` keeps a stored one (R2, precedent 312).
- Menu: Files > *Rename in Place\tShift+F6* after *Quick Rename...*, no access key (R4).
- Bottom toolbar Shift row unchanged (R5) - not asked by the item.

## Analyze (speckit-analyze) - accepted MEDIUM findings

- C1 quick search active: the posted command passes the WM_COMMAND preamble (`CancelPanelsUI`) as
  F2 and every menu command do - same state handling as F2.
- C2 / I1: the settings import refuses Shift+F6 as a new plug-in binding through `IsSalHotKey`
  (visible "skipped" line) - as every program key since 312.
- U1 plug-in FS path: same `QuickRenameBegin` code as the click start; owed to a person (FTP/SFTP).

## Implementation

- `src/common/salrenamekey.h` (new): `SalIsRenameInPlaceKey`, `SalIsRenameInPlaceHotKey`.
- `src/fileswn5.cpp` / `src/fileswnd.h`: `QuickRenameOnIndex` revived (caret, `EnsureItemVisible`,
  `GetItemRect`, a point inside the cell clamped into `FilesRect`, `GetIndex(..., &labelRect)`,
  `QuickRenameIndex` / `QuickRenameRect`, `QuickRenameBegin`); refuses while an editor is open and
  stops a pending click-start timer.
- `src/mainwnd3.cpp`: `CM_QUICKRENAMEINPLACE` (2954) handler.
- `src/fileswn0.cpp`: `OnSysKeyDown` posts the command after `Plugins.HandleKeyDown`.
- `src/keyboard.cpp`: `IsSalHotKey` VK_F6 + SHIFT; `IsSalHotKeyKeptAtLoad` Shift+F6.
- `src/texts.rh2` / `src/lang/texts.rc2`: `IDS_MENU_FILES_RENAMEINPLACE` 13019 (free slot of the
  bundle of 13021) "Rename in Place\tShift+F6"; `src/menu4.cpp`: Files menu row after Quick Rename.
- Help: `shortcuts_keyboard.htm` (Shift+F6 row), `advwork_rename.htm` (menu, key, mouse).

## Measured after

- `.\build.cmd` → BUILD SUCCEEDED; `saltests.exe` → `saltests: 28972 checks, 0 failed`
  (`TestRenameInPlaceKey346`: 20 checks); `python tools/check_encoding.py --strict` → `TOTAL: 0`.
- Probe `probe/result_after.txt`: **13 PASS, 0 FAIL** - S6-UPDIR, S6-FILE (`a.txt`, sel 0..1),
  S6-ESC, S6-ENTER (renamed on disk), S6-FOCUS (Shift+F6 again edits `a2.txt`), S6-DIR (sel 0..4),
  S6-UTF8 (exact accented text, sel 0..7, renamed to another accented name), CS6, KEEPS (F6,
  Alt+Shift+F6 open nothing), MENU, F2 (Rename dialog with `a2.txt`, Cancel keeps it), ARCHIVE
  (inside `arch.zip`: neither the key nor the command opens an editor). Registry restored identical.
- Negative control: the same S6 rows on the build of e0c3690d: 6 FAIL "no edit" (`result_before.txt`).

### Probe problems on the way

1. The first after runs hit `WM_KEYDOWN timed out` on Ctrl+Shift+F6 (as the before run did): the
   key sent straight to the panel (past the accelerator) opened the **Undelete** dialog. Cause:
   `CPlugins::QueryHotKey` upper-cases the virtual key through `UpperCase[]` (a character table):
   VK_F6 = 0x75 = 'u' → 'U', and Undelete's hot key is Ctrl+Shift+U. Pre-existing and outside this
   item → Inbox item (`measure:346`). The CS6 row now sends with a 3 s timeout, records the window
   and cancels it. In the real message loop the accelerator Restore Selection takes Ctrl+Shift+F6.
   Consequence for this feature: a plug-in hot key on Shift+F6 never ran from the key (Shift+F6 is
   looked up as Shift+U, which is reserved), so the spec's premise "a user's binding keeps running"
   was wrong - spec, research, contract, plan and code comments corrected: the binding is kept at
   load (not erased), Shift+F6 opens the editor.
2. The F2 row failed once: the probe's `$r = Serve ...` inside `Run-Disk` shadowed the fixture path
   `$R` (PowerShell names are case-insensitive, and called functions see the caller's variables).
   Renamed to `$srv`.

## Translations (stop-rules §2.13)

- Step 0: one new entry, `IDS_MENU_FILES_RENAMEINPLACE` (STRINGTABLE:106:13019); no changed ids.
  `english_fallback` rows in `salamand.origin` before: 0 in every enabled language.
- Dry run: 1 unique gap per language (cs de fr nl hu ro sk es), ~25 chars each.
- Merge `--formality prefer_more --budget 2400`: DeepL characters sent 120, validation failures 0.
- Read-back and pins (`translations/ui-overrides.json`, `_feature_346`): de `Umschalt+F6`,
  fr `Maj+F6`, es `Mays+F6` (the module's key names); sk `Premenovať` (DeepL `Pomenovať` = to name);
  nl `Naam ter plaatse veranderen`, es `Cambiar nombre en el mismo lugar` (the module's rename term).
  cs `Přejmenovat na místě`, hu `Helyben átnevezés`, ro `Redenumire pe loc` kept.
- Second merge: 0 gaps; `python -m translate.slt --verify` → round-trip byte-exact (298 files).
- Layout drift: none (each `.slt` diff = the new row + the TEXTVERSION/VERSION header).
- `.\build.cmd full` → BUILD SUCCEEDED (21 modules x 8 languages).

## Review

Review 1 (independent agent, refute-first, on 9a32cf54): **no MUST**.
- Re-ran saltests (28972 / 0) and the probe (13 PASS / 0 FAIL, registry identical); own probe of the
  reviewer: quick-search filter on (`b2` typed, Shift+F6, rename `b2.txt` -> `b9.txt`: the right file
  renamed, nothing else), the focused item scrolled out of view, view modes Alt+1..5 (first rows and
  last item) - the editor opened on the focused item, inside the panel, every time.
- Confirmed the plug-in hot-key reading (`QueryHotKey` looks F6 up as U; Shift+U reserved).
- **S1 (SHOULD, fixed)**: no context-help alias for the new command - What's This (Shift+F1) on
  Files > Rename in Place would show a help error. Added
  `CM_QUICKRENAMEINPLACE=hh\salamand\advwork_rename.htm` to `help/src/salamand.hhp` (as 245 did
  for `CM_IMPORTFROMSALAMANDER`). Not compiled: HTML Help Workshop (`hhc.exe`) is not installed on
  this machine and the help is not part of `build.cmd`; the line follows the existing pattern
  (the `.hhp` includes `resource.rh2`, which defines the id).
- N1: the CS6 row proves nothing about the Ctrl check (Undelete's Ctrl+Shift+U answers first when
  the key is sent past the accelerator) - covered by `TestRenameInPlaceKey346` instead. Accepted.
- N2: the "editor already open" guard of `QuickRenameOnIndex` cannot fire through WM_COMMAND (the
  preamble's `CancelPanelsUI` closes an editor first, without renaming) - kept as a defensive check.
- N3: in an archive the caret item is scrolled into view before `QuickRenameBegin` refuses -
  harmless, accepted.
- N4: the `.slt` header moves to 0.2.0 / 195 - the pipeline's normal catch-up after the release.
- N5: plug-in FS, horizontal scroll in Detailed view and a real keyboard not probed - person step.
