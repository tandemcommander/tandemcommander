# Closing report - 372-wsl-activation-freeze

Backlog item: switching-back-to-tandem-commander-freezes-it-briefly-while - Switching back to Tandem Commander freezes it briefly while a panel shows a WSL folder
Outcome: closed

## What changed

- **The 400 ms freeze**: `CFilesWindow::ChangePathToDisk` (`src/fileswn2.cpp`) slept 400 ms and
  listed the folder a second time on every refresh of a monitored folder whose change
  notification failed - every refresh of a WSL folder (9P has no change notification), on the UI
  thread, 200 ms after each activation. Now a 400 ms one-shot panel timer starts a background
  check; only a folder that is no longer accessible is refreshed again (and left, as before).
- **The cold-distribution freeze**: `CFilesWindow::Activate` (`src/fileswn6.cpp`) checked a
  network folder synchronously (`CheckPath`: 200 ms grace, "ESC to cancel" window - ~2 s for a
  stopped WSL distribution). Now the same check runs on a worker; its posted answer leads to the
  refreshes the synchronous code posted.
- The worker (`StartBkgndPathCheck`, `src/salamdr5.cpp`) uses the check-path thread's own test,
  moved into `SalTestPathAccessible` unchanged (its fixed-disk fallback mask now a heap buffer of
  the path's length). At most one awaited worker per panel; a result applies only while the panel
  shows the folder; a hung worker is abandoned after 10 s or when the panel shows another folder
  (generation number).
- Rule `src/common/salbkgndcheck.h` (route, verify condition, result -> action, abandonment) with
  `TestBkgndPathCheck372` in saltests.
- No UI strings, no configuration, no plug-in interface change.

## Measurements (before / after, commands)

Probe `specs/372-wsl-activation-freeze/probe/act372_probe.ps1` on the hidden desktop
(`tools\run_on_hidden_desktop.ps1`), WM_ACTIVATEAPP FALSE / TRUE posted, WM_NULL pings every 2 ms:

| Row | Before (`result_before.txt`, main 50c47081) | After (`result_after2.txt`) |
|---|---|---|
| WSLROOT `\\wsl.localhost\Ubuntu\` | 392-408 ms wait at +218 ms, 5/5 | late waits 1.4-5.1 ms |
| WSLBIG `...\usr\bin` (827 entries) | 408-411 ms at +218 ms | 0.3-5.1 ms |
| LOCAL control | 140 ms at +15 ms (clipboard check) | 140-143 ms (unchanged, out of scope) |
| WSLNEW / WSLDEL / VEARLY / VLATE / SHARE | - | PASS (changes still followed, deleted folder left, verification proven by its control) |

Cause located by temporary QPC instrumentation (reverted; fix-log *Where the time goes*).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` (Debug x64) -> `BUILD SUCCEEDED`
- `saltests.exe` -> `saltests: 30120 checks, 0 failed`
- probe -> PASS 16, FAIL 0, NOT DRIVEN 4 (busy cursor not readable on the hidden desktop);
  registry restored, identical SHA-256
- no translations involved (no UI text changed)

## Reviews (findings and what was done)

- Review 1: 0 MUST. SHOULD - the cold-distribution gain is not measured -> person-step item.
  NOTE - a hung worker swallowed later requests -> fixed (abandonment + generation number,
  saltests + 5). Other NOTEs accepted (fix-log *Review*); its VEARLY / VLATE rows taken into the
  probe.
- Review 2 (focus on the fix): 0 MUST; negative control with a hook build (hung worker): H1 / H2
  PASS on HEAD, FAIL on the build before the fix -> recorded (`probe/review2/`). NOTEs accepted.

## Owed to a person (with the new person-step items)

- `check-by-hand-switching-back-with-a-wsl-folder-in-a-panel-no` - busy cursor and the
  stopped-distribution case on the user's own desktop.
- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it was not added there:

```markdown
- **Switching back to the program no longer freezes it with a WSL folder in a panel** (feature 372).
  - **Before:** with a WSL folder (`\\wsl.localhost\Ubuntu`) or another network folder without change notification in a panel, every switch back to Tandem Commander stopped it for about half a second with the busy cursor; after the WSL distribution had stopped, the first switch back froze it for about two seconds.
  - **Now:** the window answers at once; the folder is checked in the background and the panel is refreshed as before (new and removed items appear, a folder deleted meanwhile is left).
  - **Limitation:** a short pause (~0.15 s) of every switch back, also with local folders, remains (the check of the clipboard for the paste commands); for a network folder that does not answer, the "press ESC to go to a fixed drive" window no longer appears - the panel keeps its listing until the folder answers.
```

## New Inbox items (slug - title)

- `every-activation-of-the-program-blocks-it-150-ms-in-the-idle` - Every activation of the program
  blocks it ~150 ms in the idle clipboard check (measure:372)
- `check-by-hand-switching-back-with-a-wsl-folder-in-a-panel-no` - Check by hand: switching back
  with a WSL folder in a panel no longer freezes (person-step, leftover:372)
