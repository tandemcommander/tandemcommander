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
