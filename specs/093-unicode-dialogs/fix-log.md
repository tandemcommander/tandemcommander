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
