# Closing report - 386-mydocs-path-whole

Backlog item: my-documents-drive-opens-a-cut-path-when-documents-needs - My Documents drive opens a cut path when Documents needs more than 259 bytes
Outcome: closed

## What changed

- `src/common/salmydocs.h` (new, header-only): `SalDocumentsOrDesktopToU8` - Documents when it
  has a path, the Desktop only when it has none; the whole UTF-8 (WTF-8) path or refused with an
  empty buffer; a Documents path that does not fit is refused, not replaced by the Desktop.
- `src/shellib.cpp` `GetMyDocumentsOrDesktopPath`: both folders read wide (`GetSpecialFolderPathW`),
  the rule decides; the 520-byte intermediate buffer and the `lstrcpyn` cut are gone. Debug-only
  probe seam `TC_PROBE_MYDOCS_FILE` (`contracts/salmydocs.md`).
- Callers: Ctrl+; (`fileswn0.cpp`), the drive bar / Alt+F1/F2 Documents item
  (`fileswn3.cpp` `ChangePathToDrvType`), `SafeGetSaveFileNameW` / `SafeGetOpenFileNameW`
  (`salamdr6.cpp`) hold `SAL_MAX_PATH_UTF8`; the rescue path (`GetIfPathIsInaccessibleGoTo`) keeps
  `MAX_PATH` and takes its drive-root fallback on a refusal.
- `src/saltests/saltests.cpp`: `TestDocumentsPath386` (with the old copy rule as negative control).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\386-mydocs-path-whole\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\386-mydocs-path-whole\probe\mydocs386_probe.ps1 -Exe <exe>"`

| Row | before (66a9dfcc: the seam, old code) | after |
|---|---|---|
| SHORT | PASS | PASS |
| LONG (90 CJK letters, 310 bytes) | FAIL - the prefix folder (259 bytes), silently | PASS - the whole folder |
| LONG200 (200 letters, 640 bytes) | FAIL - `C:\Users\pavel\Desktop`, silently | PASS - the whole folder |
| RESCUE-SHORT | PASS | PASS |
| RESCUE-LONG | FAIL - the prefix folder | PASS - `C:\` (refused, drive-root fallback) |

Registry restored identical in every run. The first before-run (seam = the variable itself)
showed the environment's code-page copy (90 `?`); the seam reads a UTF-8 file since.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64). No UI strings, dialogs or resources changed:
  no `.slt` refresh, no `build.cmd full` needed.
- saltests -> `saltests: 30699 checks, 0 failed`.
- Probe `mydocs386_probe`: before 2 PASS / 3 FAIL -> after 5 PASS / 0 FAIL.
- NOT DRIVEN (code reading; the same helper and buffer change): Ctrl+; (real Ctrl key state),
  the Alt+F1/F2 menu item (same `ChangePathToDrvType` as the button), the File Open / Save
  fallback (only when the common dialog refuses its initial folder).

## Reviews (findings and what was done)

Review 1 (refute-first, independent agent): no MUST. SHOULD 1 (the rescue route can be driven:
subst + denied listing) -> rows RESCUE-SHORT / RESCUE-LONG added. SHOULD 2 (FR-006 unproven by
the 310-byte row) -> row LONG200 added; it showed the old code's Desktop fallback. NOTE 1 (260+
unit Documents -> Desktop) -> Inbox; NOTE 2 (settings page compares with the drive root) -> the
rescue-path item's Notes; NOTE 3 (96 KB local in the key handler) accepted; NOTE 4 (no Release
build by the reviewer) recorded.

## Owed to a person (with the new person-step items)

- `confirm-ctrl-opens-a-long-documents-folder-whole-on-a-real` - Ctrl+; and Alt+F1 *Documents*
  with a long Documents folder (Debug seam) on a real keyboard.
- Add the CHANGELOG entry below (`CHANGELOG.md` has no `## [Unreleased]` section; versions are
  the maintainer's).

## CHANGELOG entry (to be added by a person - `CHANGELOG.md` has no `## [Unreleased]` section)

```markdown
- **The Documents drive could open another folder when the Documents folder has a long name in letters that need several bytes** (feature 386).
  - **Before:** with a Documents folder whose path needs more than 259 bytes inside the program (for example a folder named with 90 Chinese letters), the Documents button of the drive bar, *Documents* in the Alt+F1 / Alt+F2 menu and Ctrl+; opened the folder whose name is the first part of the real one - another folder, without a message; with a still longer one (about 520 bytes) they opened the Desktop. The "If the path is inaccessible, go to Documents" rescue path also went to the shortened folder.
  - **Now:** the Documents folder is opened whole. The rescue path, which can hold only 259 bytes, no longer goes to another folder: for such a Documents folder it goes to the root of the Windows drive.
  - **Limitation:** a Documents folder whose path is 260 characters or longer still opens the Desktop.
```

## New Inbox items (slug - title)

- `environment-variables-passed-to-the-program-arrive-as` - Environment variables passed to the program arrive as question marks outside the code page
- `rescue-path-goes-to-the-windows-drive-root-when-documents` - Rescue path goes to the Windows drive root when Documents needs more than 259 bytes
- `a-documents-folder-of-260-or-more-characters-opens-the` - A Documents folder of 260 or more characters opens the Desktop instead
- `confirm-ctrl-opens-a-long-documents-folder-whole-on-a-real` - Confirm Ctrl+; opens a long Documents folder whole on a real keyboard (person step)
