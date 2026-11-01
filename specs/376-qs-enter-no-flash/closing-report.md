# Closing report - 376-qs-enter-no-flash
Backlog item: opening-a-folder-found-by-quick-search-briefly-shows-the - Opening a folder found by quick search briefly shows the whole parent folder
Outcome: closed

## What changed

- Opening a folder from a quick-search-filtered panel (Enter, double click, Ctrl+PageDown - all
  `CFilesWindow::Execute`) no longer draws the parent's whole listing before the new folder is
  read; the panel goes from the tinted filtered view straight to the new listing.
- Cause (measured, not intermittent): `EndQuickSearch` -> `QFEndView(TRUE)` -> `RefreshListBox`,
  which ends with `ListBox->PaintAllItems` - a synchronous drawing of the whole parent listing,
  every time, before `ChangePathToDisk`. Visible whenever the read takes longer than a screen
  refresh.
- `RefreshListBox(..., BOOL paint = TRUE)`: `FALSE` lays out only (`SetItemsCount(..., TRUE)`; no
  scroll bars, boundary correction, header or items). `EndQuickSearch(BOOL deferPaint = FALSE)` /
  `QFEndView(repaint, deferPaint)` use it and set `QFPaintDeferred`; a scope guard in `Execute`
  calls the new `QFFinishDeferredPaint()` on every return (draws the laid-out parent once if
  nothing drew the panel since, then updates the tint / search text). The full listing is still
  back before the path change (standing rule 244); every other caller keeps the old behaviour.
- Files: `src/fileswnd.h`, `src/fileswn0.cpp`, `src/fileswn1.cpp`, `src/fileswn2.cpp`; probe
  `specs/376-qs-enter-no-flash/probe/qs376_probe.ps1`.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log <result> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\376-qs-enter-no-flash\probe\qs376_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`
(left panel on a folder with five subfolders, `big` holding 30,000 files; type `big`, Enter; list
box pixels sampled every ~6 ms):

| Build | FLASH (whole-parent samples per round) | New listing from |
|---|---|---|
| before (`main` d4fb03e7) | 39 / 38 / 38; 36; 38 / 35 / 38 (FAIL 3 of 3 each run) | 306-316 ms |
| after | 0 in all 12 rounds of three runs | 298-315 ms on a quiet machine (mean 306) |

LOC, BACK (Backspace returns with the cursor on the opened folder), DENY (access denied) and
GONE (folder deleted before Enter) pass before and after. Frame of the flash:
`probe/before_flash.png`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: TOTAL 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED. No UI string, resource or language change (no
  `.slt` refresh, `build.cmd full` not needed).
- saltests: 30,237 checks, 0 failed.
- Probe qs376: 19 rows FAIL 0 (`result_after.txt`), 19/0 (`result_after_timing.txt`), 34/0
  (`result_after_timing2.txt`, 6 rounds); before 15/3, 9/1, 19/3.
- Feature 244 probe (`-Expect new -FilterOption 1`): 45 rows, FAIL 0 (`result_qs244.txt`); the
  reviewer repeated it: 45/0.

## Reviews (findings and what was done)

- Review 1 (refute-first agent): no MUST. Negative control (HEAD~1 in its own worktree) FLASH
  2/2 FAIL, feature build 19/0. SHOULD 1: the fix-log claimed the GONE row exercised the guard's
  drawing - it does not (GONE is drawn by `ChangePathToDisk`, DENY by `Execute`'s access-denied
  branch). Fix-log corrected; an attempt to drive a guard-only route (a `subst` drive removed just
  before Enter) went to a rescue path instead and was dropped
  (`probe/result_review_subst_attempt.txt`). The guard-only routes (Esc / timeout on a slow network
  check, `PrepareCloseCurrentPath` refusing, a plug-in FS that stays) are not driven; the guard
  draws with the same `RefreshListBox` the old code ran. NOTEs 2 (mixed picture while an error
  box of a failed change is open), 3 (remembered top index not exercised by a 6-row folder) and
  4 (history entry) recorded in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `check-by-hand-that-opening-a-folder-found-by-quick-search` - look at it on a real screen with
  a large or slow folder (Enter, double click, Ctrl+PageDown, Backspace back).
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it was not added:

```text
- **Opening a folder found by quick search briefly showed the whole parent folder** (feature 376).
  - **Before:** when quick search showed only the matching items and you opened a matching folder (Enter, double click, Ctrl+PageDown), the panel first drew every item of the current folder on a plain background and only then the opened folder; with a large or slow folder the unfiltered list stayed visible for a moment.
  - **Now:** the panel goes from the search view straight to the opened folder. Going back up still puts the cursor on the folder you opened.
  - **Limitation:** other ways of leaving a folder while quick search is on (choosing a drive, Back/Forward, Change Directory, a hot path) can still show the unfiltered folder for a moment.
```

## New Inbox items (slug - title)

- `leaving-a-folder-by-other-ways-during-quick-search-briefly` - Leaving a folder by other ways
  during quick search briefly shows the whole folder (measure:376).
- `check-by-hand-that-opening-a-folder-found-by-quick-search` - Check by hand that opening a
  folder found by quick search shows no flash (376) (person step, leftover:376).
