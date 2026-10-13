# Fix log: feature 127 - translated sentences with names and error texts (GitHub issue #7)

Branch `127-mixed-template-texts` from `126-package-api-late-bind`. Session 2026-10-13, the maintainer away.

## 1. Measure first

Probe `probe/mixed_probe.ps1` on 0.1.9 (`Debug_x64_v019`), Czech, hidden desktop -
`probe/mixed_result_before_v019.txt`: all three cases of the report reproduced (LOG exact:
`(5) PĹ™Ă­stup byl odepĹ™en.`; STATUS: the file name garbage; BOX: the Windows error text
garbage), plus two the report does not have (TITLE: the mask in the Find window's title;
REGDEL: the key name in the Registry Editor's question).

The guard with the report's two additions: 22 findings = the report's 21 + the allowed
exception (`probe/guard_before.txt`).

## 2. The class is larger than the report

`probe/scan_mixed.py --core` lists every composition of a `LoadStr()` template with a name or
error-text argument: 46 of 130. A separate agent read every sink and looked for compositions
without a printf call. Outcome (research R3-R5):

- fix: the report's 21 + 4 (`codetbl.cpp`) + the Find status line, and 13 more places the
  report does not name - among them **a file name** (`IDS_NEWNAME_COPY`, the generated name of
  a copy in the same folder);
- leave: 18 compositions that are right as they are (both parts code page, or ASCII templates,
  or unreachable) - after the fix the inventory lists exactly these 18;
- defer: two places that hand a composed text to plug-ins which wrap it in their own code-page
  sentences, and the other plug-ins (137 candidates, FTP 86) - NEXT-WORK.

## 3. The change

| File | Sites |
|---|---|
| `src/salamdr2.cpp` | `LoadStrU8` wraps and converts again when a text does not fit the rest of its rotating buffer (it answered `ERROR LOADING STRING`) |
| `src/finddlg1.cpp` | status base (`char buf[300]`, UTF-8), three titles |
| `src/find.cpp` | five log compositions, three plain log texts, duplicates text x2, `CSearchingString::Set` cuts at a whole character |
| `src/dialogs3.cpp`, `icncache.cpp` x2, `mainwnd4.cpp` x3, `salamdr1.cpp` x2, `codetbl.cpp` x4 | message boxes |
| `src/fileswn5.cpp` | viewer / editor cannot be started x4, View With / Edit With menu x2 |
| `src/fileswn6.cpp` | name too long x2, cannot read directory x3, too big for FAT32, junction target text, **the copy name** |
| `src/fileswn3.cpp`, `fileswn9.cpp`, `fileswn8.cpp` x2 | path not found in archive, UNC name, Copy / Move title sentence |
| `src/callstk.cpp` | allowed-exception marker |
| `src/plugins/regedt/fs2.cpp` x2, `fs3.cpp` x2, `utils.cpp` | Registry Editor messages through the plug-in's `LoadStrU8` |
| `tools/check_encoding.py` | `GetErrorText(` is a UTF-8 argument; `params.Text =` / `log.Text =` are sinks |

Mechanics: template `LoadStr` -> `LoadStrU8`; every touched unbounded `sprintf` ->
`_snprintf_s(buf, _TRUNCATE, ...)`; after a composition that holds a path or name
`SalU8TrimIncompleteTail(buf)` (a cut inside a character would make the text invalid again).
The 44 mechanical sites were changed by a script with exact anchors and counts
(it stops when an anchor matches a different number of lines), the rest by hand.

## 4. Traps met

- `codetbl.cpp`: `textBuf` is a pointer parameter - `_snprintf_s(buf, _TRUNCATE, ...)` needs
  an array; the size got a name (`CODETBL_TEXTBUF_SIZE`). The compiler caught it.
- An inserted trim line after a statement that is the body of an `if` / `else` without braces
  lands outside it - two places, fixed by hand (braces / placement).
- PowerShell: `(Func 1 'a' + "b")` passes `+` and `"b"` as arguments.
- "Copy to the same folder" by typing the folder as the target is refused ("Cannot copy a file
  to itself"); the generated copy name comes from Paste in the same folder - which needs the
  clipboard.

## 5. Independent review (read-only, refute-first) - "not ready to commit"

The first version built, passed the probe and the guard, and was **rejected**: one blocker and
two regressions, all of the kind "the UTF-8 template now meets a code-page neighbour or sink".

| Finding | Fix |
|---|---|
| **Blocker** - the Copy / Move subject (`fileswn8.cpp`) becomes `COperations::WaitInQueueSubject`, which `CProgressDialog::SetDlgTitle` (`dialogs.cpp`) put into `"(%s) %s"` with a code-page word and set with `SetWindowText` (A): the title of every queued operation would have read `KopĂ­rovat ...`. The same lines overran `char buf[200]` with a long file name (old defect) | the dialog's own title is composed **wide**, piece by piece (`ProgressTitlePieceToW`: UTF-8 when valid, else code page), bounded, compared with `InternalGetWindowText`, set with `SalSetWindowTitleW` |
| `codetbl.cpp`: `ReadTable` returns `LoadStr(IDS_VIEWERBADFILESIZE)` as the `%s` of the now-UTF-8 template; the paths come from `GetModuleFileName` (A) - an installation under an accented folder would garble the message | `LoadStrU8` there; paths through `MsgPath()` (code page -> UTF-8 for the message; a plain function because the callers use `__try`); two older unbounded `sprintf` bounded |
| `salamdr1.cpp`: `skippedNames` is composed with `LoadStr(IDS_NUMOFSKIPPEDPLUGINNAMES)` and goes into the UTF-8 message | `LoadStrU8`, bounded |
| Registry Editor `fs3.cpp`: a very long key name is cut by `_TRUNCATE` without a tail trim | `SplU8TrimTornTail` |

The lesson is the reverse rule: when a template becomes UTF-8, **every other piece and the sink
must be UTF-8 too**. The guard cannot see it (recorded in NEXT-WORK: a reverse rule - a
`LoadStr(` argument inside a `LoadStrU8` template - and variable-name independence of the sink
patterns).

Recorded, not changed: `menu2.cpp` `AssignHotKeys` works byte-wise with code-page tables and can
put `&` inside a UTF-8 sequence of a View With / Edit With item (old for UTF-8 commands); the
`"..."` cut inside `cmdLine` in `mainwnd4.cpp` can split a character ("always false" path);
the Registry Editor's `LoadStrU8` gives an empty text for a template over 599 bytes (the
longest is about 110).

## 6. Tests

| What | Result | Record |
|---|---|---|
| probe, 0.1.9, Czech | PASS 7, **FAIL 6** (LOG, TITLE, STATUS, BOX text, BOX drawing, REGDEL), NOT DRIVEN 1 | `probe/mixed_result_before_v019.txt` |
| probe, fixed, Czech | **PASS 13, FAIL 0**, NOT DRIVEN 1 | `probe/mixed_result_czech.txt` |
| probe, 0.1.9 and fixed, English (LOG, BOX, PROGRESS) | PASS 8, FAIL 0 both - identical texts | `probe/mixed_result_english.txt`, `..._before_v019_english.txt` |
| guard | 22 findings -> 0; one fixed line put back -> that line reported | `probe/guard_before.txt`, `probe/guard_after.txt` |
| inventory (`probe/scan_mixed.py --core`) | 46 candidates -> 18, exactly the "right as they are / deferred" list of research R3-R4 | |
| saltests | 18,304 checks, 0 failed | |
| Debug and Release builds | clean | |

Rows: LOG (the log row, exact), TITLE (the Find window's title during a search with the mask
`*.bin;ž*.řx`, exact), STATUS (the status line during a content search of a 12 GB sparse file
`Příliš žluťoučký kůň 01.bin`; capture + recognition), BOX (the Copy error for the unreadable
subfolder: window text exact + recognition of the drawing), PROGRESS (the progress dialog's
title during a running Copy - the row added for the review's blocker: `(0 %) Kopírování`),
REGDEL (the Registry Editor's question for a non-empty key named `Příliš žluťoučký kůň`, exact),
END rows (exit code 0, no stray window, no report).

**Not driven**: COPYNAME - the generated name of a copy pasted into the same folder (Slovak
`Kópia`). It needs Edit > Paste; the clipboard of the machine held non-text data, which the
probe library refuses to overwrite. Reviewed by reading (the name block appends the two words
byte-wise and never compares against them); owed to a person: Slovak, Ctrl+C / Ctrl+V on a
file in its own folder, the new name reads `a - Kópia.txt`. Also owed: the queued-operation
title (`(čekající) Kopírovat ...`) on a real screen.
