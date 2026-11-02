# Closing report - 392-filter-dialog-backup
Backlog item: filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a - Filter dialog cuts a long panel filter to 259 bytes after a refused edit
Outcome: closed

## What changed

`src/dialogs3.cpp` `CFilterDialog::Validate`: the typed text is checked in a local `CMaskGroup`
that carries the panel filter's mode (`Filter->GetExtendedMode()`); the panel's own group is no
longer written there. The `char buf[MAX_PATH]` backup and its restoration are gone. The error
box, focus, selection and `ti.ErrorOn` are unchanged; an accepted text is stored by `Transfer` as
before. No UI string, dialog or resource changed (no `.slt` refresh).

Before, a refused edit (syntax error, then Cancel) left the panel with:
- its filter text cut to 259 bytes when the filter was longer (a tab's filter, up to 1000 bytes);
- at any length, the refused text's partly prepared masks - the panel listed by them (`*.txt`
  of `*.txt|`) until the filter was prepared again (found by review 1).

## Measurements (before / after, commands)

Probe `probe/flt392_probe.ps1` (098's library), hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\392-filter-dialog-backup\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\392-filter-dialog-backup\probe\flt392_probe.ps1 -Exe <exe> -Label <label>"
```

| Run | Build | Rows |
|---|---|---|
| `result_before.txt` | main fc9b8691 (before the listing check) | PASS 7, FAIL 1 - `long-refused` 259 of 300 bytes |
| `result_before_review1.txt` | fc9b8691 rebuilt by the reviewer (`%TEMP%\rv392\oldtree`) | PASS 6, FAIL 2 - `long-refused` 259 bytes and lists `b.txt`; `short-refused` lists `b.txt` |
| `result_after.txt` | branch (before the listing check) | PASS 8, FAIL 0 |
| `result_after_review1.txt` | branch | PASS 8, FAIL 0 - 300 of 300 bytes, every listing as before the dialog |

Regression: feature 270's filter rows (`mask270_probe.ps1 -Only flt,flt-unused,flt-ctl`) on the
branch build -> `probe/regress_270_flt.txt` PASS 6, FAIL 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` -> `BUILD SUCCEEDED`, exit 0
- `saltests.exe` -> `saltests: 30798 checks, 0 failed`
- probes: above; every row PASS, none NOT DRIVEN; the registry restored with an identical hash
  after every run

## Reviews (findings and what was done)

Review 1 (independent agent, refute-first): no MUST. SHOULD 1 - the probe did not prove the
panel filters by its filter; the old code listed by the refused text at any length - fixed (a
listing check in every row, read right after the cancel). SHOULD 2 - the records understated the
impact - fixed (spec, fix-log, history). NOTEs: a filter over 259 bytes cannot be switched off
(Inbox); "Don't use filter" stores an invalid text unchecked (accepted, see fix-log); the error
selection is a byte index (Inbox).

## Owed to a person (with the new person-step items)

- No person-step item: nothing was NOT DRIVEN.
- The CHANGELOG has no `[Unreleased]` section (the versions are the maintainer's), so the entry
  below was not written there. Add it when the next release section is made:

  ```text
  - **A refused Change Filter edit no longer changes the panel's filter** (feature 392).
    - **Before:** after "File mask is syntactically incorrect." and Cancel, the panel went on listing by the refused text (for example only `*.txt` files after typing `*.txt|`) until the filter dialog was opened again, and a tab's filter longer than 259 bytes was cut to its first 259 bytes.
    - **Now:** a refused edit leaves the panel's filter exactly as it was - whole, and the panel lists by it.
    - **Limitation:** a filter longer than 259 bytes still cannot be switched off with "Don't use filter" without shortening the text first.
  ```

## New Inbox items (slug - title)

- `filter-dialog-cannot-switch-off-a-panel-filter-longer-than` - Filter dialog cannot switch off a panel filter longer than 259 bytes
- `mask-syntax-error-selects-the-wrong-characters-in-a-non` - Mask syntax error selects the wrong characters in a non-ASCII mask
