# Fix log - 396-tar-dotdot-name

Backlog item `tar-member-name-with-dotdot-extracted-into-wrong-folder` - A tar member whose name
contains `..` is extracted into a wrong folder. Run of `/tandem-backlog-implement`, 2026-11-02,
`main` at `6db68ab0`.

## Measurement at 6db68ab0 (before)

Sites (searched by name): `SalTarNormalizeNameU8` in `src/common/saltarlink.h` (one copy, feature
309 moved it there); callers - `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`): the
member name (every format: ustar, GNU long name, PAX path, cpio newc / crc / odc / binary, rpm
payload, deb parts) and, only when it has no `..` component, a link name; saltests
`TarNorm309` (`TestTarLink309`, `TestCpioKeepsGroupMember394`). No other copy of the loop in `src/`
(grep `testAIX`, `drop one directory level`).

Trace by hand: on `..` the loop does `dst -= 2`, walks back to a `\` or to the start, then `dst++`
when it moved. With a previous separator it lands right after it (right); at the start it keeps the
first byte of the dropped component (wrong): `sub/../a.txt` -> `s\a.txt`, `x/../a.txt` ->
`x\a.txt`, `q/../../f.txt` -> `q\f.txt`, `a/..` -> `a`; `x/y/../b.txt` -> `x\b.txt` (right),
`../../empty` -> `empty` (right).

Reachability: every name read by `ReadArchiveHeader` - listing (opening the archive in a panel),
Unpack (Alt+F9), Copy out of the archive, F3.

Build: `.\build.cmd` (Debug x64 incremental, HEAD) -> BUILD SUCCEEDED.

GUI probe (`probe/dotdot_probe.ps1`, written for this item from 309's `link309_probe.ps1`, fixtures
by Python tarfile through `probe/mkdotdot.py`), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\dotdot_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before -OutFile <scratch>\out_before.txt"
```

Result `probe/result_before.txt`: PASS 7, FAIL 5 (6 END rows PASS - no crash):

- UNP-ROOT-DEL FAIL - `s/a.txt` and `q/f.txt` instead of `a.txt` and `f.txt`; archive deleted.
- UNP-OVER-DEL FAIL - "Overwrite file" asked; with Yes the unrelated `s/a.txt` (S) was replaced by
  the data of `sub/../a.txt` (A); `a.txt` missing; archive deleted. (Data loss on disk.)
- UNP-GNU-DEL / UNP-PAX-DEL FAIL - `s/g*120.txt` instead of `g*120.txt`.
- UNP-LINK-DEL PASS - 309's rule (link to `sub/../a.txt` reported, archive kept).
- COPY-ROOT FAIL - the same wrong files. (In this first run the row also required "no window during
  the copy"; the Copy confirmation dialog is a window, so the condition was changed afterwards to
  "no Overwrite question" - the file check alone already failed.)

A first attempt of the probe stopped at once: the variable `$root` hid the library's `$Root`
(PowerShell names are case-insensitive) - renamed to `$rootWant`; the registry was restored and
identical both times.

saltests pins the legacy result: `TarNorm309("sub/../a.txt") == "s\\a.txt"`.

## Decisions

