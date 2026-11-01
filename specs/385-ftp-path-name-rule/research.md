# Research - 385 FTP server path compare

## R1. What the old rule does (measured at 6428f7e9)

- `FTPIsPrefixOfServerPath` (`src/plugins/ftp/ftputils.cpp`): VMS, MVS, z/VM / Tandem use
  `SalamanderGeneral->StrNICmp(prefix, path, l1)` after stripping trailing separators; Windows /
  NetWare / OS/2 and AS/400 walk bytes with `LowerCase[*s1] == LowerCase[*s2]`. Both are
  `CharLowerA` per byte.
- ACP 1250 (this machine), measured with python ctypes `CharLowerA` over the UTF-8 bytes:
  `Č` C4 8C -> E4 9C, `č` C4 8D -> E4 9D (different: one folder is two); `Ĝ` C4 9C -> E4 9C
  (equal to `Č`: two folders are one); `ĥ` == `Ĺ`.
- `CompareStringOrdinal(TRUE)`: U+0250 `ɐ` (2 bytes) == U+2C6F `Ɐ` (3 bytes); U+023A == U+2C65;
  `ſ` / `ı` / `K` sign do not equal ASCII letters. So a byte count taken from one path cannot
  be applied to the other.
- VMS reads `prefix[l1 - 1]` with `l1 == 0` when `mustBeSame` is FALSE and the prefix is empty
  (an out-of-range read; guarded now).

## R2. Callers (all keep their logic)

| Site | Use | Effect of the new rule |
|---|---|---|
| `ctrlcon4.cpp` 1483, 1596, 1673 | listing cache: find a listing, invalidate a path and its subpaths | case twins found / invalidated; fold collisions no longer |
| `ctrlcon5.cpp` 590, 595 | Create Directory: is the new folder under the working path, focus | same |
| `fs1.cpp` 757, 783 | panel path equality | same |
| `fs3.cpp` 693 | change-on-path notification (refresh) | same |
| `fs4.cpp` 1068, `fs5.cpp` 1123, `operats6.cpp` 1510, `operatsa.cpp` 823, `ftputils.cpp` 2417 | AS/400 `/QSYS.LIB` test | ASCII literal: unchanged for ASCII; `/qsys.lib` still matches |
| `fs5.cpp` 1241 | same source and target path | same |
| `operats2.cpp` 1996, 2025 | operation: path under the operation's path | same |
| `operats7.cpp` 607, 608 | explore cycle check (proper prefix = parent) | detects every real cycle the old rule did, plus case twins; `CExploredPaths` byte-exact backstop |
| `operats9.cpp` 649, 665 | upload listing cache `FindPath` | the item's main defect |
| `operats9.cpp` 2065 | opened-file lock `IsSameFile` (path part) | case twins locked together; fold collisions no longer |
| `ftputils.cpp` 888 | `FTPIsTheSamePath` (history, panel) | same |

Decision: change the rule under all of them (the item); no caller needs a different answer.

## R3. Component rule

- Decision: separator-by-separator, name-by-name walk; names compared with
  `SalNameOrderEqualCI(a, la, b, lb)`.
- Rationale: 092's rule is defined on whole names (valid WTF-8 by `CompareStringOrdinal`, invalid
  text by the legacy fold, never equal across); a whole-path comparison would put an invalid
  name and its neighbours into one "tail" and compare them together.
- Alternatives: code point by code point walk (rejected: does not apply 092's rule to invalid
  names); `SalNameOrderEqualCI` over the whole path (rejected: the prefix test needs the
  boundary, and invalid names would mix).

## R4. Separators

- Only the characters the old boundary logic used: Vms `.`, `[`, `]` (unescaped), Mvs `.`, `'`,
  Dotted `.`, Slashes `/` `\`, As400 `/`. UTF-8 continuation and lead bytes are never ASCII, so a
  separator is never found inside a multi-byte character.

## R5. Probe

- Feature 323's `ftpmini_hide.py` answers `SYST` with `215 UNIX Type: L8`; a copy
  (`probe/ftpmini385.py`) takes `FTPMINI_SYST` from the environment so the plug-in sees a Windows
  server (`GetFTPServerPathType`: SYST contains "Windows" and the path starts with `/`).
- Rows (shape of 345's): CROSS - upload 1 of `o1.txt` into `/Č` kept at its overwrite question,
  upload 2 of `x.txt` into `/Ĝ` where `x.txt` exists: PASS = the question for `x.txt`, no
  `STOR x.txt`, server `x.txt` unchanged. ASCII control - the same with `/a` and `/b`.
