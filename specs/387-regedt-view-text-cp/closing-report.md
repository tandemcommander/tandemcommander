# Closing report - 387-regedt-view-text-cp
Backlog item: registry-editor-view-of-a-text-value-cut-text-and-a-stray - Registry Editor View of a text value: cut text and a stray byte on a UTF-8 code page
Outcome: closed

## What changed

- `src/common/salregfind.h`: `SalRegViewTextToCodePageAlloc` (counts the code-page bytes of all
  units with 278's `SalRegFindTextToCodePage`, allocates exactly that, converts whole) and
  `SalRegViewExportBytes` (the whole decision of the viewer's export: a text type with the switch
  on -> the converted copy and its count; another type, the switch off, a text that cannot be
  converted -> the data as stored; low memory -> nothing). Never a partial result.
- `src/plugins/regedt/fs3.cpp` `ExportValueData`: the value buffer is `size` bytes; the bytes
  written are those the rule returns; the copy is freed on every path; a short write of the
  temporary file is the existing write error (it was `WriteFile(...) || written != size`).
- `src/saltests/saltests.cpp`: `TestRegViewTextToCodePage387`.

## Measurements (before / after, commands)

- Before (main 477f01b1; python ctypes `WideCharToMultiByte` with the old sizing,
  `python -I %TEMP%\claude\repro_regview.py`): 65001 `a€\0` -> ret 0, `61 AA 00` (needs 5);
  65001 `čččč bar\0` -> ret 0, ` bar` lost (needs 13); 932 two hiragana + NUL -> ret 0, cut
  (needs 5); 1250 -> 9, whole.
- After: the rule produces 5 / 13 / 5 bytes with the full text, and 1250's 9 bytes unchanged
  (saltests); review 1's harness built the call-site code under an `activeCodePage=UTF-8`
  manifest (`GetACP()` = 65001) and the file held `61 E2 82 AC 00`, the 13 bytes and the whole
  REG_MULTI_SZ.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64). No UI strings changed: no `.slt` refresh,
  no `build.cmd full` needed.
- `saltests.exe` -> `saltests: 30724 checks, 0 failed` (30,699 before the feature).
- Mutations: the old unit sizing -> 5 failed; the converted length dropped in
  `SalRegViewExportBytes` -> 4 failed; both restored -> 0 failed.
- GUI probe: NOT DRIVEN - the machine's code page is 1250 (old = new bytes); owed to a person.

## Reviews (findings and what was done)

Review 1 (refute-first, independent): no MUST. SHOULD 1 (the call site had no automated proof)
-> the decision moved into the tested rule `SalRegViewExportBytes`, 11 checks + a mutation.
SHOULD 2 (the "negative control" rows only tested Windows; `old[1]` relied on undocumented
behaviour) -> relabelled as the defect's premise, the `old[1]` check removed. NOTE 1 (dead
`INT_MAX` guard) -> removed. NOTE 2 (UTF-16 fallback has no BOM) and NOTE 3 (`?` on single-byte
code pages, as before) accepted. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `registry-editor-view-confirm-f3-shows-a-whole-non-ascii-text` - F3 on a REG_SZ / REG_MULTI_SZ
  with non-ASCII text on a machine with the UTF-8 ANSI code page (can share the restart of the
  257 / 278 person steps).
- Add the CHANGELOG entry below (`CHANGELOG.md` has no `## [Unreleased]` section; versions and
  headings are the maintainer's):

  ```text
  - **Registry Editor: View (F3) of a text value showed a cut text with a garbage character on
    a UTF-8 or East Asian ANSI code page** (feature 387). A REG_SZ, REG_EXPAND_SZ or REG_MULTI_SZ
    value with a letter outside ASCII is now written to the viewer whole; a text that cannot be
    converted to the code page is shown as stored instead of as stale bytes, and a failed write
    of the viewer's temporary file is reported. On single-byte code pages nothing changes
    (letters the code page lacks still show as `?`).
  ```

## New Inbox items (slug - title)

- `registry-editor-view-a-key-that-cannot-be-opened-is-still` - Registry Editor View: a key that
  cannot be opened is still read with an unset handle (measure:387).
- `registry-editor-view-confirm-f3-shows-a-whole-non-ascii-text` - Registry Editor View: confirm
  F3 shows a whole non-ASCII text value on UTF-8 (person step, leftover:387).
