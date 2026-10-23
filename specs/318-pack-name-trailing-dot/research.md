# Research - 318-pack-name-trailing-dot

## R1 - Where the name can be checked

- Decision: in `CFilesWindow::Pack` (`src/fileswn7.cpp`), right after `SalGetFullName(fileBuf, ...,
  MAX_PATH, TRUE)`, where 317's refusal already is.
- Rationale: it is the one point every Pack name passes (offered or typed, relative or absolute,
  "Use the other panel" on or off) before the "packed into itself" check (119), the "add or
  overwrite?" question, Overwrite's aside (176) and `ExecutePacker` - a refusal there touches
  nothing. The dialog's own `Transfer` runs before the full path exists and only adds the extension.
- Consumers enumerated (Grep): `SalPackNameIsOnlyDotsAndSpaces` is called only at
  `src/fileswn7.cpp` (Pack) and in `src/saltests/saltests.cpp` (`TestPackName317`). Other routes into
  an archive (F5/F6 into an open archive, drag & drop) write into an existing archive whose name the
  user did not type - out of scope.
- Alternatives: a check in the ZIP plug-in (covers one packer only, plug-in change); changing
  `SalGetFullName` (shared by every path entry, its callers rely on today's result).

## R2 - What "not kept as typed" means

- Decision: the last part (after the last `\`), when not empty, is refused if
  1. its last character is `.` or ` ` (Win32 trims trailing dots and spaces; `\\?\` does not), or
  2. it is a reserved device name: the part before its first `.` (the whole part when there is
     none), with trailing spaces removed, equals case-insensitively `CON`, `PRN`, `AUX`, `NUL`,
     `COM0`-`COM9`, `LPT0`-`LPT9`, or `COM` / `LPT` followed by a superscript one, two or three
     (UTF-8 `C2 B9`, `C2 B2`, `C2 B3`) - Microsoft's documented list ("Naming Files, Paths, and
     Namespaces").
- Measured (before, Windows 11 10.0.26300): case 1 names are not openable through a plain path;
  case 2 names with an extension are (Windows 11 no longer maps `CON.zip` to the device). Case 2 is
  refused anyway (spec Clarifications: the item names it); the program's own
  `SalIsValidFileNameComponent` already treats them as invalid.
- Not refused (spec Clarifications): leading spaces before a device name (` CON.zip`), a trailing
  tab or other control character, `CONSOLE.zip`, `con bla.zip`, `COM10.zip` - Windows treats none
  of them as reserved; the ZIP plug-in refuses control characters itself.
- Alternatives: calling `SalIsValidFileNameComponent` (`src/salamdr5.cpp`) - it also refuses
  `* ? < > | " :`, a trailing tab and names over 255 UTF-16 units, which the item does not name
  (behaviour change beyond scope), it misses `COM0` / the superscripts, and it is not reachable from
  saltests as a header-only rule.

## R2a - Existing files and '/' (review of 318)

- Decision: the refusal applies only when `FileExists(fileBuf)` is FALSE - an archive already named
  so (an `aux.zip` made elsewhere, a literal `report.` left by an earlier Pack) gets the "add or
  overwrite?" question as before. `FileExists` (`src/salamdr2.cpp`) reads attributes through
  `SalPathToWExtAlloc` (`\\?\`, no trimming of dots or spaces - `SalCanonicalizePathW` only folds
  `.` / `..` segments and `/`), so an existing `report` never stands for `report.`; a folder of that
  name does not count (FileExists is files only - the packer fails on it, as before).
- Decision: the rule's last part starts after the last `\` or `/` - `SalPathToWExtAlloc` and the
  packers turn `/` into `\`, so `./CON.zip` named `CON.zip` (the review measured `./CON.zip`,
  `sub/CON.zip`, `report./`, `report.zip /` reaching the ZIP plug-in, which refused them itself).
- Rationale: stop-rules §1 step 4 - the item names new files only; adding to an existing archive is
  a case it does not name, so its behaviour stays.

## R3 - 317's rule

- Decision: `SalPackNameIsOnlyDotsAndSpaces` is removed; `SalPackNameIsNotKeptAsTyped` covers it
  (a part of only spaces and dots ends with one of them). Its 16 checks become checks of the new
  rule with the same expectations, except `"C:\\t\\\t.."` (a tab, then dots): now refused - it
  ends with a dot - which is the point of the new rule.
- Rationale: one rule at one call site; no dead code.

## R4 - The message

- Decision: `IDS_PATHISINVALID` ("The path specified is invalid."), the box titled Pack, the dialog
  again with the full name selected - exactly 317's route. No new string (a run cannot do the
  `.slt` refresh).
- Alternative: `IDS_DIRNAMEINVALID` ("The path or file name "%s" is invalid.") would need a
  formatted message and a second error route - more change for the same outcome.