- Fix the rule (the item's first outcome): `..` removes the whole previous component, never above
  the root. Not refusing: `x/y/../b.txt` extracts right today and `../../empty` must stay `empty`.
- 309's link rule unchanged (a link name with `..` stays reported) - the item says "may"; the
  conservative answer keeps it.

## speckit-analyze

0 CRITICAL, 0 HIGH, 0 MEDIUM. LOW accepted: C1 - a name resolving to nothing (`a/..`) is checked
by saltests only (the caller path is 395's, its probe runs as regression); C2 - cpio / rpm / deb
names are not driven by the new probe (one shared function and caller; 395's cpio probe runs).

## Implementation

- T002 (tests first, `src/saltests/saltests.cpp`): 309's pin `TarNorm309("sub/../a.txt")` now
  `"a.txt"`; new `TestTarDotDot396` - 15 table checks (contract `contracts/name-rule.md`) and a brute
  force over all 19,531 names of up to 6 characters from `a b . / \`: every result equals a reference
  component-stack resolver (`TarNormRef396`), every name without a `..` component equals the legacy
  loop copied into the test (`TarNormLegacy396`), no result is longer than its source. The first
  reference forgot that `a/.` keeps the trailing separator (the caller's folder mark) - fixed before
  the first run (it tracks "a separator followed the last kept component").
- T003 negative control (`.\build.cmd` -> BUILD SUCCEEDED; saltests on the legacy rule):
  `saltests: 30858 checks, 12 failed` - the 10 `..` table rows, `wrong == 0` and 309's pin.
- T004 `src/common/saltarlink.h`: the `..` branch now steps back over the trailing `\` and walks back
  while `dst[-1] != '\'` - the whole last component goes; with an empty output nothing happens
  (never above the root). Comments of the file header and the function updated.
- T005 `src/plugins/tar/untar.cpp`: comment only - 309's link rule kept.
- T006 `.\build.cmd` -> BUILD SUCCEEDED (tar.spl rebuilt 11:27); `saltests: 30858 checks, 0 failed`.
- clang-format (VS 2022 LLVM): `saltarlink.h` clean; the new saltests code clean (the remaining
  diffs of `saltests.cpp` / `untar.cpp` are older code).

## Measurement after

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\396-tar-dotdot-name\probe\run_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\396-tar-dotdot-name\probe\dotdot_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\396-tar-dotdot-name\probe\result_after.txt"
```

`probe/result_after.txt`: PASS 12, FAIL 0 (before 7 / 5) - UNP-ROOT-DEL 5 of 5 files, nothing
asked, archive deleted; UNP-OVER-DEL `a.txt` = A and `s/a.txt` = S, no Overwrite question;
UNP-GNU-DEL / UNP-PAX-DEL the long name at the root; UNP-LINK-DEL unchanged (one box naming
`b.txt`, archive kept); COPY-ROOT 5 of 5 files (the Copy dialog now says "3 files and 2
directories" - before "1 file and 4 directories"). Registry restored and identical.

Regression probes (same build, label regress-396, `probe/regress_*.txt`): 306 30 / 0, 308 12 / 0,
309 16 / 0, 395 46 / 0 - the numbers their fix-logs record.

Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
No UI string, dialog or resource changed - no `.slt` refresh.

## Review

Review 1 (independent refute-first agent, 2026-11-02): **no MUST, no SHOULD.** It re-ran
`dotdot_probe.ps1` (12 / 0) and 309's probe (16 / 0), compiled the new header together with the
legacy loop and its own reference and compared 33,235,296 names (up to 5 components from
`sub a .. . "" ... ..a a.. <CJK> C: " .." ".. "`, both separators, leading / trailing separators):
every result equal to its reference, no name without `..` changed, no result with a leading or
doubled `\`, a `.` / `..` component or longer than its source - never above the target. saltests
30,858 / 0; callers enumerated (`untar.cpp` member name and link name, both in
`ReadArchiveHeader`). NOTEs:

1. New name collisions: `a.txt` (S) + `sub/../a.txt` (A) now asks "Overwrite file" (before: two
   files, `a.txt` and `s/a.txt`); with Yes `a.txt` becomes A. The consequence of resolving `..`
   (the spec's choice), the same as the existing `./a.txt` + `a.txt` case, always asked. Recorded as
   a limit in the CHANGELOG / FEATURE-HISTORY entries.
2. A regular file named `z/..` resolves to nothing - 395's "(123)" report, archive kept (before:
   written as a file `z`). The intended safe side (FR-007); now also checked in the program by the
   reviewer.
3. Pre-existing: a regular file named `x/y/..` (old and new rule: `x\`, a folder mark) fails with a
   misleading WriteFile message; archive kept -> Inbox
   `unpack-of-a-tar-file-member-whose-name-ends-in-a-folder-mark` (review:396).
4. 309's link rule kept (as specified).
5. CHANGELOG / FEATURE-HISTORY entries owed - written at closing.
