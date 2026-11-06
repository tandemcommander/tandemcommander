# Fix log - 405-tab-switch-dialog-drag

Backlog item `problem-s-prepinanim-zalozek` (GitHub issue #22): switching away from an FTP tab leaves the
tab strip in drag mode.

## Measurement at 09eaa097 (before)

Sites (searched by name, `src/tabwnd.cpp`):

- `CTabWindow::OnLButtonDown`, `case tspTab`: `SwitchToTab(index)` first, then always
  `WaitForDrag = TRUE` ... `SetCapture(HWindow)`.
- `WM_MOUSEMOVE` (feature 404, review 1 S2): a move without `MK_LBUTTON` while a gesture is pending
  calls `CancelGesture()` - a partial guard. 404 review 2 left the note "a stale capture after a switch
  that showed a dialog can eat the next click"; a `GetKeyState` check was rejected there because posted-
  message probes never set the key state.
- Callers of `OnLButtonDown`: only the strip's `WM_LBUTTONDOWN` (`tabwnd.cpp`, after `HasLockedUI`).
  Callers of `SwitchToTab` from the strip: this press, the tab list menu (`OpenTabList`, no drag) - only
  the press arms a drag.

Reachability: a click on a tab (default configuration, panel tabs on) -> `SwitchToTab` -> `ChangeDir` ->
the leave rules of the current location (FTP: the "keep / close connection" question) or an error box of
the target -> modal loop on the GUI thread -> the button-up goes to that window -> the strip arms a drag
and captures the mouse with no button held.

Probe `probe/tabs405_probe.ps1` (new), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\405-tab-switch-dialog-drag\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\405-tab-switch-dialog-drag\probe\tabs405_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Left tabs A X1 X2 X3 B; X1..X3 deleted after the start, so a click on one shows "Error Changing
Directory" inside the strip's `WM_LBUTTONDOWN` (the same place as the FTP question). The probe attaches
to the program's GUI thread (`AttachThreadInput`) and sets `VK_LBUTTON` with `SetKeyboardState` (down at
the press, up while the box is open) - read back "down" / "up", so the seam works.

Result (`probe/result_before.txt`): PASS 2, FAIL 3, NOT DRIVEN 1.
- RELEASED FAIL: after the box the strip holds the capture; a move with the button and a release moved
  the switched tab to the end (`A X1 X2 X3 B` -> `A X2 X3 B A`, the tab fell back to `A`'s folder).
- NOBUTTON FAIL: capture held after the box (the move without a button then released it - the 404 guard).
- HELD FAIL in this run only because the first row moved a tab and the row's index pointed at B (no
  box). The probe now finds X2 / X3 by name.

Note: the maintainer had the Debug build and the installed program open when the run started (the build
could not replace the exe, the probes refuse while it runs); the run waited until both were closed.
Nothing was closed by the run.

## Decision

Arm the drag after the switch only when `SalTabArmDragAfterSwitch(downAtPress, downAfterSwitch)`
(`src/common/saltabs.*`) allows it: FALSE only for "held at the press, not held after the switch". The
state is `GetKeyState(VK_LBUTTON)` (synchronous, logical button). A posted press reads "up" both times
and arms as before, so the 404 probes stay valid. A new press with a gesture still pending cancels it
first (`CancelGesture`). Research: `research.md`.

## Implementation

- `src/common/saltabs.h` / `.cpp`: `SalTabArmDragAfterSwitch(downAtPress, downAfterSwitch)` - FALSE only
  for "held at the press, not held after the switch".
- `src/saltests/saltests.cpp`: `TestTabStrip405`, 6 checks (the four combinations, any non-zero = down).
- `src/tabwnd.cpp` `CTabWindow::OnLButtonDown`: `downAtPress = GetKeyState(VK_LBUTTON) & 0x8000` at the
  start; a gesture still pending (`WaitForDrag`, `Dragging`, `PressedClose >= 0`) is cancelled with
  `CancelGesture()` before the hit test (also when the press hits nothing); after `SwitchToTab` the drag is
  armed (and the capture taken) only when the rule allows it.
- `help/src/hh/salamand/windows_tabstrip.htm`: one sentence - a tab moves only while the button is held
  from the press to the release; answering a question of the switch ends the press.
- No UI string, dialog, setting or stored data changed: no `.slt` refresh needed (stop-rules §2.13 not
  triggered).

## Probe runs

| Run | Build | Result |
|---|---|---|
| `result_before.txt` (first, at 09eaa097) | HEAD | PASS 2, FAIL 3, NOT DRIVEN 1 (HELD failed on a probe index, fixed) |
| `result_before.txt` (kept) | the old handler (`tabwnd.cpp` of HEAD, the rule present) | PASS 3, FAIL 2 (RELEASED, NOBUTTON), NOT DRIVEN 1 |
| `result_after.txt` | the fix (after review 1, with row STALE) | **PASS 7, FAIL 0, NOT DRIVEN 1** (REAL-FTP) |
| `result_tabs404.txt` | the fix | `tabs404_probe` **PASS 29, FAIL 0, NOT DRIVEN 1** (unchanged from 404) |

