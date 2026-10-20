# Closing report - 268-damaged-list-entries
Backlog item: a-damaged-viewer-editor-or-user-menu-entry-erases-the - A damaged viewer, editor or User Menu entry erases the entries after it
Outcome: closed

## What changed

- `src/salamdr2.cpp`, `LoadViewers` / `LoadEditors`, and `src/mainwnd2.cpp`, `CMainWindow::LoadConfig`
  (User Menu loop): a damaged entry (a required value missing, of the wrong type or too long; viewers
  also masks with `|`) is closed and skipped instead of ending the list, so the entries after it are
  loaded and kept by the save on exit. The low-memory `break`s still end the list but close the entry
  key first. Intact entries load exactly as before.
- `src/common/salumbalance.h` (new, header-only, `CSalUMSubmenuBalance`), used by the User Menu loop: a
  skipped damaged submenu beginning takes its matching end along (the items inside move one level up);
  a damaged submenu end is loaded as a plain end (`LoadStrU8(IDS_ENDUSERSUBMENU)`, empty texts, as the
  configuration page creates one); intact entries, also the user's own stray end, load as read. The
  damaged entry's type is read quietly (`GetValueAux`, quiet).
- saltests `TestUserMenuBalance268` (21 checks); the header is listed in
  `src/vcxproj/saltests/saltests.vcxproj`.
- No UI string, registry layout, save code, plug-in interface or installer change.

## Measurements (before / after, commands)

Probe `probe/dmg268_probe.ps1` on the hidden desktop:

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\268-damaged-list-entries\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\268-damaged-list-entries\probe\dmg268_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

- Before (HEAD0 `56a5f414`, 12 cases): PASS 30, FAIL 18 - every damaged row saved only the entries
  before the damaged one (a damaged first entry: nothing) and left a key open; controls passed.
- After (16 cases, 4 added after review 1): **PASS 64, FAIL 0**, registry restored identical.
- Negative control of the 4 added cases on the unfixed `build\tandemcommander\Debug_x64_pre251`:
  PASS 10, FAIL 6 (every damaged row fails; the intact stray-end control passes there too).
- One flaky row in one full run (V-NOTYPE END: `WM_NULL` unanswered about 15 s after start, so the
  probe ended the program before its save); not reproduced in 3 single runs and 2 full runs; judged
  unrelated by review 2 (fix-log *After the review fixes*).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` - TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64) - BUILD SUCCEEDED.
- `saltests.exe` - saltests: 24778 checks, 0 failed (24757 before + 21).
- Probe - PASS 64, FAIL 0, NOT DRIVEN 0.
- clang-format - no change on the edited lines.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD 1 - a skipped damaged submenu beginning left a stray end
  (hides the later items from the menu and the toolbar, cannot be deleted in the configuration page):
  fixed with `salumbalance.h`. SHOULD 2 - probe rows for over-long masks and submenus: added. NOTEs
  accepted (more boxes for several wrong-type values; the damaged entry itself not kept; gap /
  unopenable key pre-existing; stale import comments -> Inbox).
- Review 2 (fresh, with review 1's findings): no MUST; 100 / 0 with 9 more User Menu rows of its own,
  18 failing on the unfixed build. SHOULD 1 - the synthesized end's name used code-page `LoadStr`:
  now `LoadStrU8`; the same pre-existing use in the configuration page -> Inbox. NOTE 2 - header
  comment about levels beyond 256 corrected; other NOTEs accepted.

## Owed to a person (with the new person-step items)

Nothing. Every probe row was driven (no keyboard, clipboard or printer involved).

## New Inbox items (slug - title)

- `settings-import-ends-the-viewers-editors-and-user-menu-lists` - Settings import ends the viewers,
  editors and User Menu lists at a damaged entry (measure:268)
- `the-user-menu-page-names-a-new-submenu-end-in-the-code-page` - The User Menu page names a new
  submenu end in the code page, not UTF-8 (review:268)
