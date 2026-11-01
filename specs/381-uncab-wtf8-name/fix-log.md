# Fix log - 381-uncab-wtf8-name

Backlog item `uncab-wtf8-flagged-name-refused` - UnCAB: one UTF-8 cabinet name with an unpaired
surrogate makes the whole cabinet fail. HEAD at the start: `bd7cc15e` (main).

## Measurement before (step 3, at bd7cc15e)

- Site: `src/plugins/uncab/uncab.cpp` `CabNameToU8` - `validU8 = MultiByteToWideChar(CP_UTF8,
  MB_ERR_INVALID_CHARS, ...) > 0`; flagged (`_A_NAME_IS_UTF`) and `!validU8` -> FALSE. Callers:
  `Notify` `fdintCOPY_FILE` (flags from FDI), `fdintPARTIAL_FILE` (-1, guessed), `fdintCABINET_INFO`
  and `fdintNEXT_CABINET` (0, code page). A FALSE from COPY_FILE / PARTIAL_FILE returns -1 ->
  `FDICopy` aborts with `FDIERROR_USER_ABORT`.
- Reachable: Enter on a `.cab` (ListArchive), Alt+F9 Unpack (UnpackWholeArchive), F5 from the
  archive (UnpackArchive) - UnCAB is `on` in `plugins.cfg`, `.cab` is its association.
- Fixture: `probe/cab381.py` - a stored MS-CAB writer (one folder, CFDATA checksum as libmspack).
  Validated with Windows `expand.exe -D ok.cab` (lists `aé.txt`, `c.txt`) and `expand ok.cab -F:* x`
  (both files, contents `N1`, `C1`).
