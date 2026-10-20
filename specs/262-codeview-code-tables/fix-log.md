# Fix log - 262 Code Viewer code tables

Backlog item `codeview-code-tables-for-single-byte-files` (070 review F16, FR-024).

## Measurement before (HEAD bf05ffc9, main)

- Site: `src/plugins/codeview/intake.cpp` `CvLoadFile` - `UINT codePage = CP_ACP;`, a forced
  `cvEncAnsi` also `CP_ACP`; `CvDecode` decodes `cvEncAnsi` with `MultiByteToWideChar(codePage)`.
  No call of `EnumConversionTables` / `GetConversionTable` in the plug-in.
- Menu: `viewer.cpp` `CViewerWindow` builds *Encoding* from a fixed five-entry array;
  `CycleEncoding` wraps modulo 5; `CM_ENCODING_FIRST + i < +5` in `WM_COMMAND`.
- Reachable: F3 on a `.bat` / `.ini` / source file opens the Code Viewer (default claimed types);
  a file without BOM that is not valid UTF-8 / UTF-16 takes the `cvEncAnsi` path.
- Machine: ACP 1250 (`[Text.Encoding]::Default.CodePage`, `HKLM\...\Nls\CodePage\ACP`).
- Reproduction (Python, the same decode the plug-in does with CP_ACP = 1250):
  `cp852.bat` first line as cp1250 -> "Pý˘lię §luśouźkě k…ĺ Łpŕl Ô belsk‚ ˘dy" (correct, cp852:
  "Příliš žluťoučký kůň úpěl ďábelské ódy"); `iso8859-2.ini` as cp1250 -> "Přílią ľlu»oučký kůň"
  (correct: "Příliš žluťoučký kůň").
- Built-in viewer (for parity): `CCodeTables::InitMenu` lists every table of the active
  `convert\<dir>\convert.cfg`; `SetCodeType` -> `CodeTable` applied to bytes, drawn with `TextOut`
  (A, ANSI font) = system code page; default conversion `Configuration.DefaultConvert` (*Set as
  default*), `CodePageAutoSelect` TRUE by default.

## Decisions

See spec *Clarifications* (autonomous run). Persisting the name: the plug-in registry facade is UTF-8
(`SalRegSetValueExW8`), so the code-page name is converted on save / load (research R3).

## Implementation

- `src/common/salcodetable.h` (new, header-only): `SalCodeTableApply` (in place), `SalCodeTableDisplayName`,
  `SalCodeTableCycle`, `SalCodeTableListPos` / `SalCodeTableFromPos` (list position <-> encoding /
  table), `SalCodeTableToUse` (which table a single-byte file gets), `SalCodeTableFindName` (byte-exact).
- `intake.*`: `CvLoadFile(name, forcedEncoding, ansiTable, forcedLanguage, out)`; the table is applied
  in place over the read buffer when the result is `cvEncAnsi`, then `CP_ACP` as before;
  `CvIntake::TableApplied`. With `ansiTable == NULL` the path is the old one (T012: `codePage` was
  always `CP_ACP`; the removed lines were a dead re-assignment).
- `viewer.*`: per-window table list from `EnumConversionTables` (lazy, `LoadCodeTables`), menu items
  `4005 + i` after a separator (separators collapsed), one check (`RefreshChecks`), the status bar names
  the table (CP_ACP-widened display name), `SelectEncoding(encoding, table)` keeps everything on a failed
  re-read, `CycleEncoding` over `5 + T`, `WM_COMMAND` via `SalCodeTableFromPos`; `OpenFile` applies the
  remembered table to a detected single-byte file.
- `codeview.*`: the remembered name behind `CvDefaultConvertCS`; a name that does not fit forgets
  instead of cutting.
- `config.cpp`: `DefaultConvert` REG_SZ, code page <-> UTF-16 <-> UTF-8 (no best fit, default-char
  check; failure = empty).
- Correction to the plan: shipped names are NOT all ASCII (`grep` hid the CP1250 lines of
  convert.cfg) - the active centeuro list has "Kameničtí - CP1250" second; the conversion handles it
  (probe NONASCII / NASAVED / NARESTART).

## Checks

- T001 generator: `python %TEMP%/tc-scratch/gen_tabs262.py convert/centeuro/c8521250.tab convert/centeuro/iso21250.tab`
  (self-check line: the CP852 corpus line through the table reads "Příliš žluťoučký kůň úpěl ďábelské ódy").
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `--draft`: no codeview / salcodetable hit.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64).
- saltests -> `saltests: 24659 checks, 0 failed`. Negative control: the CP852 line decoded with the
  ISO-8859-2 table -> `saltests: 24659 checks, 1 failed` (FAIL saltests.cpp(12018)), reverted.
