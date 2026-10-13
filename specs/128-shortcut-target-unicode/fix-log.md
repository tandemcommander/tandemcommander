# Fix log: feature 128 - a shortcut opens its target (GitHub issue #8)

Branch `128-shortcut-target-unicode` from `127-mixed-template-texts`. Session 2026-10-13, the maintainer away.

## 1. Measure first

The report (in Czech) has a picture only: `ARCHIV.lnk` and the box
`(123) Název souboru či adresáře nebo jmenovka svazku je nesprávná.` No target path.

Reading: the box with nothing but an error text is the path check in `CFilesWindow::Execute`
(`fileswn2.cpp`), run on what `IShellLink::GetPath` returned - `IShellLinkA` in this code base.
Feature 069 had described the same defect for the drop-target code and fixed it there only.

Probe `probe/lnk_probe.ps1` on 0.1.9 (`probe/lnk_result_before_v019.txt`): **7 of 18 rows
fail** - Enter on a shortcut to a folder with Czech letters, Greek letters, both, and a UNC path
with Czech letters gives the report's box word for word; *Go to Shortcut Target* fails for the
accented, the Greek and the file shortcut. ASCII targets work; the shortcut's own name does not
matter.

Order of work: the cause had to be found before anything could be specified, so the
measurement and a first fix came before `spec.md` / `plan.md` / `tasks.md` were written; the
documents describe what was then verified, reviewed and finished.

## 2. The change

| File | Change |
|---|---|
| `src/common/salshelllink.h` (new) | `SalShellLinkGetPathU8`: wide `GetPath` (heap, 32,768 units) -> `SalWToU8`; NOERROR / `S_FALSE` (no path) / failure; whole path or an empty buffer |
| `src/fileswn2.cpp` `Execute` | `IShellLinkW`; the three `GetPath` calls through the helper with `SAL_MAX_PATH_UTF8`; the unused `WIN32_FIND_DATA` removed |
| `src/fileswn0.cpp` `FocusShortcutTarget` | `IShellLinkW`; the two `GetPath` calls through the helper |
| `src/saltests/saltests.cpp` | `TestShellLink128` |

## 3. Traps met

- `WScript.Shell.CreateShortcut` refuses a target outside the code page ("value out of
  range") - shortcuts for a test must be written with `IShellLinkW`.
- Bash and Python-in-heredoc mangled `'\tc128'` twice (a tab, a stray quote) - probe scripts
  are edited with the editor tool.
- *Go to Shortcut Target* **enters** a folder target (the panel ends in the target); only for a
  file target it ends in the folder that holds it. The probe's first expectation was wrong.

## 4. Independent review (read-only, refute-first)

No blocker. The main question - does later code in the two functions assume a path under
`MAX_PATH` now that the helper is given `SAL_MAX_PATH_UTF8` - was answered by reading every
callee: each takes the full length or refuses (`SalCheckPath`, `ChangePathToDisk`,
`ChangePathToArchive`, `ChangePathToPluginFS`, `ChangeDir`, `PackIsArchive`; the `memmove` of
the server branch is guarded). Applied:

- the unit test compared with `%TEMP%` verbatim (8.3 form or another letter case would fail on
  another machine) - now `GetLongPathNameW` + `SalPathEqualOrdinalCI`, a per-process folder
  name, and the "A interface differs" check only when the system code page is not UTF-8;
- the unused variable removed.

Recorded in NEXT-WORK, not changed: `GetSHObjectName` (`shellib.cpp`) returns code-page bytes
(only the server-link branch with a Network plug-in uses it); the drop-target code
(`shellsup.cpp`, `shellib.cpp`) still limits a target to `MAX_PATH` bytes (refused, not cut) and
could use the helper; other A shell calls that return paths (`SHGetFolderPath` in
`drivelst.cpp` / `shiconov.cpp` - cloud folders under a non-ASCII profile; `GetOpenFileName` in
`execute.cpp`, `dialogs5.cpp`, `viewer3.cpp`).

## 5. Tests

| What | Result | Record |
|---|---|---|
| probe, 0.1.9 | PASS 11, **FAIL 7** | `probe/lnk_result_before_v019.txt` |
| probe, fixed (final build) | **PASS 18, FAIL 0** | `probe/lnk_result.txt` |
| saltests | 18,343 checks, 0 failed (18,304 before; `TestShellLink128` = 39) | |
| `tools/check_encoding.py` | `TOTAL: 0` | |
| Debug and Release builds | clean | |

Not driven: a real mouse double-click (it runs the same `Execute`); the reporter's own shortcut
(asked in the answer to the issue); whether `GetPath` returns more than `MAX_PATH` characters
for a very long target (the helper passes a large buffer; Microsoft documents `MAX_PATH`).

## Second verification (2026-10-13, asked for by the maintainer)

Everything was built again from scratch (`build.cmd rebuild full`, Debug and Release), the
probes were run again on the fresh build and on the 0.1.9 control, and one independent agent
per feature was told to refute the fix and to write tests of its own.

Probe on the fresh build: **PASS 18, FAIL 0** (`probe/lnk_result_verify2.txt`); 0.1.9: FAIL 7.

The agent could not refute the fix. Its own program: 28 real shortcuts, 617 checks - ASCII,
Czech, Greek, CJK, emoji, an unpaired surrogate, a decomposed letter, 80 CJK letters (292
bytes), UNC with Czech letters, a share root, `C:\`, shell objects (This PC, Control Panel:
`S_FALSE`), a target that does not exist, a relative and an environment-variable target; exact
fit / one byte short / size 1 for every case; the guard bytes around the buffer intact. With
the A interface the same targets give error 123 in the core's path check - the diagnosis holds.
No other cause of the report's box was found that a working shortcut can reach.

Recorded in NEXT-WORK D (older limits next to the fix):

- **the shortcut's own path** is limited to `MAX_PATH` **bytes** in `Execute`
  (`fileswn2.cpp`, `SalPathAppend(fullName, fileName, MAX_PATH)`): a `.lnk` in a folder under
  260 characters but over 260 UTF-8 bytes (about 130 accented or 85 CJK letters) gets "name too
  long" where Explorer opens it; in `FocusShortcutTarget` a `.lnk` path of 260+ units falls to a
  `CP_ACP` conversion that cuts it ("not a valid shortcut");
- `SHGetFileInfoA` in `icncache.cpp:709` (the type name of folders) and `drivelst.cpp:1115`
  (display name of removable drives) - code-page text read as UTF-8 later, suspected;
- the drop-target readers keep their own `MAX_PATH`-byte limit (already recorded).

Wrong in the first answer, corrected: the table row `\\server\sdílení\...` (the probe used
`\\localhost\C$\...\Účetnictví` - the share name itself had no accent); "the shortcut's own
name does not matter" (true for its letters, not for a very long path, see above); "one common
rule" (two older readers for dropping remain).
