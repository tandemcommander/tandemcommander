# Closing report - 397-hex-find-quoted
Backlog item: hex-mode-in-find-turns-quoted-letters-outside-the-code-page - Hex mode in Find turns quoted letters outside the code page into question marks
Outcome: closed

## What changed

- `src/common/salhexfield.h` (new): `SalHexFieldTidyW`, the tidying of a hex-mode field (the loop
  of `DoHexValidation` before 397, on `wchar_t`, caret in UTF-16 units; no space inside a surrogate
  pair; insertions only below the field's limit and inside the buffer).
- `src/viewer.cpp` `DoHexValidation`: reads the whole field as UTF-16 (`GetWindowTextLengthW` /
  `GetWindowTextW`, heap buffer), runs the rule, writes back with `SetWindowTextW`, caret through
  `SendMessageW(CB_GETEDITSEL / CB_SETEDITSEL)`; a read that does not match the measured length
  leaves the field alone. Both callers (Find's Containing, the viewer's Find) unchanged.
- `src/saltests/saltests.cpp`: `TestHexFieldTidy397`.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\397-hex-find-quoted\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\397-hex-find-quoted\probe\hex397_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"` (ACP 1250)

| Row | Before (223d5a8e) | After |
|---|---|---|
| grep-type | `"?????" 41`, found 2 decoys - FAIL | letters kept, caret 10, found 1 - PASS |
| grep-group | `41 42 4`, caret 7 - PASS | the same - PASS |
| grep-mid | `"???a??" 41` - FAIL | `"丁丂七a丄丅" 41`, caret 5 - PASS |
| view-type | "Cannot find the string" - FAIL | found, selection `E4 B8 81 … 41` - PASS |

Totals: 5 PASS / 3 FAIL -> 8 PASS / 0 FAIL; registry restored + identical in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` -> BUILD SUCCEEDED (no UI string, resource or plug-in list changed: no `full`, no `.slt` refresh)
- saltests -> `saltests: 282166 checks, 0 failed`; negative controls: surrogate guard removed -> 2 failed; one caret comparison changed -> 1 failed (brute force)
- 311 regression probe -> 26 PASS / 0 FAIL (`probe/regress_311.txt`)

## Reviews (findings and what was done)

Review 1: no MUST, no SHOULD. Its negative control (the probe against the installed 0.2.0) 5 / 3.
NOTE 1 clang-format alignment - fixed; NOTE 2 empty read - guarded (`got != len`); NOTE 3 accepted
(count distinguishes); NOTE 4 IME typing -> person step; NOTE 5 the 311 refusal, intended; NOTE 6
Inbox item confirmed. Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `typed-check-of-hex-mode-quoted-letters-in-find-and-viewer` - typing with a real keyboard / IME.
- The CHANGELOG entry: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's); add this entry under the next version's heading:

  - **Hex search turned letters outside the system code page into question marks** (feature 397).
    With *Hex* ticked, Find's *Containing* field and the viewer's *Find* field changed quoted
    letters the system code page does not have (Chinese, Japanese, Greek on a Czech system, …) into
    `?` at the first key typed, and the search then looked for `?` bytes. The letters now stay as
    typed and are searched as their UTF-8 bytes; the help with spacing hex digits works as before.
    Limitation: a quoted text longer than 200 bytes in UTF-8 (about 67 Chinese letters) is refused
    at OK, as every Find text is since feature 311.

## New Inbox items (slug - title)

- `hex-mode-not-hex-check-selects-the-wrong-characters-after` - Hex-mode "not hex" check selects the wrong characters after non-ASCII text
- `typed-check-of-hex-mode-quoted-letters-in-find-and-viewer` - Typed check of hex-mode quoted letters in Find and viewer Find (feature 397)
