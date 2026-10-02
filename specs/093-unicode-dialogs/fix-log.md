# Fix log: feature 093 - Unicode dialogs (encoding cluster B-1)

Branch `093-unicode-dialogs`, based on `092-name-identity-unicode`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 - baseline

- saltests before the feature: 12,828 / 0. Strict guard `TOTAL: 0`.
- `probe/B1Probe.cs` + `result.txt`: the Win32 semantics the feature rests on
  (research sections 1.3, 1.4), measured on this machine (code page 1250).

## T003 - the premise measured in the product

`probe/dialogs_probe.ps1` on the Debug build, two runs with identical output
(`probe/baseline_result.txt`): 56 PASS, 25 LOSSY. Test text `a ř Ж 日 📁`.

| Surface | prefill | set by program | typed |
|---|---|---|---|
| Create Directory (created as a Unicode dialog - the control case) | - | ok | ok |
| Change Directory, Pack, Unpack (path and mask), Select, panel filter | ok | ok | ok |
| Find: Named | - | ok | **lossy** |
| Find: Look in, Containing | **lossy** | **lossy** | **lossy** |
| Configuration: Hot Paths (path, name), User Menu (command, arguments, directory) | ok | ok | **lossy** |
| Command line | - | **lossy** | **lossy** |

The executable carries the common-controls 6 manifest and the process loads
comctl32 6.0 from WinSxS. With it `Edit` and `ComboBox` are Unicode controls
also inside a dialog created through the code-page entry point - research
section 1.3 ("the entry point decides"), measured in a process without that
manifest, does **not** hold in the product. Section 1.4 (the loop decides
for typed characters) holds: the typing-only losses sit exactly on the two
code-page loops (Find's thread, the Configuration window), and Find's two
all-channel losses on the fields with the code-page helper `CComboboxEdit`
attached (their inner edit reports a non-Unicode window).

Consequence: no dialog needs to be re-created as a Unicode window. Scope
revised (plan, tasks).

Seen by the probe, not part of the feature: the main window title shows `?`
for such a folder; a message box's text control is Unicode, its buttons are
not.

## Before S2 - the 7-Zip password measured

Confirmed, shipped since 0.1.0 (feature 005 made `EditLine` return UTF-8 one
day after feature 004 wrote the code-page conversion): `dialogs.cpp` reads
the password as UTF-8 into `char[128]`; `open.cpp`, `extract.cpp`,
`update.cpp`, `7zip.cpp` convert it with the code page. Measured:

| Archive | typed in the plug-in | result |
|---|---|---|
| made by 7-Zip 22.01 with `heslo-ř` | `heslo-ř` | nothing extracted |
| made by 7-Zip with `heslo-Ĺ™` (the garbled form) | `heslo-ř` | extracted, content equal |
| made by the plug-in with `heslo-ř` | - | 7-Zip opens it with `heslo-Ĺ™`, not with `heslo-ř` |
| ASCII password | same | extracted |

Also seen: with the wrong password no error window appeared within 9 s (not
traced); the `char` password buffers are never wiped.

## S1 - message loops and attached helpers

| What | Where |
|---|---|
| Find's thread loop and its two secondary loops take, translate and dispatch wide | `find.cpp`, `finddlg1.cpp` (`StopSearch`, the wait in `WM_DESTROY`) |
| the Configuration window's loop | `common/sheets.cpp` `CTreePropHolderDlg::ExecuteIndirect` |
| the main loop: `IsDialogMessageW` (it already took and dispatched wide) | `salamdr1.cpp` |
| menu-bar mnemonics compare UTF-16: `IsMenuBarMessageEx(msg, unicodeMsg)`; the plug-in-facing virtual `IsMenuBarMessage` is unchanged and calls it with FALSE | `menu.h`, `menubar.cpp`, `SalMnemonicMatchW` |
| `CWindow::AttachToWindowKeepKind` - opt-in, used for the four `CComboboxEdit` attaches | `common/winlib.*`, `finddlg1.cpp`, `viewer.cpp`, `dialogs.cpp` |
| the in-place editor of edit list boxes is a Unicode control; the list keeps its kind | `edtlbwnd.cpp` |
| Find's *Look in* -> Browse reads the field wide | `finddlg1.cpp` |
| overflow: as many whole characters as fit (`SalWToU8Truncate`) instead of a code-page re-read | `common/winlib.cpp` `EditLine`, `SalGetWindowTextU8` |

**Why the menu bar had to move with the loops.** The mnemonic test compared
`(char)wParam` through the code-page table with one byte of a UTF-8 menu
string. The main loop has been wide since feature 004, so a typed `ř`
(U+0159) arrived there as a 16-bit unit: in the **Debug** build Alt+`ř` in
the main window crashes the pre-093 build (run-time check "cast to a smaller
type" in `CMenuBar::IsMenuBarMessage`; the reviewer drove it three times), in
Release the unit is cut to a byte and compared as `Y`. An accented mnemonic
could never match. Now both are compared as characters. For ASCII the old
and the new look-up are equivalent (reviewed; driven: Alt+a-z, 0-9 open the
same eight menus at the same positions on both builds).

**`AttachToWindow` is not changed for everybody** (the plan said it would
be): `CStaticText`, `CButton` and relatives pass `char*` text through text
messages and are handed to plug-ins. Contract D3 rewritten.

**Probe** `probe/dialogs_probe.ps1` (now 105 rows: the five modal dialogs
not driven before, the in-place list editor and a regression drive were
added):

| Build | PASS | LOSSY | FAIL |
|---|---|---|---|
| pre-093 (`s1_result_pre093.txt`) | 74 | 30 | 1 |
| S1 (`s1_result.txt`) | 103 | 2 | 0 |

The 2 are the command line (stage S3). The 30 are the 25 of the baseline
plus five the new surfaces found: Make File List's line combo and the
in-place list editor. Find with a typed `*.zip` in the Cyrillic folder finds
the file (0 on the old build). saltests 12,828 -> 12,904.

**Independent review - ACCEPT**, no blocker; its probe rerun is identical
line for line. Its measurements beyond the probe: Find with typed `Ж*`, `ř*`,
`*.txt` finds 1, 1, 3 items; Find's ignore list (a modal dialog under the
system's own loop) keeps `Ж a ř Ж 日` typed into the in-place editor (old
build: `? a r ? ?`); Configuration tree by keyboard; six control mnemonics
in Find identical on both builds.

Corrections it made to the record:

- **What a posted character proves.** A character *posted* as `WM_CHAR`
  reaches a code-page window procedure in the code page of the thread's
  keyboard layout, not the system's: on this machine's default layout a
  posted `ř` arrives as `r` under every loop. So the probe's typing channel
  proves the Unicode fields, and it cannot prove that code-page windows see
  typed code-page text as before. A scratch program did: with the Czech
  layout active, a code-page procedure sees `a ř ?` (61 F8 3F) under all four
  loop shapes, old and new alike, and a Unicode one sees `ř Ж` only under the
  wide loops. The neutrality claim of research 1.4 stands; its "lossy `r`"
  rows are a layout artefact.
- `SalACPCharToW` takes the byte of a code-page loop to be in the system code
  page; it is in the layout's. Comment corrected; the menu bar's own modal
  loop is still a code-page loop (recorded below).

Recorded, not changed:

1. The loops that only drain messages during an operation stay code-page
   loops (`dialogs.cpp`, `dialogs6.cpp`, `mainwnd2.cpp`, `mainwnd3.cpp` x2,
   `pack3.cpp`, `regwork.cpp`, `zip.cpp`, `salamdr2.cpp`, `tooltip.cpp`,
   `viewer2.cpp`, help mode in `mainwnd4.cpp`): a character typed ahead into
   a Unicode field while one of them runs is still converted.
2. The menus' own modal loops (`menubar.cpp`, `menu2.cpp`) and
   `CMenuPopup::OnChar` stay on code-page bytes.
3. The in-place list editor limits the text to `MAX_PATH` UTF-16 units while
   its buffer is 260 bytes: about 87 CJK characters or more are cut (at a
   whole character). Such text could not be entered before.
4. `SalMnemonicMatchW` reads the menu string as UTF-8 when it is valid UTF-8
   (the same heuristic the menu drawing uses); a legacy code-page string of a
   plug-in whose mnemonic bytes happen to form a UTF-8 sequence compares the
   wrong character.
5. Not driven: a real keyboard and an input method editor; an accented
   top-level mnemonic (no enabled translation has one); the shell folder
   picker behind *Look in* -> Browse; the viewer's Find dialog; dark theme.
6. The probe leaves `%TEMP%\tc093_dlg_backup.reg` (its registry backup).

## S2 - the 7-Zip password

**The typed text is UTF-16 from the field to the engine.** The two dialogs
read their password fields wide themselves (`TransferPasswordField`,
`GetWindowTextW`, limit 127 characters by `EM_LIMITTEXT`) - the shared
`EditLine` is not used for a password any more and `winliblt` is unchanged.
No code-page conversion is left on a password; the four comments that said
"our own ANSI dialog, so it is in the ACP" are replaced.

| What | Where |
|---|---|
| fields read wide, exact comparison of the two fields, buffers wiped in the destructors | `dialogs.h/.cpp` `TransferPasswordField`, `CExtOptionsDialog`, `CEnterPasswordDialog` |
| the prompt of the progress window hands over `WCHAR[PASSWORD_LEN]`; a cancel poll; a second task on one progress dialog | `7zthreads.h/.cpp` `WM_7ZIP_PASSWORD`, `WM_7ZIP_POLLCANCEL`, `LaunchAndDo7ZipTask` |
| open callback: typed text as it is; `PasswordAsked` / `PasswordTyped` | `open.h/.cpp` `CArchiveOpenCallbackImp::CryptoGetTextPassword` |
| extract callback: typed text, the form chooser, the retry list and the second pass, "told once" | `extract.h/.cpp` `CryptoGetTextPassword`, `GetStream`, `SetOperationResult`, `SetTotal`, `SetCompleted`, `DeferCurrent`, `BeginRetryPass`, `BeginRedoPass`, `EndRetryPass`, `IsEncryptedItem`, `BlockOf`, `ResetPasses` |
| update callback: typed text (the prompt there is unreachable), password wiped in the destructor | `update.cpp` |
| new archive / add: `UString` from the dialog, wiped after the call | `7zip.cpp` `PackToArchive` |
| the preferred form (test of an item, up to three blocks), the other form of the session password, the legacy attempt at open, the second pass, the rule for an update, wipe on every exit | `7zclient.h/.cpp` `TestPassword`, `ChooseForm`, `ChoosePasswordForm`, `PasswordOther`, `OpenArchive`, `Decompress`, `TestArchive`, `Update` (`CWipeOnExit`), `CreateObject(keepLoaded)` |
| pure rule: `SalArcPwdIsAscii`, `SalArcPwdLegacy`, `SalArcPwdHasLegacy` | `src/common/salarcpwd.h`, saltests `TestArchivePassword093` |

**The legacy form** is what the old code handed over, step by step: strict
UTF-8 of the field into a 128-byte buffer; when that failed (more than 127
bytes, or an unpaired surrogate) the old `EditLine` read the field as
code-page text cut to 127 bytes; the consumers then decoded the buffer with
`MultiByteToWideChar(CP_ACP, 0, ...)` (7-Zip's `MultiByteToUnicodeString`;
its body is the same call with the same flags in 16.04, which releases up to
0.1.8 carried, and in 26.03). Bytes the code page does not define (81 83 88
90 98 in 1250) come out as the C1 control of the same value - asserted in
saltests. A text of 64 or more two-byte characters therefore reached the
engine *correctly* in the old version (the code-page read), and one with
characters outside the code page as `?`; the helper reproduces both. (The
review checked the derivation against the old code: 800,776 cases, no
mismatch.)

**Design, as implemented after the review: a preference, then two passes.**

1. *The preferred form.* Right after a password is typed (once per typed
   password; 7z only; only when the text has a legacy form that differs)
   `C7zClient::ChooseForm` tests one encrypted item - a second handler object
   with its own file stream, no output - with the typed text, then with the
   legacy form. When both are refused the item may be damaged, so the
   cheapest item of the next block is asked, up to three blocks
   (`PWDTEST_BLOCKS`). The form that passes is the session password, the
   other one is kept beside it (`C7zClient::PasswordOther`, wiped with the
   session password). For encrypted headers `OpenArchive` does the same with
   the open itself. The preference covers the two common cases - everything
   under the typed text, everything under the legacy form - with one prompt
   and no garbage output. It is only a preference.
2. *First pass.* The requested items are extracted with the preferred form.
   While the password has another form, an **encrypted** item that fails with
   a data / CRC / wrong-password result is not reported: its index goes to
   the retry list in the callback (`RetryList`), a file the callback opened
   for it in this operation is deleted without a question (`DiscardOutFile`,
   the existing `HaveOutFile` rule - never a file it did not open for the
   current item), and it is not counted as an error.
   *Skipped items are not retried:* `GetStream` sets `CurrentDeclined` when
   it gives the engine no stream for a requested item (the user's Skip / Skip
   all, a file that could not be created); such an item never enters the
   list. Neither does an item the operation did not ask for
   (`CurrentRequested`); its failure in a block that is retried is no error.
3. *Second pass*, only when the list is not empty and the first pass ended
   normally (not after Cancel, not after an engine error): the same
   `Extract()` over exactly the list, with the other form, the **same
   callback** - overwrite-all / skip-all answers and counters go on - and the
   normal 087 handling and messages for whatever fails now. One exception,
   a *third pass*: an item that had output in the first pass and fails in the
   second without any is damaged, not mis-keyed - it is extracted once more
   with the form of the first pass through the ordinary path (keep-or-delete
   question, partial file).
4. *Which form the session keeps:* the preferred one; the other one only when
   no encrypted item succeeded in the first pass and at least one did in the
   second. Forgotten (both) when items still fail after the second pass, as
   before for any failed item.
5. *Result:* unchanged - `OPER_OK` only without failed items and skipped
   links; "Unpack and delete" keeps the archive otherwise.
6. *Progress:* a later pass continues the bar behind the earlier ones - its
   total is added to the total so far and its completed value is offset by
   it (`SetTotal`, `SetCompleted`, `ProgressBase`); the bar steps back once
   per pass, to done / (done + new), and goes on to the end.
7. An ASCII password or a RAR archive has no other form: no retry list, no
   second pass, the code path of the first pass is the old one.
8. Test archive, F3 view and copying single files go through the same
   callback (`TestArchive`, `Decompress`), so the same rule holds; in a test
   every item counts as requested.

**Update of an existing archive**: content that opens with the typed text -
the typed text; content that opens only with the legacy form - the legacy
form; content that opens with neither is under another password, and the
typed text is used without a message, exactly as for an ASCII password and
as 7-Zip itself allows (coordinator's decision; the first version refused).
An archive that already holds both forms **stays mixed**: the plug-in cannot
re-encrypt what is in it; the new items get the form of the first block that
answers.

**The independent review of the first version - REJECT**, and what was done:

- *Blocker - one form per archive is wrong for mixed archives.* 0.1.8 adding
  a file to an archive made by 7-Zip left two forms in one archive; the first
  version chose one form for the whole archive and could no longer open the
  other files (pre-093 could open its own). -> the two passes above.
- *Should-fix - the new "wrong password" message aborted the operation*, so
  an archive with files under two ASCII passwords unpacked nothing. -> told
  once per operation, the other blocks are still unpacked; the result is not
  `OPER_OK` and `Decompress` forgets the password.
- *Should-fix - a damaged cheapest item decided for the whole archive.* ->
  up to three blocks are asked, and a wrong preference now costs only time.
- Nits: `Update()` wipes its copy of the password on every exit
  (`CWipeOnExit`); saltests gained the 3- and 4-byte overflow cases and the
  unpaired surrogate at the 127/128 boundary; the probes remove their
  leftovers (`tc093_pwd_engine_*`, the registry backup once the restore is
  verified).
- Left as recorded: `CRetryableInFileStream(NULL)` may raise a box from the
  worker thread (the same pattern as `OpenArchive`); `WM_7ZIP_POLLCANCEL`
  does not disable Cancel.

**The second independent review - REJECT** (the two-pass design held; the
result accounting did not), and what was done:

- *Blocker - items the operation did not ask for were counted as errors.* The
  7z handler reports every item of a block up to the last requested one, the
  others in skip mode (`7zExtract.cpp`, `CFolderOutStream::OpenFile`). In the
  first pass such an item of a block read with the wrong form failed, was not
  deferred and was counted; the requested item then came out right in the
  second pass, but the operation was "not OK": the session password was
  forgotten (F3 on a file of a legacy block opened no viewer and asked again
  every time) and "Unpack and delete" kept the archive. -> in the first pass,
  under a two-form password, such a failure is only noted
  (`UnrequestedFailed`); `BeginRetryPass` drops it when a requested item of
  the same block goes to the second pass, and counts it - with the CRC
  message, as pre-093 - in any other block. With an ASCII password or RAR
  nothing changed: the old accounting, line for line.
- *Should-fix - a damaged item lost its recoverable part.* -> `DeferCurrent`
  remembers whether the first pass had written output for the item
  (`RetryHadOutput`). When such an item fails in the second pass at once,
  without output (the engine reports it in test mode), it is neither counted
  nor reported there; `BeginRedoPass` runs a third and last pass over those
  items with the form of the first pass through the ordinary 087 path - the
  keep-or-delete question, the partial file. One error, reported once. An
  item without output in the first pass is not redone; when the second pass
  itself produced output and asked, there is no third pass for the item.
- *Should-fix - the "skipped item" test worked by accident.* When `GetStream`
  gives no stream the engine downgrades the item to skip mode, so
  `ExtractMode` is false and the old test never matched. -> an explicit flag
  `CurrentDeclined`, set in `GetStream` where no stream is given for a
  requested item (the user's Skip, a file that could not be created, a name
  that could not be built); used in `SetOperationResult`; the comments cite
  the engine. A declined item is never deferred and, under a two-form
  password in the first pass, its failure is not an error (nothing of it was
  to be written).
- Nits: a retry list that cannot be run counts as failed items
  (`BeginRetryPass`); M7's expectation says what it proves (each Unpack
  command is a new session) and the re-prompt inside one session is row V1;
  the probe ignores the system's "UAC Input Indicator" windows of a hidden
  desktop.

Found on the way:

- **The engine library was reloaded on every `CreateObject`**
  (`CLibrary::Load` frees first). Harmless while no engine object was alive;
  the second handler is created while one is, so `CreateObject` got
  `keepLoaded`.
- **A wrong password on a content-encrypted 7z archive produced nothing and
  said nothing** (since the 26.03 engine, feature 087; the note "no error
  window" above). The 7z handler reports the items of a block it cannot
  decode in *test* mode, and the callback's test branch left a data error to
  "the caller", which for an extraction is nobody. Now one message per
  operation (`IDS_DATA_ERROR_PWD` / `IDS_DATA_ERROR`, existing strings), for
  an item the operation asked for; nothing is aborted.
- **A second task on one progress dialog recursed until the stack ran out**:
  `LaunchAndDo7ZipTask` subclassed the dialog again and took its own
  procedure for the old one. The first run of the second pass crashed on it
  (the files were already unpacked); the dialog is now subclassed once.

**The re-review - ACCEPT**, with one more should-fix and notes:

- *A skipped file could turn a clean operation into a reported failure.* A
  declined item is never on the retry list, so its block looked "not
  retried" and the failures of the block's unrequested items were counted
  (a "CRC failed" message, the archive kept, the password forgotten). Seen
  with a Delta filter, where output precedes the failure and the overwrite
  question is asked in the first pass. -> the block of a declined item that
  failed the wrong-form way is remembered (`DeclinedBlocks`) and counts as
  retried in `BeginRetryPass`. Rows D1 and D2.
- Recorded, not changed: an item that fails *with* output in both passes
  (stored or Delta data, damaged, under the preferred form) gets the
  keep-or-delete question for the output of the second pass, not for the
  partial data of the first (the third pass only covers "no output in the
  second pass"). The `handled` return in `SetOperationResult` comes before
  the `E_STOPEXTRACTION` check - harmless, the engine runs to the end of the
  pass.
- Driven by the reviewer: a real F3 view from the panel on the mixed archive
  opens after one prompt and later files open without a prompt; the ASCII
  rows are identical to pre-093 except for the one new message. Not tested
  by anybody: the passes of the *Test archive* command, a cancel or an engine
  error during the second or third pass, a real disk-full failure to create
  a file, RAR.

**Probes.** `probe/pwd_engine_probe.ps1` (7z.exe 22.01 makes the archives,
the built `7za.dll` opens them through 087's `7zdrive.exe`, which got
`-pu:<hex units>`): 53 checks, 0 unexpected (`pwd_engine_result.txt`).

`probe/pwd_gui_probe.ps1` through the product, 29 rows, run on a hidden
desktop (`tools/run_on_hidden_desktop.ps1`); final build
`pwd_gui_result.txt`, pre-093 `pwd_gui_result_pre093.txt`:

| Row | | S2 (final) | pre-093 |
|---|---|---|---|
| U1 | by 7-Zip, content, `heslo-ř` | unpacked, equal | nothing, no message |
| U2 | by 7-Zip, headers, `heslo-ř` | unpacked | "Cannot open archive" |
| U3 | legacy, content, typed `heslo-ř` | unpacked once, one prompt, no message | unpacked |
| U4 | legacy, headers | unpacked | unpacked |
| U5 / U6 | Cyrillic, content / headers | unpacked | nothing / "Cannot open" |
| U7 | ASCII control | unpacked | unpacked |
| U8 / U9 | wrong password (ASCII / non-ASCII), content | one message, nothing unpacked | nothing, **no message** |
| U10 | wrong password, headers | "Cannot open archive" | the same |
| M1 | mixed: a, b typed (7-Zip) + c 22 KB legacy; typed `heslo-ř` | all three equal, one prompt, no message | only c.txt |
| M2 | the same, tiny c (the cheapest item is the legacy one) | all three equal | only c.txt |
| M3 | only c.txt (mask in the Unpack dialog) | c.txt equal | c.txt equal |
| M4a / M4b | ASCII mixed (pw1: a, b; pw2: zadded), typed pw2 / pw1 | zadded / a, b unpacked; one message | the same files, **no message** |
| M5 | legacy, not solid, packed bytes of the smallest item flipped | intact file unpacked, one message | intact file unpacked, no message |
| M6a / M6b | existing a.txt in the target, Skip (met in pass 1 / pass 2) | asked once, the user's file unchanged, b and c unpacked | a and b never reached (wrong form), c unpacked |
| M7 | wrong non-ASCII password, then a second Unpack with the right one | one message, nothing left; second unpacks | no message; second unpacks nothing (U1) |
| V1 | in the panel: block a, b, e legacy + d typed; e.txt copied out twice | equal both times, asked once | the same |
| X1 | the same archive, mask e.txt, "Delete archive after unpacking" | e.txt equal, archive deleted | the same |
| Z1 | legacy, not solid, 2.7 MB p.txt with 16 packed bytes flipped + s.txt; Keep | s.txt equal, question once, about 1.34 MB of p.txt kept | the same |
| D1 | a, b (Delta filter, typed) + tiny c (legacy); mask b.txt, existing b.txt, Skip, "Delete archive" | asked once, the user's file unchanged, no message, archive deleted | b.txt never reached (wrong form), archive kept |
| D2 | control: the same without an existing file | b.txt equal, archive deleted | nothing unpacked, archive kept |
| P1 | new archive, `heslo-ř` | 7-Zip: typed yes, legacy no | typed no, legacy yes |
| P2 | add to a legacy archive | whole archive tests with the legacy form | the same |
| P3 | add to an archive by 7-Zip | whole archive tests with the typed text | two passwords in one archive |
| P4 | add to an archive with another password | added file tests with the typed text, the original files with their own password, no message | added file encrypted with the legacy form |
| P5 | new archive, 70 Cyrillic letters | 7-Zip tests it | does not |
| | | **29 PASS** | 9 PASS, 20 FAIL |

The expectations describe the fixed behaviour, so a pre-093 FAIL is the
defect (or, for M4 and M5, only the missing message). V1, X1 and Z1 pass on
both builds: they are the regressions the reviews found in the earlier S2
builds. Z1's kept size differs by a few bytes between runs - each run makes
its own archive with a random salt, and where the decoder notices the damage
depends on it. For the same reason a wrong password now and then lets the
decoder write some output before it fails; the plug-in then asks its
keep-or-delete question first, as pre-093 did (seen once in M4a) - the
one-message rows M4 and M5 allow that question, U8, U9 and M7 could still
fail on such a run. M3, X1, D1 and D2 use the mask of the Unpack dialog; V1 copies from
inside the archive in the panel (`CM_COPYFILES`), not F3.

saltests 12,904 -> 12,943; `check_encoding.py --strict` TOTAL 0; 087's engine
probe 33 PASS.

Not driven / open:

1. Cancel during the test of a large item (the poll through
   `WM_7ZIP_POLLCANCEL` / `ProgressAddSize(0)`) and Cancel during any pass;
   the cost on a large archive: the test decodes the cheapest encrypted item
   once more (up to six tests when everything is refused), with the progress
   bar standing still. During an update the test runs on the main thread.
2. The passes in *Test archive* and F3 view were not driven (the same
   callback; V1 drives the panel session through F5). *Delete from archive*
   was not driven.
3. A damaged item under a two-form password: when the first pass wrote
   output for it, it is redone in the third pass and the user gets the
   keep-or-delete question and the partial file as before (Z1); with stored
   (uncompressed) data the second pass writes output itself and asks there.
   The partial file of the first pass is deleted and written again, so the
   damaged item is decoded up to three times.
4. An item the operation did not ask for that fails in the first pass in a
   block of which a requested item is retried is dropped from the count; if
   the second pass does not reach it again (it lies behind the last retried
   item) a real CRC error of such an item is no longer counted. Two-form
   passwords only.
5. In a mixed archive whose items alternate between the forms inside one
   operation, every item of the minority form is decoded twice.
6. The password fields cannot be read back from another process
   (`ES_PASSWORD`), so the probe proves the 127-character limit and the long
   password only by the result (P5).
7. An update may add a second password to an archive, as before and as
   7-Zip does - with any password; only the two forms of ONE typed password
   are kept from meeting in an archive that does not hold both already.
8. A machine with another code page gives another legacy form; an archive
   made by 0.1.8 on a machine with code page X opens through the retry only
   on a machine with code page X.
9. The edit control keeps its own copy of the typed text until the dialog is
   destroyed; only the plug-in's buffers are wiped.

## S3 - the command line

**Cause.** The combo box and its inner edit are Unicode controls of
comctl32 6 whichever call creates them; each was turned into a code-page
window by the core's own code-page subclass: `CEditWindow` (the combo, attached
inside `CreateEx`) and `CEditLine` (the inner edit, `AttachToWindow`), both
`CWindow` objects with the default `unicodeWnd = FALSE`. Established with two
throw-away builds and `probe/cmdline_probe.ps1`:

| Build | combo / edit Unicode | set through the combo | set to the edit | typed |
|---|---|---|---|---|
| pre-093 (both code-page subclasses) | False / False | lossy | lossy | lossy |
| combo wide, edit attached the old way | True / False | lossy | lossy | lossy |
| combo the old way, edit keeps its kind | False / True | lossy | ok | ok |
| S3 (both) | True / True | ok | ok | ok |

So each subclass loses the text that passes through its own window; both had
to change.

**What changed** (`src/editwnd.cpp` unless said otherwise):

| What | Where |
|---|---|
| the combo is a Unicode `CWindow` created with `CreateExW`; the edit is attached with `AttachToWindowKeepKind` | `CEditWindow::CEditWindow`, `CEditWindow::Create` |
| the typed-character switch takes the whole UTF-16 unit - cut to a byte, U+010D (`č`, on every Czech keyboard) would have run the command and U+0109 changed the panel | `CEditLine::WindowProc` `WM_CHAR` |
| the command is read wide; a command whose UTF-8 form does not fit `SALCMDLINE_MAXLEN` is refused with the existing "too long" message instead of being run cut short | `CEditLine::WindowProc`, Enter |
| the selection a plug-in file system returns (bytes of its UTF-8 `command`) is converted to UTF-16 units | the same; `SalU8OffsetToW` in `src/common/salunicode.*` |
| Alt+Enter sends its `WM_CHAR` wide | `CEditLine::WindowProc` |
| word breaking (Ctrl+Left/Right, double click) works on the UTF-16 text itself - the old callback converted to the code page first, which moved every offset behind a character outside the BMP | `EditWordBreakW`, `EditWordBreakProcUNICODE` |
| Ctrl+Backspace reads the text wide under comctl32 6 and uses the same routine | `BSHandlerSubclassProc` |
| drag and drop: the line's text, the drop position and the width of the last character in UTF-16 units (a surrogate pair is one character); dropped Unicode text is inserted as it is (it was converted to the code page first), dropped code-page text is converted properly | `CEditDropTarget` (`TextBuff`, `HitTest`, `InsertText`, `DragEnter`, `Drop`) |
| the width of the path prefix is measured wide, as it is drawn (the old code measured the UTF-8 bytes as code-page characters, so EVERY path with a non-ASCII character got too much room, also one inside the code page - reviewer's measurement: ASCII folder 346 px on both builds, code-page folder 358 -> 315 px, the probe's folder 338 -> 308 px; a correct fix, and the one visible change for code-page text) | `CInnerText::GetNeededWidth` |
| stored content: length in units | `CEditWindow::StoreContent` |
| comment only | `fileswn0.cpp` (the forward of a character typed in the panel was already `PostMessageW`) |

Looked at and left as they are: `CEditLine::InsertText` (already a wide
`EM_REPLACESEL`), `SalSetWindowTextU8` after a command, `FillHistory`
(`SalComboAddStringU8`), the history comparison and the password stripping of
feature 085 (UTF-8 strings), `StoreContent` / `RestoreContent` selection
(`EM_GETSEL` and `EM_SETSEL` of the same control, units both ways),
`EM_SETSEL 0,-1`, `SetWindowText(HWindow, "")` on Esc, `CB_LIMITTEXT`
(a limit in units, as before), `AttachBackspaceHandler` (W/A aware since
feature 015), the prefix window itself (a code-page `STATIC` that paints its
own text wide; its window text is empty).

**Plug-ins.** No service returns the command line's text or its window.
`CPluginFSInterface::ExecuteCommandLine` gets the command as UTF-8 (since
feature 005) in a `SALCMDLINE_MAXLEN + 1` buffer and the edit as dialog
parent - unchanged; the selection it returns is now applied correctly for
non-ASCII text. `CSalamanderGeneral::InstallWordBreakProc` installs the
routines above on a plug-in's own control: same breaks for text of a
single-byte code page. Interface 107, no change.

**Probe** `probe/cmdline_probe.ps1` (hidden desktop), 64 rows; text cases
ASCII / code page (`ř ž č`) / outside it (Cyrillic, CJK, a surrogate pair):

| Row | | S3 (`cmdline_result.txt`) | pre-093 (`cmdline_result_pre093.txt`) |
|---|---|---|---|
| C1 | combo / edit are Unicode windows | True / True | False / False |
| C2 | set by the program (to the combo, to the edit), read back | 6 PASS | outside the code page: `?` |
| C3 | typed (posted `WM_CHAR` per unit) | 3 PASS | outside the code page: `?` |
| C3 | typed `x č ĉ y`: no Enter, no Tab | PASS | `ĉ` arrives as `c` |
| C4 | Ctrl+Enter inserts the name of each of 5 files (name + space, no quotes - also for `a b.txt`, both builds) | 5 PASS | Cyrillic, CJK, emoji: `??.txt` |
| C5 | the same into the middle of `ab`: text, caret, the next typed character | 15 PASS | ASCII and code page: text and next character PASS; the others not driven |
| C6 | `copy nul "<name>.flag"` + Enter: the file on disk; the line is empty afterwards | 6 PASS | outside the code page: no such file (the line held `??????`) |
| C7 | first item of the drop-down = the command; Ctrl+Down recalls it; stored `Command History` after a normal exit; URL password stripped (085) | 9 PASS | outside the code page: `?` in the list and in the registry |
| C8 | Ctrl+Backspace twice (word, then up to the dot); Backspace on `ab`, `ař`, `aЖ`, `a📁` | 10 PASS | outside the code page: FAIL (text already `?`; the emoji is two `?`, Backspace leaves one) |
| C9 | prefix: code-page `Static`, empty window text, width 308 px | info | 338 px |
| C10 | ASCII: typing, Home / End / Left / Shift+Left by where the next character lands, Esc clears, focus edit -> panel | 7 PASS | 7 PASS |
| | | **63 PASS, 0 FAIL** | 37 PASS, 17 FAIL, 3 not driven |

Two of the 17 are not defects of the old build: C5 "caret" for the ASCII and
the code-page name. Through a code-page subclass the reply to a cross-process
`EM_GETSEL` is not the caret (it read `4,0 5,0 6,0 7,0` = the text length
while Home / End / Left demonstrably moved it), so on the old build the caret
is proven only by where the next character lands - which passes. No offset
defect for code-page text was found in the old build: it never computed an
offset from UTF-8 bytes on a path the probe reaches.

Keys with Ctrl / Shift are driven by `AttachThreadInput` + `SetKeyboardState`
from the probe and sent `WM_KEYDOWN` / `WM_KEYUP`; no input is injected.

`probe/dialogs_probe.ps1`, hidden desktop, 140 rows after the menu rows were
reworked (below):

| Build | PASS | LOSSY | FAIL | NOT DRIVEN |
|---|---|---|---|---|
| S3 (`s3_dialogs_result.txt`) | 139 | 0 | 0 | 1 |
| pre-093 (`s3_dialogs_result_pre093.txt`) | 109 | 30 | 1 | 0 |

The two command-line rows are PASS on S3. The one FAIL of the old build is
Find's search (its lossy *Look in* finds nothing).

**"Find menu by Alt+F" was a probe artefact, not a defect.** The first S3 run
of the probe failed that row (and the build of HEAD without S3 failed it the
same way). The independent review found the cause: the popup does open,
within 40 ms, on both builds; on the hidden desktop something closes it about
0.4 s later when the row runs right after a search that FOUND an item, and
the probe looked only after 0.8 s. The pre-093 build "passed" only because
its lossy *Look in* found nothing and the probe then waited 8 s before the
row; with an ASCII folder pre-093 fails the same way 3 of 3. On the
interactive desktop the menu stays open on both builds. The likely closer is
`MenuMessageHookProc` (`src/menu1.cpp`), which closes menus on any
`WM_ACTIVATE` / `WM_NCACTIVATE` / `WM_KILLFOCUS` in the thread; only the hidden
desktop has the extra "UAC Input Indicator" windows.

The rows now: the menu bar is driven BEFORE Find Now; a popup is detected by
polling every 40 ms for 2 s ("opened at least once", one more attempt when
none shows up - never needed in the saved runs); every top-level mnemonic is
driven - Find `F M E V O`, main window `L F E C P O R H` - three ways: Alt+
letter as a posted `WM_SYSCHAR`, the plain letter inside the menu bar's own
loop after Esc closed the popup, and Alt+letter as a posted `WM_SYSKEYDOWN`
with Alt in the shared key state. Hidden desktop: main 24 / 24 on both
builds; Find 15 / 15 on pre-093 and 14 / 15 on S3 - the one NOT DRIVEN is
"plain F in the menu bar loop", where the first popup of the run went away by
itself before the probe's Esc (the effect above; it differs from run to run).
The popup positions are identical on both builds, row by row.
**The interactive-desktop matrix is the reviewer's run, not this probe's**:
main 16 / 16 and Find 10 / 10 on both builds, identical popup positions. An
interactive run of this probe was started and stopped (the user was working
at the machine); nothing of it is kept. A check with a real keyboard is owed
to a person.

saltests 12,943 -> 12,973 (`TestCmdLineOffsets093`); strict guard TOTAL 0;
Debug build only (no Release build in this stage).

**Independent review - ACCEPT.** Its own evidence, beyond the probes:

- Word-break callbacks fuzzed against the old ones: ASCII text 9,897,591
  calls, 0 differences; code page 1250 text, the old Unicode callback against
  the new one, 3,600,000 calls, 0 differences; arbitrary UTF-16: no result
  out of range and no break inside a surrogate pair.
- The rewritten `CEditDropTarget` exercised in a harness, 25 cases: the same
  results as the old class for ASCII and code-page text.

Not driven / open:

1. A real mouse drag through OLE onto the command line and the painting of
   the insert mark (the class was run only in the reviewer's harness).
2. The selection returned by a plug-in file system (`SalU8OffsetToW` at the
   call site; the shipped plug-ins looked at return an empty line), Alt+Enter,
   `StoreContent` / `RestoreContent` (the temporarily shown command line),
   Ctrl+Shift+Enter (short name), Ctrl+[ / ] / Space (path insertion), Tab.
3. Ctrl+Left / Ctrl+Right and double click in the product (the control calls
   `EditWordBreakProcUNICODE`; fuzzed by the reviewer, and Ctrl+Backspace,
   which uses the same routine, was driven).
4. A real keyboard (also for the menu mnemonics), an input method editor,
   paste from the clipboard, the dark theme, a system with a double-byte code
   page.
5. The word-break routine no longer treats a character the code page maps to
   a delimiter by best fit (e.g. a full-width full stop) as a delimiter.
6. The "too long" refusal was not driven. It is reachable only when the
   UTF-8 form of the line exceeds 8,192 bytes (the line holds about 8,150
   UTF-16 units, so only with non-ASCII text - e.g. more than about 2,700 CJK
   characters). The message is the existing one and says "path"; the pre-093
   build failed there with error 123 (the text re-read through the code
   page), S1 would have run the command cut short.
7. The main window's title still shows `?` for such a folder (the main
   window is a code-page window) - seen again, not part of the stage.
8. The probe leaves nothing; `dialogs_probe.ps1` leaves its registry backup
   in `%TEMP%` as before.
9. The probes export and restore the whole registry key; an installed copy
   of the program running at the same time (seen during the last runs) shares
   that key - a setting it saves while a probe runs is rolled back by the
   restore.

## S4 - gates

All windows on the hidden desktop (`tools/run_on_hidden_desktop.ps1`); the
maintainer closed the installed program for the final runs.

| What | Result |
|---|---|
| Debug build; full Release build (`build.cmd full release`: 20 plug-ins, 189 language modules, runtime closure OK) | no errors |
| saltests | 12,973 checks, 0 failed |
| `check_encoding.py --strict` | TOTAL: 0 |
| 093 `dialogs_probe` | 139 PASS, 0 LOSSY, 0 FAIL, 1 NOT DRIVEN (pre-093: 109 / 30 / 1) |
| 093 `cmdline_probe` | 63 PASS, 0 FAIL (pre-093: 37 / 17) |
| 093 `pwd_gui_probe` | 29 PASS, 0 FAIL (pre-093: 9 / 20) |
| 093 `pwd_engine_probe` | 53 checks, 0 unexpected |
| 092 `build_and_run.cmd` | both probes pass |
| 092 `focus_probe`, the ten NEW rows | 10 PASS |
| 089 `assoc_probe` | RESULT: PASS |
| 087 `run_engine_probe.py` on the Debug `7za.dll` | 0 failed |
| 088 `viewers_probe`, `longpath_probe` | see below |
| registry key after everything | identical to the state before (SHA-256 `CDC4CF03...`) |

**The 088 probes on the hidden desktop** were written for the visible
desktop and count every window they did not expect:

- `longpath_probe`: every step shows the right file in the right viewer
  (titles in the log); 8 rows are marked FAIL only because the two system
  windows of a new desktop (`UAC Input Indicator`) are counted as unexpected.
- `viewers_probe`, two runs of the new build and one of the pre-093 build:
  row N3 fails on both builds for the same reason (two "other windows").
  Rows P1 / P3 / P5 failed in one run of the new build, passed in the next,
  and P1 / P5 failed on the **pre-093** build as well: the first Code Viewer
  (WebView2) start on a desktop that is not the input desktop sometimes takes
  over 30 s. Not attributable to this feature; the rows passed 10/10 on the
  visible desktop after feature 092, and nothing in 093 touches the viewers'
  close path. Owed: one run of the two 088 probes on the visible desktop when
  the machine is free (and making them ignore the two system window classes).

**Shared registry key.** The GUI probes back up, change and restore the whole
key `HKCU\Software\Tandem Commander`. An installed instance running at the
same time reads the probe's temporary settings if it starts during a run,
and loses what it saves during one. One probe run was killed mid-way on the
maintainer's request; the key was restored from the probe's backup and
verified. Recorded as a limit of the probes (they need a way to point the
program at another key).

**Not done / owed to a person**: `quickstart.md` - the real-keyboard pass
(menus first), an input method editor, a mouse drag onto the command line.
