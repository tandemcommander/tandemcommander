# Fix log: 168 - the probe artefacts of NEXT-WORK item 18

Item 18: "the 093 dialogs probe's Find-menu rows fail in about one run of three (102); 088's
`viewers_probe` fails its Code/Markdown Viewer rows there (item 4). Sampled by 154: the rate
depends on the build; find the mechanism before trusting these rows."

## 088 viewers_probe

Run on the hidden desktop (Debug and the CFG Release build of 167): the Code Viewer / Markdown
Viewer rows (P1-P5, R1) **pass** now - the recorded `ERROR_FAIL_SHUTDOWN` no longer occurs. One
row failed on both builds alike: N3 counted "other windows 2" - Windows 11's
`UAC_InputIndicatorOverlayWnd` / `UAC Input Indicator`, which belong to the process; the newer
probe library ignores them (`$SystemClasses`), this probe did not. Fixed in the probe; N3, P1, P2
again: PASS (`probe/viewers088_after.txt`). Registry identical.

## 093 dialogs_probe, the Find window's menu rows

- Sampled `-Only drive` on the build at 167: without a change 4 of 5 runs with 8 FAIL (every Find
  menu row from Alt+M on: "no menu").
- A first hypothesis (prepared before: the menu bar's loop survives a popup that went away by
  itself; an Esc to the window ends it) was **wrong**: `CMenuBar::EnterMenuInternal` takes every
  message of the thread (`PeekMessage(NULL)`), so an Esc posted to any of its windows ends the
  loop; with the extra Esc 5 of 5 runs failed with 9 FAIL. Withdrawn.
- Diagnostic (the popup's thread next to the window's): in a failing run the first popup after
  Alt+F had thread 0 - it no longer existed when the probe looked; in passing runs it is the Find
  window's thread. The popup opened right after the Find window came up is closed again by the
  window's start-up, and the rows after it fail (`probe/dialogs093_drive_failing_diag.txt`).
- Fix in the probe: the Find window settles before the first menu row (WM_NULL, 1.5 s, WM_NULL;
  also after a reopen). 6 of 6 runs: FAIL 0, PASS 40 (`probe/dialogs093_drive_after.txt`); one
  row NOT DRIVEN in every run - "plain F in the menu bar loop": the very first popup still goes
  away by itself before the probe's Esc (the probe already records such a close on this desktop
  as an effect of it). The popup's thread stays in the row text.

## Recorded, not changed (product, from reading)

`CMenuBar`'s loop ends on Esc, Alt, F10, a mouse button or `WM_USER_CLOSEMENU`; a popup closed
by something else (activation, `WM_CANCELMODE`) leaves it running, and while it runs the keys of
the window are redirected to the menu bar and plain characters are dropped (`WM_CHAR` only
looks for a mnemonic) - typing into the Find window would do nothing until Esc / Alt / a click.
Not seen by a person; NEXT-WORK.