- Probe: `probe/cab381_probe.ps1` on the hidden desktop, Debug x64 build of bd7cc15e
  (`build.cmd`, BUILD SUCCEEDED):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\381-uncab-wtf8-name\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\381-uncab-wtf8-name\probe\cab381_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
  ```

  `result_before.txt`: PASS 14, FAIL 4 - U-WTF8, U-WTF8L (nothing extracted, not even `c.txt`;
  cabinet kept; no window) and L-WTF8, L-WTF8L (Enter leaves the panel in `src`; no window).
  Controls U-OK / L-OK PASS; refused U-BAD, U-OVER, L-BAD PASS (silent refusal). Registry restored,
  identical (SHA-256 0014109...).
- `result_before0.txt`: the first run, whose refusal rows still expected an error window (the item
  says "shows an FDI error"); they failed only on that expectation - **correction to the item: the
  refusal is silent** (`FDIError(FDIERROR_USER_ABORT)` shows nothing). The rows were changed to the
  measured behaviour; the silence is a separate defect (Inbox item, below).
- `python tools/check_encoding.py --plugins`: `[strict-probe-rejects-wtf8] 6 finding(s)`, one of them
  `plugins/uncab/uncab.cpp:211`; TOTAL 17.

## Decisions

- The rule (as UTF-8 / code page / refuse) goes into the header-only `src/plugins/uncab/cabname.h`,
  its validity test into `SplIsWtf8` in `src/plugins/shared/splunicode.h` (the feature 089 decoder);
  saltests checks both (stop-rules §2.5).
- The unflagged guess (`fdintPARTIAL_FILE`) also accepts WTF-8 (spec Clarification 1, item's Approach).
- Analyze: 0 CRITICAL / 0 HIGH. Accepted: C1 (FR-003 covered by the attribs-0 vectors, call sites
  unchanged), C2 (the too-long refusal is unchanged code, not re-tested), D1 (CHANGELOG /
  FEATURE-HISTORY are done at closing, step 8).

## Implementation

- `src/plugins/shared/splunicode.h`: `SplIsWtf8(s)` = `SplUnicodeDetail::Wtf8ToW(s, NULL, 0) > 0`
  (the feature 089 decoder; NULL -> FALSE).
- `src/plugins/uncab/cabname.h` (new, header-only, UTF-8-BOM, CRLF): `CabNameReadAs(name, attribs)` ->
  `CABNAME_UTF8` / `CABNAME_CODEPAGE` / `CABNAME_REFUSE`; listed in `uncab.vcxproj` (+ filters).
- `src/plugins/uncab/uncab.cpp` `CabNameToU8`: decides by `CabNameReadAs`; the verbatim copy, the
  `lstrlen >= bufSize` refusal and the code-page branch are unchanged;
  `static_assert(CABNAME_A_NAME_IS_UTF == _A_NAME_IS_UTF)`. The strict `MB_ERR_INVALID_CHARS` probe is
  gone from the plug-in.
- `src/saltests/saltests.cpp` `TestCabName381`: 10 accepted and 12 malformed vectors through
  `SplIsWtf8`, `CabNameReadAs` (flagged, guessed, unflagged) and `SplU8ToWAlloc`; the item's name
  decodes to `a<U+D800>.txt`; exhaustive over all 16,646,655 strings of 1-3 non-NUL bytes:
  `SplIsWtf8` == the core's `SalU8ToW` acceptance (0 disagreements), contains strict UTF-8
  (0 rejected), adds exactly 2,048 strings, all `ED A0..BF 80..BF`. (The strict reference call in the
  test carries an `encoding-check: allow` marker.)

## Measurements after

- `.\build.cmd` -> BUILD SUCCEEDED (splunicode.h rebuilt every plug-in; no new warning in the changed
  files).
- `saltests.exe` -> `saltests: 30401 checks, 0 failed` (about 15 s, including the exhaustive loop).
  First run: 1 failure in my own vector (expected 7 code units, the count includes the terminator) -
  the expectation fixed, not the code.
- Negative control: `CabNameReadAs` temporarily on the strict probe (`MultiByteToWideChar(CP_UTF8,
  MB_ERR_INVALID_CHARS)`), rebuilt -> `saltests: 30401 checks, 10 failed` (the 5 surrogate vectors x
  flagged / guessed); restored, rebuilt -> 0 failed.
- Probe after (`probe/result_after.txt`, same command, `-Label after`): **PASS 18, FAIL 0** - U-WTF8
  extracts `a\uD800b.txt` + `c.txt` and deletes the cabinet, U-WTF8L `a\uDC00b.txt` + `c.txt`;
  L-WTF8 / L-WTF8L open the cabinet; U-OK / L-OK as before; U-BAD / U-OVER / L-BAD still refused
  (silently, as before). Registry restored, identical (SHA-256 0014109...).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `python tools/check_encoding.py --plugins` -> TOTAL 17 -> 16; `strict-probe-rejects-wtf8` 6 -> 5,
  no `uncab/uncab.cpp` line.
- clang-format (VS x64 clang-format, `--style=file`): `cabname.h`, `uncab.cpp` clean; the changed
  lines of `splunicode.h` and `saltests.cpp` clean (the rest of those files has older drift, untouched).
- No UI string, menu or dialog changed -> no `.slt` refresh.

## Review

Review 1 (independent agent, refute-first): **no MUST, no SHOULD.** It rebuilt, re-ran saltests
(30401 / 0), both scans (strict 0; plug-ins 16, no UnCAB line) and the probe (18 / 0, registry
identical); negative control: the old `uncab.spl` built from `main` in its own worktree and build
folder, same probe -> 14 / 4 with exactly U-WTF8, U-WTF8L, L-WTF8, L-WTF8L failing. Its own extra
probe (12 / 0): F5 of the surrogate entry from inside the cabinet, F5 of one of `ab.txt` /
`a<U+D800>b.txt` / `c.txt` (no confusion - `CompareStringW` tells them apart), F3 on the surrogate
entry, a CESU-8 pair next to its 4-byte form (one name -> the overwrite question, nothing replaced
silently), a refused entry after a good one (`c.txt` out, cabinet kept). All four `CabNameToU8`
callers checked; "delete after unpacking" keeps the cabinet whenever `FDICopy` fails.

- NOTE 1 (comments said "valid WTF-8"; the decoder also reads a pair written as two 3-byte
  sequences, CESU-8 style, as the core does): **fixed** - the comments of `SplIsWtf8` and
  `cabname.h` say so; `TestCabName381` gained a CESU-8 vector (accepted, decodes to the same
  U+D83D U+DE00 as the 4-byte form and as the core's `SalU8ToW`). Rebuilt: BUILD SUCCEEDED,
  `saltests: 30404 checks, 0 failed`, strict scan 0, clang-format clean on the changed lines. The
  plug-in change is comment-only, so the probe result stands.
- NOTE 2 (the unflagged guess accepts `ED A0..BF 80..BF` code-page bytes as a surrogate): accepted -
  spec Clarification 1 (the item's Approach; keeps a continued entry's name equal to its start).
- NOTE 3 (refusal still silent, extraction stops part-way): out of scope, Inbox item
  `uncab-a-cabinet-whose-entry-name-is-refused-fails-without` (written before the review).
- NOTE 4 (six old review worktrees under `%TEMP%\rev3xx\neg` from earlier sessions): not this
  feature's; named in the closing report for the maintainer.
