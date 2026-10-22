# Fix log - 311 Find's Containing text and the viewer's Find text are never cut

Backlog item `find-cuts-a-long-containing-text-and-writes-the-cut-text` (source `review:291`).

## Measurement before (main at 95145b44, Debug x64 build of HEAD)

`build.cmd` (up to date), then the probe on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\311-find-containing-cut\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\311-find-containing-cut\probe\grep311_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

Fixture `%TEMP%\tc311_grep\find`: `cut.txt` = 66 CJK letters + `ZZ`, `full.txt` = 67 CJK letters,
`other.txt`; C66 = 198 bytes, C67 = 201 bytes (the buffer holds 200 + NUL).

Result (`probe/result_before.txt`): PASS 13, FAIL 9 - every refusal row FAILS, both controls PASS:
- `grep` (C67): nothing asked, **found 2**, the field afterwards 66 letters (cut written back).
- `grep-regex` (C66 + `ZZQ`): found 1, the field cut to 200 bytes. `grep-hex` (`"C66" 5A 5A`, 206
  bytes): found 2, field cut to the quoted part.
- `grep-add`, `grep-manage` (the Settings Manager showed the cut Containing), `grep-ignore`: the
  field written back cut.
- `grep-option`: the stored option without Containing left the field cut (66 letters), Find found 2.
- `view-find`: the viewer's Find with C67 closed with no "cannot find" - searched C66, which the
  file holds.
- `view-copy`: after a Find, Containing changed to C67 and the result viewed with Alt+F3: the
  viewer's Find field held the cut 66 letters (copied by `UpdateInternalViewerData` through the core
  `CTransferInfo::EditLine`, which cuts at a whole character).
- Controls `grep-ctl` (C66 + `Z`, 199 bytes: found 1, field whole) and `view-ctl` PASS.

Probe history: the first draft opened the viewer with F3, which on `.txt` is the Code Viewer
plug-in (CM_FINDSET opened nothing) - the viewer rows use Alt+F3 (CM_ALTVIEW) and assert the
window class `Salamander's Viewer Window`.

## Consumers (fix protocol)

- `CFindDialog` (core, `finddlg1.cpp`): opened only by `find.cpp`; `TransferData(ttDataFromWindow)`
  at the three `ValidateData()`-guarded starts (Find / Find Now / Find Duplicates, Append /
  Subtract / Intersect) and in `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE`;
  `LoadControls` only from `CM_FIND_OPTIONS_FIRST..`; `UpdateInternalViewerData` from `OnViewFile`
  (View / Alt View) and `OnViewFileWith`.
- `CFindSetDialog` (`viewer.h`): executed only by the viewer (`viewer3.cpp`, `CM_FINDSET` and
  Find Next / Prev without a text); `GlobalFindDialog` is data only. The plug-ins `codeview` and
  `mdview` have their own `viewer.h`.
- Stored values: registry load (`find.cpp`, `mainwnd2.cpp`) and settings import (`cfgimport.cpp`,
  refuses too long) read at most the buffer - unchanged.

## Change

- `src/finddlg1.cpp` `CFindDialog::Validate`: after 291's Named check,
  `DlgItemTextFitsU8(HWindow, IDC_FIND_CONTAINING, &ti, GREP_TEXT_LEN)` - covers every search start
  and every mode (plain, regular expression, hex).
- `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE`: the same check (NULL ti) after Named,
  before `TransferData(ttDataFromWindow)`.
- `CFindDialog::LoadControls`: `keepGrep` as 291's `keepNamed` (whole text taken before `Data`
  changes, put back after the transfer; no memory -> nothing loaded, `keepNamed` freed); the
  "expand when Containing has text" test also counts the kept text.
- `CFindDialog::UpdateInternalViewerData`: no copy into the viewer's Find when the field does not
  fit `FIND_TEXT_LEN` (`SalWindowTextFitsU8`; the core `CTransferInfo::EditLine` would cut).
