# Closing report - 390-regedt-hkcr-move-user
Backlog item: registry-editor-move-from-hkcr-to-user-classes-does-nothing - Registry Editor: Move from HKCR into the user's Classes key does nothing
Outcome: closed

## What changed

- `src/plugins/regedt/fs5.cpp` `CopyOrMoveKeyRec`: for a Move whose source root is
  `HKEY_CLASSES_ROOT`, before anything of the key is opened or written, `GetHkcrHalves` notes which
  halves hold it (`HKLM` / `HKCU` `Software\Classes\<path>`; not found = not held, access denied =
  held, other errors = the existing open-error box, fails closed). At the end of the key, the one
  half that held it is deleted by its real path (`SafeDeleteHkcrHalf`, the existing "Unable to
  remove the original registry key." box naming `HKEY_LOCAL_MACHINE\Software\Classes\...`); a key
  held by both halves keeps the delete through HKCR.
- `src/common/salregkeyid.h`: pure rule `SalRegHkcrDeleteHalf`, `SalRegJoinClassesPath` (refused
  when too long, never cut); `src/saltests/saltests.cpp`: `TestRegHkcrHalf390` (15 checks).
- No UI string, menu or dialog changed; no `.slt` refresh; no plug-in ABI change.
- Probe `specs/390-regedt-hkcr-move-user/probe/hkcr390_probe.ps1` (new: MACHUSER, MACHUSERU,
  USERMOVE, USERCLS; only reads a real machine-only extension key and removes its user copy; never
  elevated).

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\390-regedt-hkcr-move-user\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\390-regedt-hkcr-move-user\probe\hkcr390_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\390-regedt-hkcr-move-user\probe\hkcr390_<label>.txt"
```

- Before (main at 129136b4, `hkcr390_before.txt`): MACHUSER / MACHUSERU FAIL - F6 of the
  machine-only `HKEY_CLASSES_ROOT\.386` into `\HKEY_CURRENT_USER\Software\Classes\` (and
  `\HKEY_USERS\<SID>_Classes\`): no box, the user's copy deleted again, the machine key unchanged.
- After (`hkcr390_after_review.txt`, final binary): **10 PASS / 0 FAIL** - the box "Unable to remove
  the original registry key. (5)" naming `HKEY_LOCAL_MACHINE\Software\Classes\.386\PersistentHandler`,
  the user's copy equal to the machine key, the machine key unchanged; controls moved whole.
- Negative control (reviewer: `fs5.cpp` of `main` built in a worktree): 6 PASS / 4 FAIL.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: BUILD SUCCEEDED (only the old C4267 warnings of `fs2.cpp`).
- `saltests`: `30755 checks, 0 failed` (30,740 before).
- Probes on the final binary: 390 English 10 / 0, Czech 10 / 0; 292's 33 / 0; 294's 24 / 0;
  296's 47 / 0; 297's 40 / 0; registry restored identical every time.

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD 1 (the elevated Move owed to a person, no item) - person
step created. NOTE 1 (a half whose key denies listing stopped the Move) - fixed: access denied
counts as held (the reviewer's "open with no access right" is refused by Windows - the probe
caught it, 4 / 6). NOTE 2 (a key of both halves keeps a partial delete) - Inbox. NOTE 3-6 recorded
in `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `registry-editor-390-elevated-hkcr-move-check` - the elevated Move (the key ends in the user's
  half and is gone from the machine's).
- `CHANGELOG.md` has no `## [Unreleased]` section (the tree is at the 0.2.0 release): add the entry
  below when the next section is opened.

```text
- **Registry Editor: moving a key from HKEY_CLASSES_ROOT into the user's Classes key did nothing** (feature 390).
  - **Before:** moving (F6) a key that HKEY_CLASSES_ROOT shows only from the machine's settings into \HKEY_CURRENT_USER\Software\Classes\ made a copy for the user and then deleted that copy again instead of the original. No message appeared and nothing changed, although the move seemed to succeed.
  - **Now:** after the copy, the original is deleted where it really is (HKEY_LOCAL_MACHINE\Software\Classes). Without administrator rights Windows refuses that, and "Unable to remove the original registry key." says so; the user's copy stays. With administrator rights the key is moved.
  - **Limitation:** a key that exists for both the machine and the user is still removed only from the user's part when moved elsewhere.
```

## New Inbox items (slug - title)

- `registry-editor-390-elevated-hkcr-move-check` - Registry Editor 390: elevated check of Move from HKCR into the user Classes key (person step)
- `registry-editor-hkcr-move-both-halves-leaves-machine-half` - Registry Editor: Move of an HKCR key held by both halves leaves its machine half
