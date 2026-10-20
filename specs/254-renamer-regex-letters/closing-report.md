# Closing report - 254-renamer-regex-letters
Backlog item: renamer-regex-single-byte-classes - Renamer: regular expressions judge \b, \w, classes and '.' by single bytes
Outcome: closed

## What changed

- New header-only `src/common/salu8letter.h`: the units of a UTF-8 (WTF-8) name (valid character,
  WTF-8 lone surrogate, else one byte), stepping back consistent with stepping forward, the
  boundary test, letter classification (`GetStringTypeW`; `icu.dll` `u_charType` from System32 for
  letters outside the BMP and for combining marks, optional), the regex word test and the plain
  whole-word tests (moved from `salu8fold.h`, now with marks and non-BMP letters).
- `salu8fold.h`: `SalU8FoldCodePoint` - 210's same-length fold plus the final sigma as sigma.
- The Renamer's engine (`regexp.cpp`, `regexp.h`): `.`, classes, `\w \d \s`, POSIX classes,
  literal runs before `*+?`, STAR / PLUS / ungreedy forms, `\b \B`, look-behind and the match
  start positions work on whole letters; a class is a variable-length operand (bitmap of ASCII and
  lone bytes, explicit byte members, NEG, type tests, code-point ranges); `\x` escapes forming one
  letter and `\` before a letter give one letter, folded when case-insensitive; ASCII ranges keep
  the old byte loop exactly.
- `crenamer.cpp`: an empty match skips a whole letter; whole words through `salu8letter.h`.
- `dialogs.cpp`: the histories dedupe by `SalNameOrderEqualCI` (092).
- The preview's sort was not changed: it already compares by letters (`RegSetStrICmp`, feature 004).

## Measurements (before / after, commands)

Probe `probe/ren_regex_probe.ps1` through `tools\run_on_hidden_desktop.ps1` (ACP 1250):
- before (3ea24ab5 build): `probe/result_before.txt` + `probe/result_before_wwmark.txt` - 17 of 19
  RUN rows FAIL (10 refused "(123)", one wrong name written - `а\b` gave "ЖAба", six missed), the 2
  ASCII controls PASS.
- after: `probe/result_after.txt` - 25 RUN + 25 END rows, 50 / 0 (the 6 rows added after the
  reviews cover their findings), registry restored identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (one failed attempt on the way: C2440, fixed).
- `saltests.exe` -> `saltests: 24439 checks, 0 failed` (new `TestU8Letter254`).
- Regression probes (`probe/regress_*.txt`): 210 16 / 0 (re-run after each review fix), 196 8 / 0,
  199 6 / 0, 206 10 / 0, 207 8 / 0, 208 12 / 0, 209 8 / 0.

## Reviews (findings and what was done)

- Review 1: MUST M1 (`\ž` / `[\ž]` took the lead byte as U+00C5 - `[\ž]` renamed "Åluť" to
  "Zluť") - fixed; SHOULD S1 (case-insensitive `\x` letters in a bracket not folded) - fixed;
  SHOULD S2 (no engine-level tests) - probe rows bs-lit, bs-class, esc-ci-cls, ungreedy; notes N1
  (recorded limit), N2 (mixed byte / letter range bounds: now no range), N3 (guarded), N4 (as
  designed).
- Review 2: no MUST; SHOULD 1 (byte ranges like `[\x80-\xFF]` no longer covered letters) - fixed
  (explicit byte members), probe rows byte-cls, byte-all; notes recorded under *Limits* in
  `fix-log.md`. Its fuzzing: 330,000 ASCII cases identical to main, 220,000 cases against Python's
  `re`, 90,000 crash cases - nothing else found.

## Owed to a person (with the new person-step items)

Nothing - every row was driven on the hidden desktop.

## New Inbox items (slug - title)

None.

Recorded limits (`fix-log.md`): case-insensitive ranges compare the folded letters (can match less
than case-sensitive); letters whose two cases differ in UTF-8 length stay case-sensitive (210); no
canonical equivalence; `(?<=ab|ž)` refused as not fixed width; a reversed range with a letter bound
keeps only its first bound; without `icu.dll` a non-BMP letter is in no class.
