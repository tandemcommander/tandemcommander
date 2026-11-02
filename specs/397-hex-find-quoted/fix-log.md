# Fix log - 397 hex mode in Find keeps quoted letters outside the code page

Backlog item `hex-mode-in-find-turns-quoted-letters-outside-the-code-page` (source review:311).

## Before (HEAD 223d5a8e, main)

Build: `.\build.cmd` (Debug x64, incremental) - BUILD SUCCEEDED.

Probe `probe/hex397_probe.ps1` (new; driver of 311's probe on 098's library), run with
`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\397-hex-find-quoted\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\397-hex-find-quoted\probe\hex397_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`.
ACP 1250. Typing = `WM_CHAR` sent to the combo box's edit (runs edit -> `EN_UPDATE` ->
`CBN_EDITUPDATE` -> `DoHexValidation`, as a key press).

| Row | Result |
|---|---|
| grep-type | FAIL - the field `"?????" 41`, Find found 2 (the decoys `?????A`), not hit.txt |
| grep-group | PASS - `41424` -> `41 42 4`, caret 7 (behaviour to keep) |
| grep-mid | FAIL - `a` typed inside the quotes -> `"???a??" 41` |
| view-type | FAIL - `"?????" 41`, "Cannot find the string '"?????" 41'" |

Rows: PASS 5, FAIL 3 (END rows count as PASS); registry restored + identical.

First probe run had two probe bugs (no `$StartDir` of its own -> "Error Changing Directory" at
start and Alt+F3 found no window; expected caret 9 instead of 10 - the text is 10 units): fixed,
the run above is the second.

## Decisions (research.md)

- Work on UTF-16: the caret of `CB_GETEDITSEL` / `CB_SETEDITSEL` is in UTF-16 units.
- The rule moves unchanged (character type only) into `src/common/salhexfield.h`
  (`SalHexFieldTidyW`), plus: no space between the halves of a surrogate pair.
- Length: the whole field is read (`GetWindowTextLengthW`), buffer `max(len, textLen - 1) + 1`;
  insertions only while length < `textLen - 1` (the field's `CB_LIMITTEXT`, as before); never cut.
  The UTF-8 length is refused at OK by feature 311's `DlgItemTextFitsU8`.
- `char` is unsigned in this build (`/J` in `sal_base.props`), so `LowerCase[*s]` in
  `HistoryComboBox` / `ConvertHexToString` is safe for UTF-8 bytes.

## Implementation

- `src/common/salhexfield.h` (new): `SalHexFieldTidyW` - the old loop on `wchar_t`, insertions
  only while `len < maxLen` and `len + 1 < capacity`, the surrogate guard on the hex grouping.
- `src/viewer.cpp` `DoHexValidation`: `GetWindowTextLengthW`, heap buffer
  `max(len, textLen - 1) + 2`, `GetWindowTextW` (a read longer than the measured length leaves the
  field alone - never tidy a text that may be cut), the rule with `maxLen = textLen - 1`,
  `SetWindowTextW`; the caret by `SendMessageW(CB_GETEDITSEL / CB_SETEDITSEL)` (UTF-16 units
  without any doubt about an A/W translation of positions).
- `src/saltests/saltests.cpp` `TestHexFieldTidy397`: fixed cases, CJK / surrogate pairs inside
  quotes, a pair outside quotes not split, limit and capacity, refusals, and a brute force against
  a verbatim `char` copy of the old loop: every text of length 0..6 over `{' ', '"', '4', 'a'}`, every
  caret and the whole selection, limits 200 / len / len + 1 (>50,000 comparisons, 0 differ).
- First build failed: a variable named `small` (a macro of `rpcndr.h`) - renamed.

Callers (T005/T006, Grep `DoHexValidation|ConvertHexToString`): `src/finddlg1.cpp`
`CFindDialog::DialogProc` (`IDC_FIND_CONTAINING`, `CBN_EDITUPDATE`, `GREP_TEXT_LEN`) and
`src/viewer.cpp` `CFindSetDialog::DialogProc` (`IDC_FINDTEXT`, `FIND_TEXT_LEN`) - signature
unchanged, nothing to change; `ConvertHexToString` (`finddlg1.cpp` StartSearch, `viewer.h`
`InitFindDialog`) already copies quoted UTF-8 bytes; `src/plugins/regedt` has its own
`ConvertHexToString` (wide, unrelated).

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED.
- saltests -> `saltests: 282166 checks, 0 failed` (30,858 before; the brute force adds ~250,000).
- Negative control 1: surrogate guard removed -> 2 FAIL (section 3: `4` + pair + `1` split).
- Negative control 2: the opening-quote caret test `>` changed to `>=` -> 1 FAIL (`differ == 0`
  of the brute force). Header restored (byte-identical), rebuilt, 0 failed.
- Probe after: `probe/result_after.txt` - PASS 8, FAIL 0 (grep-type: the letters kept, caret 10,
  found 1 = hit.txt; grep-mid kept; view-type: no "Cannot find", Find again pre-fills the found
  selection `E4 B8 81 … 41`); registry restored + identical.
- Regression: 311's probe `probe/regress_311.txt` - PASS 26, FAIL 0.

## Inbox

- `hex-mode-not-hex-check-selects-the-wrong-characters-after` (measure:397): `HistoryComboBox`'s
  "not hex" selection uses a UTF-8 byte offset as a field position (research R6).

## Review

Review 1 (independent agent, refute-first, at 70b48f4f): no MUST, no SHOULD.
- Re-ran: saltests 282,166 / 0; encoding guard 0; probe 8 PASS / 0 FAIL. Negative control: the
  same probe against the installed 0.2.0 (same `DoHexValidation` as `main`) -> 5 PASS / 3 FAIL,
  matching `result_before.txt`.
- NOTE 1 (`viewer.cpp` includes not clang-format aligned after the new include) -> fixed
  (clang-format on `viewer.cpp`, and on the new saltests function only; the saltests include block
  is unformatted on `main` too, the new line follows its neighbours).
- NOTE 2 (an empty read with a measured length > 0 would clear the field) -> the read check is
  now `got < 0 || got != len` (the field is left alone).
- NOTE 3 (grep-type checks the count, not the name) - accepted: the before state finds 2 decoys,
  so count 1 distinguishes.
- NOTE 4 (real keyboard / IME typing not driven) -> person-step item
  `typed-check-of-hex-mode-quoted-letters-in-find-and-viewer`.
- NOTE 5 (67+ quoted CJK letters now exceed 200 bytes and are refused at OK - before they became
  one-byte `?`) - the intended refusal of 311, not a cut.
- NOTE 6 - the Inbox item for the selection offset confirmed.

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 282,166 / 0; encoding guard 0; probe
`result_after.txt` (label after-review) 8 PASS / 0 FAIL, registry restored + identical.

## Owed to a person

- `typed-check-of-hex-mode-quoted-letters-in-find-and-viewer` - typing with a real keyboard and IME.
