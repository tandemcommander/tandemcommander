# Closing report - 405-tab-switch-dialog-drag
Backlog item: problem-s-prepinanim-zalozek - Switching away from an FTP tab leaves the tab strip in drag mode
Outcome: closed

## What changed

- `src/tabwnd.cpp` `CTabWindow::OnLButtonDown`: the left button's state (`GetKeyState(VK_LBUTTON)`) is
  read when the press is handled and again after `SwitchToTab`; a drag is armed and the mouse captured
  only when `SalTabArmDragAfterSwitch` allows it (refused when the button was held at the press and is no
  longer held - a question or error box of the switch took the button-up). A gesture still pending at a
  new press is cancelled first (capture released).
- `src/common/saltabs.h` / `.cpp`: the pure rule `SalTabArmDragAfterSwitch`; `src/saltests/saltests.cpp`:
  `TestTabStrip405` (6 checks).
- `help/src/hh/salamand/windows_tabstrip.htm`: one sentence on drags and a question shown by the switch.
- Probe `specs/405-tab-switch-dialog-drag/probe/tabs405_probe.ps1` (new).
- No UI string, dialog, setting, stored data, network or plug-in interface change; no `.slt` refresh.

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\405-tab-switch-dialog-drag\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\405-tab-switch-dialog-drag\probe\tabs405_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (the old handler): PASS 3, FAIL 2, NOT DRIVEN 1 - RELEASED: after the box the strip held the
  capture, a later move with the button and a release moved the tab (`A X1 X2 X3 B` -> `A X2 X3 B A`);
  NOBUTTON: capture held after the box. STALE (review 1, old handler): `A X1 X2 B` -> `A X1 B X2`.
- After: PASS 7, FAIL 0, NOT DRIVEN 1 (REAL-FTP) - `probe/result_after.txt`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd`: BUILD SUCCEEDED.
- `saltests`: 282524 checks, 0 failed (was 282518).
- `tabs405_probe`: 7 / 0 / 1; `tabs404_probe` (regression, `probe/result_tabs404.txt`): 29 / 0 / 1.

## Reviews (findings and what was done)

Review 1 (refute-first, with its own negative-control build): no MUST. S1 (no probe row for the cancel
of a pending gesture) - row STALE NEWPRESS added; S2 (results older than the last relink) - regenerated.
NOTEs: comment and manual wording fixed; the key-state seam and the 404 overlap recorded; a re-entrant
second press during a switch left (old behaviour). Details: `fix-log.md` *Review*.

## Owed to a person (the lines added to the release checklist)

- `manual-checks-owed-before-the-next-release`: 1 line (feature 405) - the real FTP question answered
  with a real mouse, then mouse moves and a click in the panel; a held drag still moves a tab.
- Answer and close GitHub issue #22 (draft in `specs/405-tab-switch-dialog-drag/reply.md`).
- Add the CHANGELOG entry below (`CHANGELOG.md` has no `## [Unreleased]` section; versions are the
  maintainer's):

  ```text
  - **A tab switch that asked a question left the tab strip dragging a tab** (feature 405, GitHub issue #22).
    - **Before:** clicking another panel tab when leaving the current one shows a question (the FTP plugin asking what to do with the connection) or an error box: the button's release went to that window, the strip kept waiting for a tab drag and held the mouse - the insert mark could follow the mouse, the next click was swallowed, and a press and move moved the tab where it was never meant to go.
    - **Now:** after such a switch no drag starts and the strip does not keep the mouse; a tab moves only while the button is held from the press to the release.
    - **Limitation:** a button held down through the question (answered with the keyboard) still drags the tab, as it is held from the press to the release.
  ```

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- Feature 404 review 2's NOTE "a stale capture after a switch that showed a dialog can eat the next
  click": no capture is left after such a switch, and any pending gesture is cancelled at a new press
  (probe rows NOBUTTON, STALE).

## New Inbox items (slug - title)

None.
