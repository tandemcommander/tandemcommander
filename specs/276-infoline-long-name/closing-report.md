# Closing report - 276-infoline-long-name
Backlog item: focusing-an-archive-member-with-a-very-long-name-shows - Focusing an archive member with a very long name shows "Expanded string is too large." twice
Outcome: closed

## What changed

- `src/fileswn2.cpp` `CFilesWindow::ItemFocused`: the core's Information Line expansion is tried
  in the 1000-byte stack buffer first and, when it does not fit, repeated into a heap buffer that
  doubles up to 65,535 bytes; attempts before the last pass no parent window (no box), the last
  one reports as before. The plug-in route (`GetInfoLineContent`, 1000 bytes by contract) is
  unchanged.
- `src/common/salinfolinebuf.h` (new): `SAL_INFOLINE_FIRST_LEN`, `SAL_INFOLINE_MAX_LEN`,
  `SalInfoLineNextLen` - the growth rule.
- `src/saltests/saltests.cpp`: `TestInfoLineBuf276` (28 checks).
- `CHANGELOG.md` (0.1.11 unreleased): a new entry; feature 275's limitation about this box
  removed.

## Measurements (before / after, commands)

Cause: the default content `$(FileName): ..., $(FileDOSName)` names the item twice when it has no
short name (archive members; disk volumes without 8.3 names); a 604-byte name needs more than
1000 bytes.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\276-infoline-long-name\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\276-infoline-long-name\probe\infoline276_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (main de31d72a build): 16 PASS / 7 FAIL - ARCCAP (604 bytes), ARCMAX (757), ARCDEEP
  (604 in a folder) one box and the information line unchanged; WIDTH box; BADSYNTAX / OVERCAP one
  box each (kept). First version of the probe: 13 / 4 (`result_before_v1.txt`).
- After: 23 PASS / 0 FAIL / 0 NOT DRIVEN.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED (no warnings in the touched files)
- `saltests.exe` -> saltests: 24887 checks, 0 failed; negative control (bound 1000) -> 6 failed
- Probe 276: 16 / 7 -> 23 / 0; regressions: 260's probe 16 / 0, 275's probe 17 / 0

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST, no SHOULD; NOTEs - check count corrected; clang-format spacing
fixed (rebuilt, saltests 0 failed); unit tests cover the rule only and WIDTH / hot texts by
reading - accepted; a pre-existing use-after-free in `CStatusWindow::SetText` under low memory -
Inbox item. Details in `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `information-line-of-a-long-named-item-check-it-on-screen-276` - read the information line of a
  long-named archive member on screen, copy its hot texts, and the disk case on a volume without
  8.3 names (needs an administrator to set up).

## New Inbox items (slug - title)

- `the-information-line-keeps-using-a-freed-text-when-memory` - The information line keeps using a
  freed text when memory runs out as it grows
- `information-line-of-a-long-named-item-check-it-on-screen-276` - Information line of a
  long-named item: check it on screen (276)
