# Closing report - 312-tabs-browser-keys
Backlog item: panel-tabs-chrome-shortcuts-and-reopen-closed-tab - Panel tabs: a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab
Outcome: closed

## What changed

- Configuration > Tabs (after Appearance) holds *Show tabs in panels* (moved from Appearance) and
  the new option *Browser-like tab shortcuts* (off by default), with a list of the tab shortcuts
  that follows the option at once.
- With the option on (and tabs on): Ctrl+T new tab, Ctrl+W close tab, Ctrl+Page Down / Up next /
  previous tab, Ctrl+Shift+T Reopen Closed Tab, Ctrl+Shift+W Restore Selection, Ctrl+Shift+G Go to
  Shortcut or Link Target - in the panel and the command line. With it off every key does what it
  did in 0.1.10.
- Reopen Closed Tab in both modes (10 per panel, memory only), Tabs in Options > Show and in the
  toolbar context menu; Go to Shortcut or Link Target visible at every skill level.
- One pure key table (`src/common/saltabs.*`) drives the dispatch, the menu labels and the page.
- Translated into the eight enabled languages; manual pages updated.

## Measurements (before / after, commands)

- Before (4a7d5595): the tab keys were only Ctrl+Shift+T / W / Page Up / Down; no reopen; the
  setting was one Appearance checkbox (`fix-log.md` *Measurement*).
- After: `tabs312_probe` PASS 33, FAIL 0 (new feature rows; the classic rows as the control), on
  the branch (`probe/result_after.txt`) and again after merging `main`
  (`probe/result_after_merge.txt`), registry restored identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `.\build.cmd full` -> BUILD SUCCEEDED (the eight core language modules import).
- `saltests: 27664 checks, 0 failed` (312 added 106 checks, `TestTabKeys312`).
- `check_encoding.py --strict`: TOTAL 0.
- Translations: 10 gaps per language, 1,832 DeepL characters, validation failures 0, 24 pins,
  0 accelerator collisions in the Tabs submenu, Options > Show and the Tabs page;
  `translate.slt --verify` 298 files byte-exact.

## Reviews (findings and what was done)

- Review 1 (autonomous run): no MUST, 2 SHOULD fixed (`fix-log.md` *Review*).
- Review of the merge with `main` (313's quick-search keys in the same file): no MUST, no SHOULD;
  NOTEs on behaviour already accepted by the spec (`fix-log.md` *Finished*).

## Owed to a person (with the new person-step items)

- `tabs-312-real-keyboard-and-eight-languages` - the real keys in both modes in the panel and the
  command line; the Tabs page and the menus in the eight languages.

## New Inbox items (slug - title)

- none in the finishing session.