- `src\plugins\codeview\test\run_tests.cmd` -> `RESULT: all codeview checks passed`.
- Probe `probe/cvtab262_probe.ps1` (hidden desktop, ACP 1250, registry restored + identical):
  - before (HEAD codeview sources, `git stash push -- src/plugins/codeview`, rebuilt): MENU FAIL
    ("Encoding menu 5 items"), SAVED FAIL (no value), RESTART FAIL (ANSI), NONASCII NOT DRIVEN (no
    table) - `probe/result_before.txt` (its END rows fail because the probe stops at MENU and leaves the
    viewer open).
  - after: PASS 15, FAIL 0, NOT DRIVEN 0 - `probe/result_after.txt`: menu 39 items, CP852 - CP1250 =
    4007 (after ISO-8859-2 and Kameničtí), choose / F8 / Shift+F8 / remember / UTF-8 unchanged /
    saved / restart / forget, the non-ASCII name stored and read back exactly.
  - a first after-run with ids assumed from the repository's convert.cfg failed 6 rows on the
    assumption (4006 is "Kameničtí - CP1250") - the probe now finds the items by name.

## Review

Review 1 (independent agent, refute-first, at 5875847e): no MUST. Re-ran the decode (tables =
shipped files byte for byte), build, saltests 24659 / 0, guard 0, probe 15 / 0 / 0; callers of
`CvLoadFile`: `OpenFile` and `SelectEncoding` only; no data-loss path (read-only viewer; in-place
table pass over the read buffer; a failed re-read keeps view, encoding and remembered table).

- S1 (SHOULD, fixed): F8 / Shift+F8 went through `SelectEncoding` and stored the remembered table on
  every step - one Shift+F8 on a UTF-8 file wrapped to "ANSI - OEM" and every later CP1250 file opened
  through it, also after a restart (the reviewer's scratch probe stored 'ANSI - OEM'); F8 past
  *System code page* also forgot a remembered table. Fix: `SelectEncoding(encoding, table, remember)`;
  only the menu command remembers, `CycleEncoding` passes FALSE (spec FR-003 / FR-004 and a
  Clarification updated, contract updated). Probe row KEEP added: Shift+F8 on b_utf8.cpp -> "ANSI -
  OEM", a_cp852.bat reopened -> still "CP852 - CP1250" - PASS; the pre-fix build is the reviewer's
  reproduction (stored 'ANSI - OEM'). After the fix: build SUCCEEDED, probe PASS 16 / FAIL 0 /
  NOT DRIVEN 0, guard TOTAL 0.
- NOTE 1: the letters are proven by saltests on the pure table pass + reading `CvLoadFile`, not by a
  test that runs `CvLoadFile` (the status bar is driven by `TableApplied`). Accepted; the person step
  reads the letters.
- NOTE 2: menu and status bar widen table names with the system code page (`AppendMenuA`); the
  built-in viewer uses `SalInsertMenuItemU8` (UTF-8 when the name is valid UTF-8). The shipped
  convert.cfg files give the same result; only a user-edited UTF-8 convert.cfg with non-ASCII names
  would differ. Recorded as a limit.
- NOTE 3: on a machine with the UTF-8 system code page (65001) the converted bytes decode to U+FFFD and
  a non-ASCII name is not stored - the built-in viewer is limited the same way. Recorded as a limit.
- NOTE 4: the tables are first loaded on the viewer thread at window creation (a broken convert.cfg
  would show its error box there); no deadlock (own thread, own parent). Accepted.
- NOTE 5: bookkeeping (leftover item, CHANGELOG, FEATURE-HISTORY) - done at closing.
- NOTE 6: the *CP1250 - Cork* table maps the backtick to 0x00 - a NUL can appear in the decoded text;
  the copy path is length-driven. Accepted.

No MUST -> no second review required (SKILL.md step 7).

## NOT DRIVEN (owed to a person)

- The decoded letters themselves: they are rendered in the WebView2 page, which no probe reads. The
  status bar, menu and settings are driven; the decode is the same function saltests checks on the same
  bytes. A person opens cp852.bat and reads "Příliš žluťoučký kůň úpěl ďábelské ódy".
- F8 / Shift+F8 pressed on the real keyboard inside the page (the probe posts the commands 3990 / 3991
  that the keys map to).

## speckit-analyze

- Run 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (FR-010 not explicit in tasks), C2 (no-tables case implied),
  LOW I1 (separator collapsing), U1 (settings persist when the core saves its configuration).
  Fixed C1, C2, I1 in tasks.md / spec.md.
- Run 2: 0 CRITICAL, 0 HIGH, 0 MEDIUM; U1 accepted (the same as every other codeview setting).
