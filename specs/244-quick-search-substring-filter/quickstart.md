# Quickstart: validating feature 244

Validation runs, not implementation. Contracts:
[salquickfilter-rules](contracts/salquickfilter-rules.md),
[panel-quick-filter-behaviour](contracts/panel-quick-filter-behaviour.md).

## Prerequisites

- `build.cmd` (Debug x64) green; `saltests` green.
- The GUI probe in `specs/244-quick-search-substring-filter/probe/`. It runs on the hidden desktop (`tools/run_on_hidden_desktop.ps1`).
- The probe backs up `HKCU\Software\Tandem Commander\0.1` before the run and restores it after, with a hash check (see memory *Interrupted probe leaves registry*).
- Keystrokes are posted as `WM_CHAR`/`WM_KEYDOWN` to the panel's list box; commands as `WM_COMMAND`.
- Fixture `%TEMP%\tc244\` (every typed target is asserted to start with it):
  - `left\`: `2024_chatbot\`, `chat.txt`, `alpha\`, `beta.md`, `Report.PDF`, `old.log`, `Účetnictví 2024.xlsx` (NFC and an NFD copy), `notes 😀.txt`, a hidden-attribute file `secret_chat.txt`, a file excluded by a panel filter mask.
  - `right\`: an empty target folder.
  - `big10k\`, `big100k\`: generated names, 1 % containing `needle`.

## V1 — Baseline (before the fix; on 0.1.10 / the unchanged build)

Record these into `probe/result_before.txt`:

- the focus after typing `c`, `ch`, `cha`, `chat`, and after `/chat`;
- that `chat` is refused when no name starts with `c` (`chat.txt` removed);
- that F5 with `old.log` selected and the search on copies `old.log` (the search ends, the whole selection is copied).

Expected: matches *Current behaviour* in the spec. A difference is a finding (fix-log).

## V2 — Pure rules

`saltests` runs the M1–M7, F1–F4 and T1–T4 tables; the total check count rises.

## V3 — Substring and focus (US1)

| Step | Expected |
|------|----------|
| type `chat` in `left\` | focus `chat.txt` (prefix wins), caret after `chat` |
| remove `chat.txt`, refresh, type `chat` | 4 characters accepted, focus `2024_chatbot`, caret after `…chat` |
| type `pdf` | `Report.PDF` |
| type `q` | refused; panel unchanged |
| type `úč` (NFC) | both `Účetnictví` copies match |

## V4 — Visible set (US2, SC-002)

Type `chat`, then Ctrl+A, then F5 to `right\`. `right\` contains exactly the
matches: `2024_chatbot` and `chat.txt`. `secret_chat.txt` is not copied while
hidden files are hidden; the filtered-out file is not copied either. The
directory line reads `Search: chat (2 of N)`.

## V5 — Hidden selection untouched (SC-007)

1. Select `old.log`, type `pdf`, select `Report.PDF`, F8 (to the Recycle Bin, `right\` copy variant for safety).
2. Only `Report.PDF` is affected; the search is still on.
3. Esc: `old.log` is visible and still selected.

Repeat with F5, F6 and Pack (Alt+F5) into `right\`.

## V6 — Lifetime (FR-016–FR-022)

- **Ends:** Esc · Backspace to empty · Enter on `2024_chatbot` (the new directory is complete) · Tab · Ctrl+Shift+PgDn tab switch · F7 `zzz` (not a match: the search ends and `zzz` is focused) · Ctrl+G to another path (history Back returns to the full list's position).
- **Keeps:** F3 view and close · a menu opened and closed · the mouse wheel · Ctrl+F3 sort · Alt+2 view mode · F5 dialog cancelled · application deactivated and reactivated.
- **Refresh:** create `chat2.txt` in `left\` from outside; it appears in the filtered view. Delete all matches from outside; the search ends.

## V7 — Indication (US3, SC-006)

`PrintWindow` captures of the idle and the searching panel in every view mode
(Brief, Detailed, Icons, Thumbnails, Tiles), each in the four built-in schemes
and in Dark:

- the item area differs from the idle panel;
- icons have no untinted squares (or the limitation is recorded);
- the text is readable;
- the other panel is identical to its idle capture.

Person step owed to the maintainer: judge *light but recognisable* on a real
screen, per scheme (NOT DRIVEN on the hidden desktop).

## V8 — Option off (SC-008)

Clear the checkbox (Configuration › Panels). Re-run the V1 steps: the result
equals `result_before.txt` line by line.

## V9 — Archives and plug-in FS (FR-011)

Pack `left\` into `left.zip`, enter it and run V3/V4 inside it. The same on
the SFTP test server (Docker `tandem-sftp`, localhost:2222) if available,
otherwise a person step.

## V10 — Performance (SC-003)

In `big10k\` and `big100k\`, type `needle` character by character. The Debug
TRACE time from `WM_CHAR` to the next paint is under 0.1 s (10k) and 0.3 s
(100k) per keystroke. Backspace is the slowest path (full re-test); report
its maximum.

## Done

V1–V10 recorded in `probe/result_after.txt` and `fix-log.md`. Owed person
steps: V7 colours, and V9 SFTP if not driven. An independent refute-first
review is clean.
