# Closing report - 380-regedt-full-path-cut
Backlog item: regedt-full-path-cut-reported-as-success - Registry Editor: a too long full key path is cut and reported as success
Outcome: closed

## What changed

- `src/plugins/regedt/fs2.cpp` `CPluginFSInterface::GetFullFSPath`: a full key path that does not fit
  the core's buffer (`MAX_PATH` bytes) is refused - "Unable to finish operation because of too long
  path name.", `success = FALSE`, the panel stays and Change Directory re-opens for correction. The
  old test `WStrToU8(...) >= 0` was always true (`DWORD`), and `WideCharToMultiByte(CP_UTF8)` fills
  the buffer before failing, so the path cut at 259 bytes was returned as success. A failed conversion
  of the typed path is refused the same way (before: returned with `success` still TRUE).
- `src/plugins/regedt/fs3.cpp` Quick Rename and `src/plugins/regedt/fs5.cpp` rename by Move: the name
  handed back to focus after the refresh is empty when it does not fit (never cut); the rename itself
  is done as before (as New key already handled it).
- `src/plugins/regedt/finddlg2.cpp` Find *Focus*: both conversions checked; a failure shows the "too
  long path" message (parented to the Find window) and sends nothing to the panel.
- The new messages clear the last error first, so no unrelated system text is appended.

## Measurements (before / after, commands)

- Python ctypes at 823f2873: `WideCharToMultiByte(CP_UTF8)` of 200 x U+010D into 260 bytes → 0,
  error 122, 260 bytes written.
- Probe `specs/380-regedt-full-path-cut/probe/regpath380_probe.ps1` through
  `tools\run_on_hidden_desktop.ps1` (Debug x64):
  - before (`result_before.txt`, `result_before_exact.txt`): SHORT PASS, EXACT PASS, LONG FAIL (no
    message, the panel went to the other existing key named by the first 259 bytes), CJK FAIL (cut
    inside a character, "Unable to open registry key ...\uFFFD") - 6 PASS / 2 FAIL counting END rows;
  - after (`result_after.txt`, label after-review): 8 PASS / 0 FAIL; registry restored identical
    (SHA-256), fixture key removed.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → `BUILD SUCCEEDED` (Debug x64).
- `saltests`: not run - nothing in the core or `src/common/` changed (plug-in only; no pure rule).
- Probe: 8 / 0 after, 6 / 2 before; the reviewer's own negative control (old `regedt.spl` in a copy
  of the build tree): 6 / 2.
- No UI strings changed → no `.slt` refresh; `build.cmd full` not needed.

## Reviews (findings and what was done)

Review 1 (refute-first, independent agent): no MUST, no SHOULD. NOTE 1 (last-error text appended to
the new messages) fixed; NOTE 2 (rename / Find guards proven by reading) recorded; NOTE 3 (the core
cuts the focus name in `ChangePathToPluginFS`) → Inbox; NOTE 4 (Find message parented to the main
window) fixed. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (there is no `## [Unreleased]` section since 0.2.0; a run does not
  create one):

  ```text
  - **Registry Editor: a too long relative path went to another key** (feature 380). In a deep
    registry key, typing a path relative to it (Change Directory or `cd`) whose full path is over
    259 bytes of UTF-8 sent the panel, without a message, to the path cut at 259 bytes - possibly
    another existing key. The Registry Editor now refuses it with "too long path name" and the panel
    stays; the name focused after a rename and the Find window's Focus are never cut either. Limit:
    under a key deeper than 259 bytes relative paths are refused (type the whole path).
  ```

- No person-step item: the rename / Find rows are guards proven by reading, not changes that need a
  real keyboard to be trusted.

## New Inbox items (slug - title)

- `relative-path-under-a-deep-plug-in-file-system-path-is` - Relative path under a deep plug-in
  file-system path is refused: the core buffer for GetFullFSPath is MAX_PATH (leftover:380)
- `changing-to-a-plug-in-path-cuts-the-name-to-focus-at-259` - Changing to a plug-in path cuts the name
  to focus at 259 bytes and may focus another item (review:380)
