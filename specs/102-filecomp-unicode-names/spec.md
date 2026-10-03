# Feature Specification: The File Comparator compares the files you name

**Feature Branch**: `102-filecomp-unicode-names`
**Created**: 2026-10-03
**Status**: Draft
**Input**: found by feature 100 ("the File Comparator cannot open files named outside the code page") and researched before the work (`research.md`); the maintainer: *"ok oprav je"*.

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: What is wrong? → A: Measured and read (`research.md`): the comparison engine itself opens files through the Unicode file layer and is correct. What breaks names is everything around it:
  1. the **Compare Files dialog** subclasses its two path fields with a code-page window procedure, so a name with characters outside the code page becomes `?` and the comparison fails ("cannot open ... syntax is incorrect"), and the `?` name is saved into the history;
  2. **dropping files** onto the dialog and **`fcremote.exe`** (the command-line entry used by other programs, e.g. version-control clients) take names through code-page calls that use *best-fit* mapping: `voilà.txt` becomes `voila.txt`, `ＡＢ` becomes `AB` - **if such a file exists, it is compared instead, without a word**;
  3. `fcremote.exe` fails for **every** non-ASCII name, even inside the code page (`Petrů.txt`), since feature 004 (it sends code-page bytes, the plug-in expects UTF-8);
  4. the **history** drop-down shows every non-ASCII name garbled in every language (`ř` as `Ĺ™`) and a picked entry "does not exist";
  5. the **list of differences**, several titles and messages mix code-page text with UTF-8 names (garbled names in the Czech, German, French, Hungarian and Slovak UI);
  6. all name buffers are 260 bytes: with a longer path the command does nothing, silently.
- Q: Scope? → A: All six, in the File Comparator plug-in and `fcremote.exe` only; no plug-in interface change (stays 107); no change of the registry format (history values are already UTF-8 through the core's registry layer). Other plug-ins with the same pattern are recorded for the backlog.
- Q: `fcremote.exe` and the running program talk through a shared message channel - compatibility? → A: Both ship together. The message format changes (names as UTF-16, variable length), and the channel's version is bumped, so a mismatched pair (a copied old `fcremote.exe`) fails with a clear error instead of misreading the message; today a size mismatch is silently ignored and `-w` (wait) then waits forever - also fixed.
- Q: Browse? → A: The Browse button uses a Unicode open-file dialog inside the plug-in (the core's plug-in service is code-page only; extending it would change the interface).
- Q: User-visible text? → A: No new strings; existing texts are loaded as Unicode so names inside them are correct.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compare files named in any script (Priority: P1)
**Independent Test**: pairs of files named with Cyrillic, Chinese, an emoji and a lone surrogate, in a short and in a 150-character Chinese path; Compare Files (Ctrl+Shift+C) with the dialog and with "confirm selection" off; result title and difference count; the history afterwards; English and Czech UI.
**Acceptance**: the right files are compared (difference count matches the fixtures), names display exactly in the dialog, history, title and list of differences.

### User Story 2 - Never compare a different file (Priority: P1)
**Independent Test**: decoy pairs in one folder - `voilà.txt` / `voila.txt`, `ＡＢ.txt` / `AB.txt`, `Ă©.txt` / `é.txt` - with different content; every route (dialog, drop, fcremote) compares exactly the named file.

### User Story 3 - `fcremote.exe` works for non-ASCII names (Priority: P1)
**Independent Test**: `fcremote first second` and `fcremote -w first second` with `Petrů.txt`, Cyrillic and Chinese names, with the program running and not running; `-w` returns when the comparison window closes.

### Edge Cases
- Names exactly at and above 259 bytes; an install path outside the code page (fcremote starting the program).
- A mismatched fcremote / plug-in pair: a clear error, no hang.

## Requirements *(mandatory)*
- **FR-001**: Every route that gives the File Comparator a file name (core selection, dialog typing/history/Browse/drop, the comparator window's drop, fcremote) MUST deliver the exact name.
- **FR-002**: No code-page conversion with best-fit mapping may ever be applied to a file name on these routes.
- **FR-003**: History, titles, the list of differences and messages MUST show names exactly in every UI language.
- **FR-004**: Names of any length the program handles MUST work, or be refused with a message - never a silent no-op.
- **FR-005**: The fcremote channel MUST carry names in Unicode and MUST detect a version mismatch.
- **FR-006**: No plug-in interface change, no new strings, history format unchanged.

## Success Criteria *(mandatory)*
- **SC-001**: For every fixture pair and route, the comparison shows the expected difference count (before: `?` errors, decoys compared, fcremote failing).
- **SC-002**: 0 decoy files compared on any route.
- **SC-003**: Debug + Release builds, unit tests, guard, and the probes of 093, 095-101 pass.
