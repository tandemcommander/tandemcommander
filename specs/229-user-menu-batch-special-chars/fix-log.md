# Fix log: 229 - the User Menu's batch file keeps %, ^, ! and & in names

Backlog (226's review): the names, paths and environment values a User Menu item inserts
($(Name), $(FullName), $(FullPath), $(ListOfSelectedNames), $[VAR], ...) went into the "through a
shell" batch file raw - each line is `call <command> <arguments>`.

## Measured (before)

Probe `probe/um229_probe.ps1` (226's machinery; each row's folder also holds a DECOY - the name the
special character turns the real one into). The build at 228 (`probe/result_before.txt`): **14
FAIL**, of them **5 "another file copied"**:
- PCT "50%off.txt" (a lone % dropped), PCTCALL, PCTU, LIST, WIDTH: nothing copied;
- **PCTVAR "a%OS%b.txt" -> "aWindows_NTb.txt", ENV ($[VAR] holding such a name), PCTDIR (folder
  "p%OS%q" through the Initial Directory): the decoy copied** - another existing file;
- **CARET "a^b.txt": the decoy "a^^b.txt" copied** (`call` doubles a quoted caret);
- **MULTI (1.txt and a^b.txt): 1.txt copied** - a partial run;
- AMPU (a&b.txt inserted without quotes): the line ran `copy ...\a` and the command "b.txt"
  (the review: a name "x&calc" runs calc); LISTQ (the same inside a quoted list), COMMA
  ("Smith,John.txt" through `$(ListOfSelectedNames)` - cmd splits at ','; `del` would delete Smith
  and John.txt, not the selected file): nothing copied;
- DELAYED (a!b.txt with cmd's DelayedExpansion on): nothing copied;
- BANG, AMP (quoted), INITVAR: as expected (controls).

Found on the way: a path on the program's command line (`-l`, `-r`, `-a`) has its %VAR% expanded
(`GetCommandLineParamExpandEnvVars`, `salamdr1.cpp:3568`) - a folder named "p%OS%q" opens
"pWindows_NTq"; the probe enters such a folder from its parent. Recorded in NEXT-WORK.

## Work

`src/common/salbatchtext.h` (saltests `TestBatchEscape229`):
- `SalBatchEscapedLen` / `SalBatchCopyEscaped`: '%' repeated (4 on a `call` line - the line's
  expansion and the call's each halve it, checked by hand: `call echo "50%%%%off"` prints 50%off;
  2 on the `cd` line);
- `SalBatchValueRefused`: '^' anywhere (no escape survives `call` inside quotes), '&', '|', '<',
  '>' outside quotes; a '"' inside the value switches the state (a list's own quotes);
  `SalBatchInsideQuotes` - the state of the line before the value;
- `SalListNameNeedsQuotes`: a list name goes in quotes for a space and for `, ; = & | < > ( ) ^`.

`src/salamdr2.cpp` `DoExpandVarString` / `ExpandVarString` (`consts.h`): optional batch mode -
each inserted value escaped (after the ':N' width cut; padding counted on the unescaped width) and
a refused value reported. Only what the program inserts is escaped; what the user typed (%VAR%,
^&, >, &&) keeps its batch meaning.

`src/execute.cpp/.h`: `ExpandCommand`, `ExpandUserMenuArguments`, `ExpandInitDir` pass it.

`src/mainwnd4.cpp` `ExpandCommand2`: batch mode for the command and the arguments (a command that
leaves a quote open is refused too - the arguments' quote state starts closed); a refused value:
"Cannot execute external command" with the system's "The filename, directory name, or volume
label syntax is incorrect" (no new string) - nothing runs (the whole batch file is dropped). The
Initial Directory is expanded a second time for the `cd` line (its inserted values' '%' doubled);
the plain value stays for `SetDefaultDirectories`. cmd is started with `/V:OFF`.

`src/salamdr6.cpp` `AddToListOfNames`: quotes by `SalListNameNeedsQuotes` (was: a space only) -
also on the ShellExecute route (programs parse the quotes away).

Build: BUILD SUCCEEDED; saltests 22,649 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` **34 / 0**: every name copied as it is, CARET / MULTI / AMPU / LISTQ
refused with the message and nothing copied, DELAYED copied (HKCU DelayedExpansion set for the row,
restored), INITVAR (a typed `C:%TC229P%` Initial Directory) still expanded by cmd. Regression:
226's probe 28 / 0 (`probe/regress_226.txt`). The negative control above is the final probe on the
build without 229.

## Review

1. Refute-first review: no MUST. Taken: **unquoted values could run another command** (S1 - the
   `&`/`|`/`<`/`>` refusal outside quotes); the Initial Directory's typed %VAR% kept (S2 - the second
   expansion; my first version escaped the whole folder and broke it); probe rows for lists, a
   width, $[VAR], a multi-item run, DelayedExpansion. Kept: the message names the command, not the
   file.
2. Second review (the policy changed): no MUST. Taken: a '"' inside a value switches the quote
   state (S-A: `"$(ListOfSelectedFullNames)"` with "a b&calc" put the '&' outside quotes - fail
   open); `AddToListOfNames` quotes cmd's delimiters and operators (S-B: "del Smith,John.txt" -
   older, but the same lines); a command with an open quote refused; the refusal also on the
   branch without a path; the test comment.

Behaviour changes (CHANGELOG): `/V:OFF` also applies to a user's own batch file called from the
line and to a kept shell window (registry-enabled delayed expansion is off there); list variables
quote names with `, ; = & | < > ( ) ^`.
