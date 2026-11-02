# Closing report - 398-viewer-find-seed
Backlog item: viewer-find-pre-fills-a-non-ascii-selection-as-code-page - Viewer Find pre-fills a non-ASCII selection as code-page text
Outcome: closed

## What changed

- `src/common/salfindseed.h` (new): `SalFindSeedDecodeW` - decodes the selected bytes by the viewer's
  content encoding (UTF-8, UTF-16 LE/BE, the ANSI code page; a UTF-8 code page as UTF-8) and keeps the
  longest whole-character beginning within 200 UTF-16 units and 200 UTF-8 bytes; an incomplete
  character is left out at the read limit, U+FFFD at the end of the selection; NUL ends the text.
- `src/viewer.cpp` `CFindSetDialog::Transfer`: the pre-fill is set as wide text (`SetWindowTextW`) from
  the seed; hex mode unchanged (the first 66 bytes as hex digits).
- `src/viewer.h` / `src/viewer2.cpp`: `GetFindText(buf, bufSize, len)` (402 bytes read now),
  `GetContentEncoding()`.
- `src/saltests/saltests.cpp`: `TestFindSeed398`.

## Measurements (before / after, commands)

Probe `specs/398-viewer-find-seed/probe/seed398_probe.ps1` through `tools\run_on_hidden_desktop.ps1`
(Debug build, ACP 1250):
- before (main 58dcca07): PASS 8 / FAIL 4 - `café` pre-filled `cafĂ©` and "Cannot find"; 199 `a` + `é…`,
  70 CJK letters, 198 `a` + U+1F600 refused at OK with "The path specified is too long.".
- after: PASS 14 / FAIL 0 - `café` found; 199 `a`; 66 CJK letters (198 bytes); 198 `a` - nothing asked;
  code page `café au lait` pre-filled as before; `caf` + E9 file -> `caf` + U+FFFD; hex `63 61 66 C3 A9`.
  Registry restored with an identical hash every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no UI strings changed: no `build.cmd full`, no `.slt` refresh).
- saltests: 282,230 checks, 0 failed; negative controls: old decoding 28 failed, no 65001 redirect 2 failed.
- Probes: 398's 14 / 0; regressions 397's 8 / 0, 311's 26 / 0.

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST. SHOULD 1 (code-page content under ANSI code page 65001 became U+FFFD)
fixed; SHOULD 2 (detection takes a short code-page file ending in a non-ASCII letter for UTF-8) -> Inbox;
NOTEs 3 and 5 fixed (wording), 4, 6, 7 no change (reasons in `fix-log.md`, *Review*).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (no `## [Unreleased]` section exists; versions are the maintainer's):

  ```text
  - **The viewer's Find showed a selected word with accented letters as garbage and could not find it** (feature 398).
    - **Before:** with text selected in the internal viewer, Find was pre-filled with the selection's raw bytes read in the system code page: in a UTF-8 file `café` appeared as `cafĂ©` and Find answered "Cannot find the string"; a longer selection with such letters, Chinese letters or an emoji was refused with "The path specified is too long." although nothing was typed.
    - **Now:** the Find field shows the selection as the viewer shows it, and a selected word of a UTF-8 file is found. A selection longer than the field holds (200 characters, or 200 bytes in UTF-8) is shortened to its beginning, at a whole letter, before it is shown.
    - **Limitation:** in a file the viewer shows in a code page (not UTF-8), a word with accented letters is shown correctly in the field but still not found by Find (use Hex search); this is recorded for a later fix.
  ```

No person-step item: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- viewer-find-does-not-find-non-ascii-text-in-a-file-shown-in - Viewer Find does not find non-ASCII text in a file shown in a code page
- viewer-shows-a-short-code-page-file-ending-in-a-non-ascii - Viewer shows a short code-page file ending in a non-ASCII letter as UTF-8
