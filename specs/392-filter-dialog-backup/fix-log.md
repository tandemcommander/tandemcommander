# Fix log - 392-filter-dialog-backup

Backlog item `filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a` - Filter dialog cuts a
long panel filter to 259 bytes after a refused edit.

## Measurement before (main fc9b8691)

Site: `src/dialogs3.cpp` `CFilterDialog::Validate` - `char buf[MAX_PATH]; lstrcpyn(buf,
Filter->GetMasksString(), MAX_PATH)` backup; `ti.EditLine(IDE_FILTER,
Filter->GetWritableMasksString(), MAX_PATH)` writes the typed text into the panel's own group;
`PrepareMasks` fails; `Filter->SetMasksString(buf)` restores the cut backup (and resets
`ExtendedMode` to FALSE, leaves `NeedPrepare` TRUE). Caller: `CFilesWindow::ChangeFilter`
(`src/fileswn9.cpp`, `CFilterDialog(HWindow, &Filter, ...)`), commands CM_CHANGEFILTER /
CM_LCHANGEFILTER / CM_RCHANGEFILTER; Cancel after the error does nothing more, so the cut filter
stays in the panel.

Corrected by review 1: the failed `PrepareMasks` of the typed text leaves the masks it prepared
before the error (`*.txt` of `*.txt|`) in the panel's group, and `SetMasksString(buf)` changes
only the text and `NeedPrepare` - so after Cancel the panel **lists by the refused text** (at
any filter length, also a short one) until its filter is prepared again (the next Change Filter
does that in `Transfer`). Measured by the probe's listing check (below, review 1).

Reachability: `Filter` > 259 bytes comes from a tab's `Filter` registry value (read with
`SAL_TAB_FILTER_MAX` = 1001 in `mainwnd2.cpp`, set into `Filter` in
`CFilesWindow::SwitchToTab` (`paneltabs.cpp`) when the tab is activated). The panel's own
`Filter` value is read with `MAX_PATH`.