- `src/viewer.h` / `src/viewer.cpp`: `CFindSetDialog::Validate` -
  `DlgItemTextFitsU8(HWindow, IDC_FINDTEXT, &ti, FIND_TEXT_LEN)`; `viewer.cpp` includes `dialogs.h`.
No new string, no plug-in interface change, no stored size changed.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `build.cmd` -> `BUILD SUCCEEDED` (no new warning in the touched files).
- `saltests.exe` -> `saltests: 27237 checks, 0 failed`.
- clang-format (VS 2022 LLVM): the touched lines clean (two trailing comments aligned by hand);
  the remaining differences in `finddlg1.cpp` / `viewer.h` are older lines.
- Probe after (12 rows at the time): **PASS 24, FAIL 0** (RUN + END rows), registry restored
  identical, fixture removed. `view-copy-ctl` (added after the first after-run) proves the copy into
  the viewer still works for a text that fits. The final run (13 rows) is under *Review*.
- Negative control (`probe/result_negative_control.txt`): a build with the Validate check of
  `CFindDialog` and the body of `CFindSetDialog::Validate` disabled - `grep`, `grep-regex`,
  `grep-hex`, `grep-option`, `view-find` all FAIL (found 2 / 1 / 2 / 2, the field cut; the viewer
  dialog closed). The checks restored, rebuilt, the full probe re-run (the result above).
- Regression: 291's probe (`probe/regress_291.txt`) **PASS 34, FAIL 0**.

## Review

Review 1 (independent agent, refute-first): **no MUST**.
- Re-measured: the probe at HEAD after a rebuild 24 PASS / 0 FAIL; a wider negative control
  (also the Add Current / Manage / Ignore checks, `keepGrep` and the viewer-copy guard disabled):
  `grep-add`, `grep-manage`, `grep-ignore`, `grep-option`, `view-copy` FAIL, `view-copy-ctl` still
  PASS - every guard is needed. 291's probe 34 PASS, 251's 42 PASS. Source restored and rebuilt by
  the reviewer.
- SHOULD 1: the viewer's Find now refuses a text the program pre-filled from a selection (the
  pre-fill puts raw selection bytes in through an ANSI `WM_SETTEXT`; a UTF-8 selection of 199 `a` +
  `é…` shows as 201 bytes ending in `Ă`). Accepted as a consequence: before 311 that text was cut
  and searched as code-page mojibake, which the file does not contain either; the refusal keeps the
  field whole for the user to shorten. The ANSI pre-fill itself -> Inbox
  `viewer-find-pre-fills-a-non-ascii-selection-as-code-page`.
- SHOULD 2: hex mode's `DoHexValidation` reads / writes the field through the code page (quoted
  CJK letters become `?` on the first typed key) - older than 311 -> Inbox
  `hex-mode-in-find-turns-quoted-letters-outside-the-code-page`. It also means `grep-hex` is
  reachable by `WM_SETTEXT` only; typed accented letters of the code page reach the refusal.
- NOTEs: `view-copy` passed on an empty viewer text - row `view-copy-keep` added (a result viewed
  with C66 + Z first, then with C67: the viewer keeps C66 + Z); 251's regression run was missing -
  run (`probe/regress_251.txt`, 42 PASS); Find Duplicates and Append / Subtract / Intersect not
  probed (the same `ValidateData` path); the message says "path" for search text (291's
  precedent, no new string); the DB Viewer plug-in's own Find reads its field with ANSI
  `WM_GETTEXT` into 201 bytes - code page end to end, not a UTF-8 cut; not filed (closing report).

After the review: the probe with `view-copy-keep` on the final code (`probe/result_after.txt`, 13
rows) **PASS 26, FAIL 0**; `regress_251.txt` **PASS 42, FAIL 0**; build, saltests 27237 / 0,
encoding guard TOTAL 0 unchanged. No second review (no MUST in the first).

## Owed to a person

Typing is not driven (WM_SETTEXT, BM_CLICK): one check with a real keyboard - Find, Search file
content, 67 CJK letters typed into Containing, Enter -> "The path specified is too long.", the text
stays whole.
