# Closing report - 346-shift-f6-inplace-rename
Backlog item: shift-f6-renames-the-focused-item-in-place-without-the - Shift+F6 renames the focused item in place, without the Rename dialog
Outcome: closed

## What changed

- Shift+F6 in a panel (no Ctrl, no Alt) opens the existing in-place rename edit (Quick Rename
  window) over the focused item's name; Files > *Rename in Place\tShift+F6* does the same. Enter
  renames and keeps the item focused, Esc cancels; the selection, the length refusal and the plug-in
  FS stages are those of the click-started edit (unchanged `QuickRenameBegin` /
  `HandeQuickRenameWindowKey`). Nothing happens on `..`, in an archive or in an FS without
  `FS_SERVICE_QUICKRENAME`. F2, F6, Ctrl+F6, Alt+F6 and Ctrl+Shift+F6 unchanged.
- Code: `src/common/salrenamekey.h` (new, pure), `src/fileswn5.cpp` + `src/fileswnd.h`
  (`QuickRenameOnIndex` revived), `src/fileswn0.cpp` (key after the plug-in hot keys),
  `src/mainwnd3.cpp` (`CM_QUICKRENAMEINPLACE` 2954), `src/keyboard.cpp` (Shift+F6 reserved for new
  plug-in bindings, an old one kept at load), `src/menu4.cpp`, `src/resource.rh2`, `src/texts.rh2`,
  `src/lang/texts.rc2` (`IDS_MENU_FILES_RENAMEINPLACE` 13019), `src/saltests/saltests.cpp`.
- Help: `shortcuts_keyboard.htm`, `advwork_rename.htm`, context-help alias in `salamand.hhp`.
- Translations: the new menu text in cs de fr nl hu ro sk es; 5 pins (`_feature_346`).

### CHANGELOG entry (owed to the maintainer - the tree has no `## [Unreleased]` section)

```text
- **Shift+F6 renames the focused file or folder right in the panel** (feature 346).
  - **Before:** the keyboard offered only the Rename dialog (F2); the edit box over the name opened only when the already focused name was clicked slowly, and Shift+F6 did nothing.
  - **Now:** Shift+F6, or Files > Rename in Place, opens the edit box over the focused item's name with the name (without the extension) selected; Enter renames, Esc cancels, the renamed item stays focused. F2 still opens the Rename dialog. On `..` and inside archives nothing happens; in FTP and SFTP panels it works as the slow click does.
  - **Limitation:** Shift+F6 is now a program key: Plugins Manager no longer accepts it for a plug-in command (a binding made earlier is kept, but it never ran from the key - see the Inbox item on F-key hot keys).
```

## Measurements (before / after, commands)

- Before (main e0c3690d): `probe/result_before.txt` - Shift+F6 sent to the panel opened no edit
  on a file, a folder or an accented name (6 FAIL rows).
- After: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\346-shift-f6-inplace-rename\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\346-shift-f6-inplace-rename\probe\rip346_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
  → 13 PASS, 0 FAIL; registry restored identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` and `.\build.cmd full` → BUILD SUCCEEDED (21 modules x 8 languages).
- `saltests.exe` → `saltests: 28972 checks, 0 failed` (+20, `TestRenameInPlaceKey346`).
- Probe `rip346_probe.ps1` 13 / 0; `translate.slt --verify` byte-exact (298 files).
- The help is not compiled here (HTML Help Workshop not installed; not part of `build.cmd`).

## Reviews (findings and what was done)

Review 1: MUST 0; SHOULD 1 fixed (context-help alias `CM_QUICKRENAMEINPLACE`); NOTE 5 accepted
(fix-log *Review*). The reviewer's own probe: quick-search filter, an item scrolled out of view,
view modes 1-5 - all edited the right item inside the panel.

## Owed to a person (with the new person-step items)

- `check-shift-f6-rename-in-place-with-a-real-keyboard-and-an` - real keyboard, horizontal scroll,
  menu, FTP/SFTP panel, compiled help.
- Add the CHANGELOG entry above when the next version's section is opened.

## New Inbox items (slug - title)

- `plug-in-hot-keys-on-f-keys-never-run-f-keys-run-commands` - Plug-in hot keys on F-keys never run; F-keys run commands bound to letters
- `check-shift-f6-rename-in-place-with-a-real-keyboard-and-an` - Check Shift+F6 rename in place with a real keyboard and an FTP/SFTP panel (person step)
