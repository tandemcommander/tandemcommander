# Fix log: 238 - a folder named with %...% is opened as it is

Found by 229's probe: a path on the command line (`-l` / `-r` / `-a`,
`GetCommandLineParamExpandEnvVars`, `salamdr1.cpp`) or typed into Change Directory (also pasted or
dropped on the directory line: `CFilesWindow::PostProcessPathFromUser`, `fileswn9.cpp`) always had
its %VAR% expanded - a folder literally named "p%OS%q" opened "pWindows_NTq", another existing folder.

## Measured (before)

Probe `probe/pct238_probe.ps1` (the build at 237, `probe/result_before.txt`, the final probe):
**CMDLINE, TYPED, DEEP (p%OS%q\sub), REL (relative "p%OS%q") opened pWindows_NTq**; CMDVAR / TYPEDVAR /
STRAY (a variable) expanded as expected.

## Work

`src/common/salpctpath.h` (new; saltests `TestPercentPath238`): `SalPercentPrefixLen` (the part up to
the last component holding a '%'), `SalPercentPathKind` (local / network / relative / root-relative
/ drive-relative).

`src/salamdr3.cpp` `SalPercentPathExistsLiterally(path, baseDir)` (`consts.h`): the path made absolute
(a relative one against `baseDir` - the disk panel's folder, or the current folder for the command
line), its prefix up to the last '%' component checked with `SalGetFileAttributes`; exists -> the
path is used as typed (also "p%OS%q\a.zip\inner"); else expanded as before. Not checked (expanded as
before): network paths and mapped network drives (a dead server would stall before ChangeDir's
cancellable check), "X:name", archive / FS panels' relative paths, and a relative path that starts
with a defined variable ("%APPDATA%\x" - programs create stray folders named "%APPDATA%"; such a folder
stays reachable as ".\%APPDATA%"). When both the literal folder and the expanded one exist, the
literal wins - the only reading that cannot silently open another folder.

Build: BUILD SUCCEEDED; saltests 22,737 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` **14 / 0**. The negative control (the build without 238, the final probe
before the STRAY row): CMDLINE, TYPED, DEEP, REL FAIL.

## Review

1. Refute-first review: no MUST. Taken: deeper paths (the prefix rule), relative typed paths, no
   check on network paths (stall), the rule's pure parts in a header with saltests, no false
   "expansion failed" trace.
2. Second review: no MUST. Taken: a defined variable at the start of a relative path wins over a
   stray literal folder (STRAY row); a relative command-line argument is checked against the
   current folder. Noted: a local folder that is a link to a share is still checked (rare).