Probe `probe/flt392_probe.ps1` (098's library), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\392-filter-dialog-backup\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\flt_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <098 lib>"
```

Result (`probe/result_before.txt`): `long-refused` FAIL - the first dialog showed 300 of 300 bytes,
`*.txt|` refused with "File mask is syntactically incorrect.", Cancel, the next dialog shows 259
bytes (tail `...x036;*.x037;`). `short-refused` PASS, `long-valid` PASS. Registry restored,
identical hash. Defect confirmed; `BL verify` recorded.

Notes answered: the dialog shows the whole long filter (WM_SETTEXT is not bound by
`CB_LIMITTEXT`); OK with the long text unchanged is refused by `DlgItemTextFitsU8` (feature 270)
before anything is touched - the cut needs a shorter invalid text, as the probe does.

## Analyze

`speckit-analyze` (one round): CRITICAL 0, HIGH 0. C1 MEDIUM (the edge case "refused, then
corrected in the same dialog" had no probe row) - fixed: row `long-refused-then-valid` added to
the probe. C2 LOW (the error position is not probed) and C3 LOW (history / "Don't use filter" not
probed) - accepted: the check runs in the same class with the panel's mode, so the verdict and
`errorPos` are the same by construction; `Transfer` is unchanged and feature 270's probe covers
history and "Don't use filter".

## Consumers (T002)

`CFilterDialog` is used at one site: `CFilesWindow::ChangeFilter` (`src/fileswn9.cpp`), reached by
CM_LCHANGEFILTER / CM_RCHANGEFILTER / CM_CHANGEFILTER (`src/mainwnd3.cpp`) and with `disable`
TRUE (no dialog) from `src/fileswnb.cpp`. Refresh is stopped around the dialog
(`BeginStopRefresh`). winliblt `CDialog::ValidateData` (`src/common/winlib.cpp`) returns FALSE on
`ti.ErrorOn`, so `Transfer(ttDataFromWindow)` - which writes the panel filter and prepares it -
runs only after a good `Validate`. Nothing relied on `Validate` writing the panel group.

## Change (T003)

`src/dialogs3.cpp` `CFilterDialog::Validate`: the typed text is read into a local
`CMaskGroup check` (mode = `Filter->GetExtendedMode()`) and prepared there; the error box, focus,
selection (`errorPos`) and `ti.ErrorOn` are unchanged. The `char buf[MAX_PATH]` backup and the
`Filter->SetMasksString(buf)` restoration are gone - the panel's group (text, mode, prepared
form) is not written by `Validate` at all.

## Measurement after (T004, T005)

Build: `.\build.cmd` -> `BUILD SUCCEEDED`, exit 0.

Probe `probe/flt392_probe.ps1 -Label after` (hidden desktop) -> `probe/result_after.txt`:
PASS 8, FAIL 0, NOT DRIVEN 0; `long-refused` the next dialog shows 300 of 300 bytes (tail
`....x042;*.last`), `short-refused`, `long-valid`, `long-refused-then-valid` PASS; registry
restored, identical hash.

Negative control: the same probe on the build of `main` fc9b8691 (`probe/result_before.txt`,
run before the change): PASS 7, FAIL 1 - `long-refused` FAIL with 259 bytes; the three control
rows PASS there too, so only the defect row tells the builds apart.

Regression: feature 270's filter rows (`specs/270-mask-filter-label-fits/probe/mask270_probe.ps1
-Only flt,flt-unused,flt-ctl`) on the new build -> `probe/regress_270_flt.txt`: PASS 6, FAIL 0
(a 260-byte field still refused as too long, "Don't use filter" too, 259 bytes stored whole).

## Checks (T006-T008)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `saltests.exe` -> `saltests: 30798 checks, 0 failed`, exit 0
- No UI string, dialog or resource changed - no `.slt` refresh (stop-rules 2.13 does not apply).

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-measured: the probe on the branch build PASS 8 / FAIL 0; the merge-base fc9b8691 rebuilt in
the reviewer's own worktree and build folder (`%TEMP%\rv392\oldtree`): PASS 7 / FAIL 1
(`long-refused` 259 bytes) - the negative control holds. Code: same verdict and `errorPos` (same
class, the panel's mode), no caller regresses, nothing cut (`DlgItemTextFitsU8` first, UTF-8
read), no data loss.

- SHOULD 1 - the probe did not prove "prepared / the panel filters by it"; the old code listed by
  the refused text's masks at any length, so `short-refused` was no control. **Fixed**: every row
  now reads what the panel lists (CM_LEFTREFRESH, Home, Down, F3 - the viewer's title; fixture
  `a.last`, `b.txt`) before the dialog and right after the cancel (before Change Filter opens
  again: opening it prepares the filter anew in `Transfer` - a first version read it after the
  reopen and saw no stale filtering; the title of a text file is `... [Plain Text] - Code
  Viewer`, the pattern takes both).
  - old code (`%TEMP%\rv392\oldtree\tandemcommander.exe`, `probe/result_before_review1.txt`):
    PASS 6, FAIL 2 - `long-refused` cut to 259 bytes and lists `b.txt` (expected `a.last`),
    `short-refused` lists `b.txt` (expected none).
  - branch build (`probe/result_after_review1.txt`): PASS 8, FAIL 0, every listing as expected;
    registry restored, identical hash.
- SHOULD 2 - the records understated the impact ("as today" for a short filter; "no prepared
  masks"). **Fixed**: spec (story 1, scenario 2, SC-002) and *Measurement before* corrected; the
  history and changelog entries describe the listing by the refused text.
- NOTE - a panel filter over 259 bytes cannot be switched off ("Don't use filter" + OK) without
  changing the field: feature 270 refuses the text as too long. Outside this item -> Inbox.
- NOTE - "Don't use filter" with an invalid text: `Transfer` stores the text and its failed
  preparation unchecked. Accepted: the filter is then off; turning it on goes through
  `Validate`; at the next start an unpreparable filter becomes `*.*` (`mainwnd2.cpp`). Not
  recorded as an item.
- NOTE - `EM_SETSEL errorPos` uses a UTF-8 byte index as a character index: a non-ASCII mask
  highlights the wrong place. Pre-existing, unchanged -> Inbox.

`git status --short` empty after the review (the reviewer edited nothing in the repository).
The source did not change after review 1 (only the probe and records), so no second review.
