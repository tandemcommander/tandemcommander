# Closing report - 259-long-name-refusals
Backlog item: core-long-name-wrong-refusals - Long names: Paste "- Copy" says "to itself"; IsSimpleSelection uses CP_ACP
Outcome: closed

## What changed

- **Paste into the item's own folder**: the "- Copy" name is built whole by the new header-only rule
  `src/common/salcopyname.h` (`SalMakeCopyNameU8`, the Explorer-style rule ported unchanged) and
  judged by 255 UTF-16 units. A name over the limit (or a full path over `SAL_MAX_PATH_UTF8`) gets
  BuildName's "name is too long" question (Skip / Skip all / Focus / Cancel); the copy never
  targets its source ("Cannot copy a file to itself." is gone for this case). `fileswn6.cpp`
  `BuildScriptMain2`; the pre-Vista patterns flag "too long" too and cannot write past `targetPath`.
- **Edit New File** (`fileswn5.cpp` `EditNewFile`): paths up to `SAL_MAX_PATH_UTF8`, relative or
  absolute; a name over 255 UTF-16 units -> "Cannot finish operation because of too long name."
- **IsSimpleSelection** (`shellib.cpp`): no CP_ACP conversion, no raw code-page bytes, no cut; a
  failed conversion refuses the selection; a too long source folder sets the new
  `CDragDropOperData::SrcPathTooLong` (`shellib.h`) and `DragDropToArcOrFS` (`fileswna.cpp`) says
  "The path specified is too long.".
- saltests `TestCopyName259` (29 checks). No new UI string, no plug-in interface change.

## Measurements (before / after, commands)

- Probe (hidden desktop): `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\259-long-name-refusals\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\259-long-name-refusals\probe\editnew259_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`
  - before (7a13bdee): 7 PASS / 3 FAIL - REL, ABS, CJK refused "The path specified is too long."
  - after (final): 14 PASS / 0 FAIL - SHORT, REL, ABS, CJK, U255 created; OVER, U256 refused with
    "too long name"; registry restored identical (SHA-256 CBAC630F...).
- Paste and IsSimpleSelection: by reading (clipboard not driven; the changed IsSimpleSelection
  routes are reached only on low memory or by a crafted drop list).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests`: 24,544 checks, 0 failed. Negative control (the rule's limit replaced by the old
  `strlen >= MAX_PATH`): 5 failed; the reviewer's control (255 -> 256 units): 2 failed.
- Probe `editnew259_probe.ps1`: 7 / 3 -> 14 / 0. An intermediate run (8 / 2) found that Windows
  answers "invalid name" for a 256-unit name (the explicit check was added) and a probe defect
  (shared folder).

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD: the Paste symptom has no runtime evidence -> person
step; the CP_ACP fallback of `CCopyMoveRecord::AllocChars` on the Paste route -> Inbox; the OVER
row accepted the old wrong message -> requires "too long name", rows U255 / U256 added. NOTEs: the
"never shorter" claim (leading zeros) reworded and pinned by a check; stale `shellib.h` comments
updated; the rest accepted (see `fix-log.md` *Review*).

## Owed to a person (with the new person-step items)

- `paste-of-a-long-name-into-its-own-folder-check-the-copy-name` - Ctrl+C / Ctrl+V of an 84-letter
  CJK name, a 250-letter name and both together (Skip) in their own folder, and a short control.

## New Inbox items (slug - title)

- `paste-of-a-long-name-into-its-own-folder-check-the-copy-name` - Paste of a long name into its own folder: check the copy name and the too long question (person step)
- `paste-and-drop-of-our-own-files-keep-a-code-page-fallback` - Paste and drop of our own files keep a code-page fallback for a name on low memory
- `create-directory-refuses-a-relative-name-in-a-folder-whose` - Create Directory refuses a relative name in a folder whose path is 260+ bytes
