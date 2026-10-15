# Fix log: 214 - the Copy / Move dialog never cuts the typed text

Backlog (left by 141, `specs/NEXT-WORK.md`): `CCopyMoveDialog::Transfer` cuts typed text that does
not fit the caller's buffer (by reading: Create Directory on a plug-in file system, 174 CJK letters
typed, the plug-in gets 173).

## Measured (before)

The dialog limits its field in UTF-16 units (`CB_LIMITTEXT` / `EM_LIMITTEXT` of the buffer's size
- 1), but the caller's buffer holds UTF-8 bytes - up to three per unit. `SalGetWindowTextU8` /
`EditLine` cut text that does not fit at a whole character (093), and the caller acted on the
shorter text - another path.

Probe `probe/cm_text_probe.ps1` (204's driver: F5 out of a ZIP, command 727 -
`CFilesWindow::UnpackZIPArchive`, a buffer of 260 bytes), the build at 212
(`probe/result_before.txt`):
- **long**: the target typed as `tgt\A\sub\` where `tgt\A\` has exactly 259 UTF-8 bytes (A: CJK
  letters padded with `a`, about 180 UTF-16 units - fits the field): the text was cut to
  `tgt\A\`, the program asked nothing and **unpacked `x.txt` into `tgt\A` - another folder than
  the one typed**.
- ctl (`tgt\short\`): asked "create it?", `x.txt` in `tgt\short`.

(A first version of the row, `tgt\` + 70 CJK letters + `\`, was refused by luck: the cut text
lost its trailing backslash and was taken for a mask - "Operation masks are not supported".)

## Work

`src/dialogs3.cpp`, `src/dialogs.h`:
- `CopyMoveTargetTextFits` (static): the UTF-8 size of the whole text of `IDE_PATH` (`SalWToU8`, WTF-8
  for a lone surrogate) against the caller's buffer; when it does not fit, "The path specified is
  too long." (`IDS_TOOLONGPATH`, an existing string) and the field marked - the dialog stays open;
- `CCopyMoveDialog::Validate` (new; also `CEditNewFileDialog`) and `CCopyMoveMoreDialog::Validate`
  (first) call it.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 4 / 0 (the final build): long - "The path specified is too long.", the dialog back (the probe
cancels it), `tgt` empty; ctl as before. Regression: 204's probe 22 / 0 (`probe/regress_204.txt`,
F5 out of archives and Alt+F9 through these dialogs).

## Review

Refute-first review: accept, no MUST / SHOULD. Every caller's buffer size checked (Edit New and
Create Directory on disk `SAL_MAX_PATH_UTF8`; Create Directory on a plug-in file system and its
copy 520; Quick Rename 780 - it relied on the cut: a relative target `sub\<long name>` became
another valid name, now refused; Unpack 260; Copy / Move with options `SAL_MAX_PATH_UTF8`). None
overrides `Validate`; IDOK always goes through `CDialog::DialogProc` (Validate, then Transfer);
the folder helper, `WM_USER_KEYDOWN` / `WM_USER_BUTTON` and Edit New's browse menu never close the
dialog. `SalWToU8(w, -1, NULL, 0)` counts the terminator also through the WTF-8 path; an empty
text passes. Wider than the probe: `CB_LIMITTEXT` limits typing only - a history entry (any length,
from Copy / Move) or a set text was cut too, also plain ASCII. Taken NITs: the comment's sizes,
the helper `static`. Kept: when there is no memory to measure, the refusal says "too long".
Recorded in `specs/NEXT-WORK.md` (the same cut elsewhere): Make File List's output file and line
(`dialogs.cpp` 1270 / 1950 / 1914 / 1931 - a cut name is written or appended to), the drive's "go
to" path (`dialogs5.cpp:1884`), the user menu (`dialogs4.cpp:2215-2217`) and viewers / editors
(`dialogs5.cpp` 2125-2127, 2507-2509 - a cut command runs another program), the hot path editor's
`GetDlgItemText` fallback (`dialogs4.cpp:2924-2926`, code page), low risk: Edit New's default
(`dialogs3.cpp:600`) and the browse-from-field cuts (`salamdr3.cpp:4349`, `dialogs5.cpp:1923`,
`dialogs2.cpp:1287`).
