# Closing report - 389-compare-icon-fits
Backlog item: user-menu-compare-names-and-the-change-icon-file-are-cut-to - User Menu compare names and the Change Icon file are cut to 259 bytes
Outcome: closed

## What changed

- `src/dialogs2.cpp` `CCompareArgsDlg::Validate`: both name fields are measured whole first
  (`DlgItemTextFitsU8`, `MAX_PATH`), then the existing empty checks.
- `src/dialogs.h`, `src/dialogs3.cpp`: `CChangeIconDialog::Validate` (new) - the file name plus the
  `,<index>` the User Menu page stores must fit `MAX_PATH` (the configuration loader reads the
  `Icon` value into `MAX_PATH`; review 1); `CChangeIconDialog::LoadIcons` refuses a name whose UTF-8
  does not fit 260 bytes before reading it (it fell back to the code-page text), leaving the list
  and the field untouched.
- No UI string, menu or dialog resource changed (the existing "The path specified is too long.").
- Probe `specs/389-compare-icon-fits/probe/fit389_probe.ps1` (new, 9 rows).

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\389-compare-icon-fits\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\389-compare-icon-fits\probe\fit389_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (build of df4d92be, `result_before.txt` / `result_before_chi.txt`): umc-name1, umc-name2
  FAIL (the command received the names without their tail letters), chi-file FAIL ("Cannot find
  the file ...???.exe", SHELL32.DLL stored); controls umc-ctl, chi-ctl PASS.
- Negative control, `Validate` only (`result_negative_control.txt`): 9 / 1 - chi-file FAIL.
- Negative control before the review-1 fix (`result_review1_negative.txt`): chi-store259 FAIL.
- After (`result_after_review2.txt`): **18 / 0** (9 RUN + 9 END rows), the registry restored,
  identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- `.\build.cmd` → `BUILD SUCCEEDED`
- `saltests.exe` → `saltests: 30740 checks, 0 failed`
- Probe 389: 4 FAIL / 6 → 18 / 0
- Regression 291 (`mask291_probe.ps1`): 34 / 0. Regression 251 (`dlg251_probe.ps1`): 38 / 4 - the
  rows vw-cmd / vw-ctl seed `Last Focused Page` 19, which since feature 312's Tabs page is the
  "Viewers and Editors" parent page; with page 20 (a scratchpad copy): 4 / 0
  (`regress_251_viewers_page20.txt`). Recorded as an Inbox item.
- No `.slt` refresh needed (no resource text changed).

## Reviews (findings and what was done)

- Review 1: MUST M1 (a 258 / 259-byte icon name was accepted, its stored `name,index` value too
  long for the loader - lost at the next start) - fixed, rows chi-store259 / chi-reload added,
  negative control recorded. NOTEs N1-N5 recorded (Cancel click lost after a refused reload, as
  before; the dead code-page fallback left; closing documents).
- Review 2: no MUST. SHOULD S1 (the spec still stated 259 bytes for Change Icon) - fixed. NOTE N1
  (index boundary) - taken over as rows chi-idx10 / chi-idx9. N2-N4 recorded.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `CHANGELOG.md` has no `## [Unreleased]` section (the tree is at the 0.2.0 release): add the
  entry below when the next section is opened.

```text
- **The User Menu's names to compare and the Change Icon file were cut at 259 bytes** (feature 389).
  - **Before:** a full name to compare whose UTF-8 form was longer than 259 bytes (about 87 or more Chinese, Japanese or Korean letters in a short folder) was cut silently, and the User Menu command was started with another name. In Configuration > User Menu > Change Icon, such a file name was read in a code-page form: the program said it could not find the file, put SHELL32.DLL into the field and stored it as the item's icon; a name of 258 or 259 bytes was stored but lost at the next start ("Error Loading Configuration").
  - **Now:** both dialogs say "The path specified is too long.", stay open and keep the whole text in the field; nothing is started or stored. Change Icon also refuses to list icons for such a name.
  - **Limitation:** the limit stays 259 bytes, for Change Icon including the icon number the item stores (e.g. ",9"); a shorter path is the workaround.
```

No person-step item: every probe row was driven (text set by WM_SETTEXT, buttons by BM_CLICK, as
in 251 / 291).

## New Inbox items (slug - title)

- `probe-251-opens-the-tabs-shifted-page-for-its-viewers-rows` - Probe 251 opens the Tabs-shifted
  page for its Viewers rows (page index 19) (tech-debt, measure:389)
