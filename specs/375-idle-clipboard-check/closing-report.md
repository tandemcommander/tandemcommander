# Closing report - 375-idle-clipboard-check
Backlog item: every-activation-of-the-program-blocks-it-150-ms-in-the-idle - Every activation of the program blocks it ~150 ms in the idle clipboard check
Outcome: closed

## What changed

- `src/common/salclipcheck.h` (new): `SalClipCheckNextLook` - the delay of the next look at a busy
  clipboard (500 ms, at most 10 in a series; a free clipboard or another trigger resets).
- `src/fileswn9.cpp`, `src/fileswnd.h`: `IsTextOnClipboard(BOOL noWait = FALSE, BOOL* busy = NULL)` -
  the idle check tries once; *Restore Selection* keeps the 10 x `Sleep(10)` retry.
- `src/mainwnd1.cpp`: the idle check uses the no-wait form, schedules / ends the later looks
  (`IDT_CLIPCHECKRETRY`), remembers whether the last check found the clipboard busy;
  `RequestIdleClipCheckIfBusy()`.
- `src/mainwnd3.cpp`: the timer handler; `WM_USER_ENTERMENULOOP` looks again when the last check
  was busy. `src/shellsup.cpp`: the archive item / archive panel context menus and the disk panel
  background menu do the same before they read the paste states (review 1).
- `src/consts.h`, `src/salamdr1.cpp`: timer id 956 and the four globals.
- `src/saltests/saltests.cpp`: `TestClipCheck375`.
- No UI string, menu or dialog: no translation refresh.

## Measurements (before / after, commands)

- Clipboard primitives (`probe/clip_primitives.ps1`): free clipboard < 1.1 ms on the user's and the
  hidden desktop; clipboard held open by another program: `OpenClipboard` error 5, the
  `IsTextOnClipboard` loop 155-165 ms.
- `probe/act375_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`), 5 activations a row:

| Row | Before (`e1b1e2c9`) | After |
|---|---|---|
| FREE | 0.4-2.3 ms PASS | 0.3-2.2 ms PASS |
| HELD (helper holds the clipboard open) | 15+140..142 ms FAIL | 0.4-1.5 ms PASS (reviewer: 2.9 ms) |
| FREE while the locked session held the clipboard | pre-fix build 125-143 ms FAIL (`result_neg_locked.txt`) | 0.3-1.9 ms PASS (`result_after_review1.txt`) |

Feature 372's "every activation" block (125-143 ms) was most likely measured while the workstation
was locked: then no program can open the clipboard.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 30237 checks, 0 failed` (30227 before; `TestClipCheck375`).
- Probe: PASS 4 / FAIL 0 (`result_after.txt`), PASS 2 / FAIL 0 after review 1; registry restored
  and identical in every run.

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST. It re-ran everything, built the negative control (HELD fails
on `e1b1e2c9`) and counted the later looks with a cdb breakpoint (11 checks 500 ms apart; pre-fix 1).
SHOULD 1 (context menus read the paste states before the menu-loop message) and NOTE 4 (menus stale
after an exhausted series) fixed with `RequestIdleClipCheckIfBusy`; NOTEs 2, 3, 6 accepted (fix-log
*Review*); NOTE 5 (the locked session holds the clipboard) recorded and used as a second negative
control.

## Owed to a person (with the new person-step items)

- `check-by-hand-the-paste-commands-after-switching-back-with-a` - the paste commands' enabled state
  on a real desktop after switching back with a busy clipboard (menus and toolbars cannot be read
  on the hidden desktop).
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it was not added:

```text
- **Switching back to the program paused it for a moment while another program kept the clipboard open** (feature 375).
  - **Before:** every time you switched back to Tandem Commander while another program held the clipboard open (a clipboard manager, remote-desktop clipboard sharing, a program that hangs), the window stopped responding for about 0.15 s while the program waited to check whether there was something to paste.
  - **Now:** the program checks the clipboard once without waiting and looks again every half second for up to 5 seconds; menus that offer Paste look again when they open. Paste becomes available as soon as the other program releases the clipboard.
  - **Limitation:** while the clipboard stays busy, Paste is not offered (as before); it may take up to half a second after the clipboard is released before the Paste toolbar button becomes enabled.
```

## New Inbox items (slug - title)

- `check-by-hand-the-paste-commands-after-switching-back-with-a` - Check by hand the paste commands
  after switching back with a busy clipboard (375) (person-step).