Traps met while measuring (recorded so the next run does not repeat them):
- The HELD row first expected the dragged tab in slot 0; the strip clamps the dragged tab at its left
  end, so its centre never passes tab 0's centre and it lands in slot 1 (the 404 slot rule, not a defect).
  The row now checks that the dragged (active) tab moved left of its old index.
- Restoring a source with `git show ... | Set-Content` in PowerShell mangled the file (one line; the build
  failed, the probe ran the old exe). Use Bash `git show HEAD:<file> > <file>`.
- `Copy-Item` keeps the source's timestamp: a restored `tabwnd.cpp` older than its `.obj` was not
  recompiled and the "after" probe ran the old handler (FAIL 2). Touch the file before building.

## Checks

- `build.cmd`: BUILD SUCCEEDED (warnings only in untouched `salamdr2.cpp`, `zip.cpp`).
- `saltests`: **282524 checks, 0 failed** (404: 282518; +6).
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- clang-format (the MSVC-bundled one) reformats untouched lines of `saltests.cpp` (2274 lines),
  `saltabs.h` (an enum), `saltabs.cpp` and `tabwnd.cpp`; those hunks were reverted - the new lines
  themselves came out unchanged.

## Owed to a person

- Release checklist `manual-checks-owed-before-the-next-release`: 1 line (feature 405) - the real FTP
  question answered with a real mouse, then mouse moves and a click in the panel.

## Findings fixed on the way

- The stale capture of 404 review 2's NOTE ("a stale capture after a switch that showed a dialog can eat
  the next click"): after a switch whose box took the button-up the rule leaves no capture (probe
  NOBUTTON: "after the box: no capture"); and a gesture still pending at a new press - from any other
  cause - is now cancelled first (FR-003, probe row STALE NEWPRESS: fixed build PASS, the old handler
  FAIL - measured by review 1, `A X1 X2 B` -> `A X1 B X2`). The press that arrives through such a
  capture is still consumed (it hits nothing); only the input after it goes where the user clicks.

## Review

### Review 1 (refute-first agent, HEAD 667606df) - no MUST

Re-ran `tabs405_probe` (5 / 0 / 1), a negative control (the branch built with `src/tabwnd.cpp` of `main`
in its own worktree and build folder: 3 / 2 / 1 - RELEASED `A X2 X3 B A`, NOBUTTON capture held; HELD
passes in both, a valid control), `tabs404_probe` (29 / 0 / 1), saltests (282524 / 0), encoding guard 0.
Traced the FTP path: `SwitchToTab` -> `ChangeDir` (`paneltabs.cpp`) -> `TryCloseOrDetach`
(`plugins/ftp/fs3.cpp`) shows a message box synchronously on the GUI thread - the premise holds; with
"always keep the connection" set FTP asks nothing and the drag arms (correct).

- **S1 the cancel of a pending gesture (FR-003) had no probe row**, and this log credited it with the
  rule's evidence. Fixed: row STALE NEWPRESS added to `tabs405_probe.ps1` (the reviewer's scratch row,
  own fixture `stale`); the wording above corrected.
- **S2 the committed results predated the last relink.** Fixed: rebuilt, `result_after.txt` (PASS 7,
  FAIL 0, NOT DRIVEN 1) and `result_tabs404.txt` (29 / 0 / 1) regenerated on the exe linked 23:51.
- NOTE fixed: the comment at the cancel said the stale capture "never swallows this press" - reworded
  (this press is handled from idle; the input after it goes where the user clicks).
- NOTE fixed: the manual sentence said answering the question "ends the press" - true only when the
  button is let go; reworded ("and you let the button go to answer it").
- NOTE recorded: the button state is set through a seam (`SetKeyboardState`); the reported case (the box
  answered with the mouse) always takes the button-up. A button released over the disabled main window
  with the box answered by keyboard relies on Windows updating the key state for the swallowed click;
  if not, the 404 guard still cancels at the first move without the button. Covered by the release
  checklist line.
- NOTE recorded: the issue's literal symptom (the mark following a mouse with no button) was already
  ended at the first move by 404's guard; 405 adds the case of a press going straight to the strip and
  the capture left behind.
- NOTE left: a second press dispatched while a switch runs could arm a drag from inside the first press
  (old behaviour, not made worse).

After the fixes: `build.cmd` BUILD SUCCEEDED; saltests **282524 checks, 0 failed**; `tabs405_probe`
**PASS 7, FAIL 0, NOT DRIVEN 1**; `tabs404_probe` **PASS 29, FAIL 0, NOT DRIVEN 1**. SHOULD and NOTE
fixes only (no MUST): no second review round required (SKILL.md step 7).
