# Fix log: 226 - the User Menu's batch file keeps accented and CJK names

Backlog (found by 225's review): a User Menu item with "Execute Through Shell" writes a batch file
and runs it with cmd.exe; its command line and folder (UTF-8, WTF-8) were converted with
`CharToOem` (`mainwnd4.cpp` ~918), which reads its input as the ANSI code page.

## Measured (before)

Probe `probe/um226_probe.ps1`: User Menu items (the registry key replaced for the run) copy the
focused file(s) with cmd's `copy` into an ASCII folder. The build at 225, the probe's final form
(`probe/result_before.txt`, ACP 1250, OEM 852): **11 FAIL** -
- ASCII (the control): copied;
- **ACC / ACCDIR / CJK / CJKDIR / ACCKEEP / CJKKEEP / MANY / MANYCZ: nothing copied** - the batch
  file named other letters (UTF-8 bytes read as cp1250 and mapped to 852: "p\u0139t\u0102..." for
  "p\u0159\u00ED..."; CJK became "?"). Every name outside ASCII was out of reach of such an item -
  or, with a name whose garbled form exists, another file;
- **CWDREL: a command with a relative name and no Initial Directory found nothing in a folder
  with Czech letters** - `mainwnd3.cpp` set the current folder with `SetCurrentDirectory` (A) on
  the UTF-8 path: it failed and the command ran in the program's resting folder (System32).

## Work

`src/common/salbatchtext.h` (new, header-only; saltests `TestBatchText226`):
- `CSalBatchText` collects the batch text in UTF-8 (not copyable);
- `SalBatchChooseEncoding`: every character has an exact OEM form (no best fit, no default
  character) -> OEM bytes; otherwise UTF-8; not valid UTF-8 (a WTF-8 unpaired surrogate) ->
  refused; an OEM code page of 65001 -> the text as it is;
- `SalBatchCodePageLine`: `@"<system folder>\chcp.com" <cp>>nul`, the first line with
  `|| exit /b 1`; the absolute system folder (from `GetSystemDirectoryW`) when it is ASCII, else
  `%SystemRoot%\System32`.

`src/mainwnd4.cpp` `CMainWindow::UserMenu` + `WriteUserMenuBat`:
- the lines are collected, then written once: pure ASCII byte for byte as before (no chcp lines);
  OEM-representable: a line switching the console to the OEM code page, then the OEM bytes;
  otherwise a line switching to 65001, the UTF-8 text, a line back to the OEM code page;
- a name no batch file holds is refused: the system's "No mapping for the Unicode character
  exists..." through the existing error path (no new string), the batch file is not run;
- the folder line is `@cd /d "<dir>" || exit /b 1` (was `@C:` + `@cd "<dir>"`, which went on when
  the folder was not there - the command then ran in the panel's folder); written only when the
  folder has a drive letter (the old condition read `initDir[1]` of an empty folder);
- `skipErrorMessage` set before the `goto ERROR_LABEL` that skipped it (read uninitialized when
  the batch file could not be created); COMSPEC read with `SalGetEnvVarU8` (was the A call; unset,
  it left the user's command in the buffer as the program to run).

`src/mainwnd3.cpp` + `salamdr3.cpp` (`SalSetCurrentDirectoryU8`, `consts.h`): the User Menu's
current folder is set through the wide API; when it cannot be set, the system folder (as before),
never another one.

Build: BUILD SUCCEEDED; saltests 22,612 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` **28 / 0**:
- all copy rows; ACCKEEP / CJKKEEP keep the shell open and read the batch file while it runs
  (Czech: `@"C:\WINDOWS\system32\chcp.com" 852>nul || exit /b 1` + OEM 852 bytes; CJK: the 65001
  line, UTF-8, the line back to 852);
- MANY / MANYCZ: 40 selected files each (CJK + Czech + ASCII / Czech only, batch files of about
  9 KB, one line per file) - all copied;
- PLANT / PLANTA: a `chcp.bat` planted in the panel's folder does not run;
- CWDREL: the panel's own a.txt copied (the other panel holds a different a.txt);
- CDFAIL: an Initial Directory that does not exist - nothing copied;
- AUTORUN: cmd's AutoRun set to `chcp 65001>nul` for the row (HKCU value and key restored).

Negative controls:
- `probe/result_control_bare_chcp.txt` (a build with a bare `chcp`): **PLANTA FAIL - the planted
  chcp.bat ran and the command never did** (cmd searches the current folder first; the probe
  removes `NoDefaultCurrentDirectoryInExePath`, which the shell it was started from had set and
  which Windows does not set; PLANT in a CJK folder did not fail there only because the A
  `SetCurrentDirectory` had not set that folder);
- a build without the `|| exit /b 1` of the folder line and without the OEM route's first line:
  **CDFAIL FAIL - "content of CDFAIL" copied from the panel's folder**; AUTORUN still passed
  (`probe/result_control_autorun.txt`, the AutoRun marker shows it ran): in a console the program
  creates, cmd read the OEM batch file correctly although AutoRun had switched to 65001. A cmd
  started in an existing console after `chcp 65001` does read it wrongly (checked by hand) - the
  OEM route's first line is kept as a cheap guard; the AUTORUN row does not tell the two apart.

## Review

1. Refute-first review of the first version: **MUST, taken - the bare `chcp` ran a planted
   chcp.bat from the folder the user browses** (confirmed by the control above). SHOULD taken: an
   explicit code-page line also on the OEM route (a console set to another code page); a probe of
   batch files over 8 KB and of mixed names. NITs taken: the last error kept around `free`, the
   class not copyable, `|| exit /b 1`. Older defects of the function fixed here (they sit on the
   rewritten lines): `skipErrorMessage`, `initDir[1]`, COMSPEC.
2. Second review (the policy changed): no MUST. SHOULD taken: the absolute system folder in the
   chcp line (a child environment without SystemRoot would make it `\System32` of the panel's
   drive); `cd /d ... || exit /b 1` (a missing Initial Directory ran e.g. `del /q *.*` in the
   panel's folder); a row with cmd's AutoRun. NITs taken: the `mainwnd3.cpp` comment (the resting
   folder is System32, not the other panel's), `<stdio.h>`, `= delete`, the header's notes.

Known limits (recorded in `specs/NEXT-WORK.md`): a failed code-page switch or `cd` ends the batch
file silently when its window is hidden; a shell window kept open ends at the OEM code page, not
at one the user configured; one character outside the OEM code page runs the whole batch at 65001.
