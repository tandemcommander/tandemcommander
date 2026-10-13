# Feature 131 - 7-Zip plug-in (`src/plugins/7zip`)

Source: `specs/130-plugin-mixed-templates/triage/7zip.md`, section 4 "Other defects seen".
**Nothing of the repository was built or run.** Two small programs of my own were compiled with
`cl` (x64) and run outside the repository (`%TEMP%\claude\...\scratchpad\t131\vararg.cpp`,
`zr_settext.cpp`); their output is quoted below. Line numbers are those after the edits.

Changed files (3): `dialogs.h`, `dialogs.cpp` (a comment), `FStreams.cpp`. BOM and CRLF kept.

| # | Item | Verdict |
|---|---|---|
| 1 | `dialogs.cpp:599` `SetWindowText` (A) of the archive path - "garbled for any non-ASCII path" | NOT A DEFECT (the note was wrong; the fix it proposed would have broken it) |
| 1b | `dialogs.h:118` the path cut at `MAX_PATH` | FIXED - shown only; a cut inside a character garbled the whole path |
| 2 | `FStreams.cpp:39` `((int*)&err)[1]` | FIXED - real on x64: a random number chose the plural form |
| 3 | `7zip.cpp:274-281` the message shortened by `_TRUNCATE` | NOT A DEFECT (a message; tail trim present since 130) |
| 4 | `7zip.cpp:206`, `:240` `Warning`, `Error(HWND, ...)` still `LoadStr` | UNREACHABLE (no caller) - left |

---

## 1. Pack options dialog: the archive path in `IDC_NA_ARCHIVE`

**The note of 130:** "`SetWindowText` (A) of the archive path (`Archive`, UTF-8 from the core)
into the static `IDC_NA_ARCHIVE` - a code-page sink: an archive path with letters outside ASCII
is garbled there in every language. The fix is `SetWindowTextW` + `SplU8ToWAlloc`."

**Found: not a defect - the control is not a plain static.** `CExtOptionsDialog::CreateChilds`
(`dialogs.cpp:571-580`) attaches the core's static text to it before the text is set:
`SalamanderGUI->AttachStaticText(HWindow, IDC_NA_ARCHIVE, STF_PATH_ELLIPSIS)`. That is the
core's `CStaticText`:

- it subclasses the control with the code-page window procedure (`CStaticText::CStaticText`,
  `src/gui.cpp:443-444` -> `CWindow(hDlg, ctrlID)` -> `AttachToControl` -> `AttachToWindow`,
  `src/common/winlib.cpp:251-273`, `302-314`: the `A` `SetWindowLongPtr` of a non-Unicode build,
  `UnicodeWnd` not set);
- its procedure takes `WM_SETTEXT` itself: `src/gui.cpp:1098-1101` `return SetText((char*)lParam)`;
- `SetText` reads the bytes as **UTF-8 first** and as code page only when they are not valid
  UTF-8: `src/gui.cpp:626-629`.

So `SetWindowTextA(hStatic, <UTF-8 bytes>)` hands exactly those bytes to `SetText`, and the path
is drawn right. **A `W` call would be the defect:** the system converts the text to the code
page for a window whose procedure is `A`.

Run outside the repository (`zr_settext.exe`: a never-shown message-only `STATIC`, subclassed
with `SetWindowLongPtrA`, the text `C:\žluť\日.7z`; ACP 1250):

```
IsWindowUnicode after the A subclass = 0
SetWindowTextA  received bytes: 43 3A 5C C5 BE 6C 75 C5 A5 5C E6 97 A5 2E 37 7A   (the UTF-8, unchanged)
SetWindowTextW  received bytes: 43 3A 5C 9E 6C 75 9D 5C 3F 2E 37 7A               (cp1250, the CJK letter is '?')
```

**Change:** none in behaviour. `dialogs.cpp:598-601` got a comment that says why the `A` call
is the right one here, so that the note of 130 is not "fixed" later.

**How a user sees it (unchanged, right):** Alt+F5, packer 7-Zip, archive name
`C:\Žluťoučký kůň\日本.7z`, with *Show extended options* on: the dialog shows the path with its
letters.

**Probe row:** open that dialog for the archive `...\Žluťoučký kůň\日本.7z`; the control is
owner-drawn by the core, so read it with `WM_GETTEXT` through the `A` procedure
(`SendMessageA(WM_GETTEXT)`): expect the UTF-8 bytes of the path (`src/gui.cpp:1103-1114`
returns `Text` as it was set) - and a screenshot row for a person.

**Not sure about:** the drawing itself was read (`gui.cpp:626-629`), not seen on a screen.

## 1b. `SetArchiveName` cut the path at `MAX_PATH` bytes

**The note:** "`dialogs.h:118` cuts the path with `lstrcpyn(Archive, archiveName, MAX_PATH)`
(display only, but it can cut inside a character)."

**Found: real, display only.** `Archive` is used in exactly one place - the `SetWindowText` of
item 1 (`dialogs.cpp:601`; the archive that is written is `fileName` in `7zip.cpp`, never
`dlg.Archive`). So no operation runs on a cut path. But the cut is by bytes: a path of 260 or
more UTF-8 bytes whose 259th byte falls inside a character (every second position of Czech
text, two of three of CJK) leaves a torn sequence, the text is no longer valid UTF-8, and
`CStaticText::SetText` shows the **whole** path through the code page (`gui.cpp:628-629`).

**Reach:** pack into an archive whose full path is 260 bytes or longer and has letters outside
ASCII, e.g. a folder chain of 130 `ž` (long paths are supported since interface 104), with the
extended options dialog on. Before: the path line is mojibake from its first accented letter.

**The fix (`dialogs.h:94`, `:116-120`):** `Archive` is 1,024 bytes and the copy is
`SplU8CopyTrunc` - a path up to 1,023 bytes is shown whole (the control shortens it with its
own path ellipsis), a longer one is cut at a whole character. `SplU8CopyTrunc` comes from
`splunicode.h` (`precomp.h:34`).

**Probe row:** as in item 1 with a path of 300 bytes of `ž` folders: `WM_GETTEXT` (A) gives the
whole path as valid UTF-8 (before: 259 bytes ending in `C5`).

**Not sure about:** a path over 1,023 bytes still loses its end (the file name) in this line;
keeping the whole path would need a heap copy and a check of what the core's control costs for
a 30,000-unit text (feature 102 measured 28 s for `DT_PATH_ELLIPSIS` on such a text in another
control) - not done.

---

## 2. `FStreams.cpp` `ShowRetryAbortBox`: the plural form of "Could not write %d byte{|1|s}."

**The note:** "`((int*)&err)[1]` reads the first variable argument through the address of the
`err` parameter (works on x64 only by the layout of the home area)."

**Found: real, and it does not work on x64.** The function is
`ShowRetryAbortBox(HWND hParentWnd, int resID, DWORD err, ...)`; `err` is the third argument
(`r8d`), the first variable argument the fourth (`r9`). The callee stores the registers into
their home slots, 8 bytes each: `&err` is the slot of `r8`, the variable argument is 8 bytes
further - `((int*)&err)[2]`. `((int*)&err)[1]` is the **upper half of the slot of `err`**, which
the 32-bit store of `r8d` does not write: whatever was on the stack.

Run outside the repository (`vararg.exe`, the same signature, MSVC 19.40 x64):

```
/Od: vsnprintf saw 4194304, ((int*)&err)[1] = 573, ((int*)&err)[2] = 4194304
     vsnprintf saw 1,       ((int*)&err)[1] = 573, ((int*)&err)[2] = 1
/O2: vsnprintf saw 4194304, ((int*)&err)[1] = 668, ((int*)&err)[2] = 4194304
     vsnprintf saw 1,       ((int*)&err)[1] = 668, ((int*)&err)[2] = 1
     va_arg reads the argument in both builds
```

So the number in the sentence is right (`_vsnprintf_s` uses the `va_list`), and the **plural
form is chosen by a random number**: in English "Could not write 1 bytes." or "... 4194304
byte."; in Czech / Slovak / Russian (three forms) any of the forms. (On x86 the expression did
read the argument - the code predates x64.)

**Reach:** only `IDS_CANT_WRITE` has the `{!}` plural form (`lang/lang.rc2:100`); it is shown by
`CRetryableOutFileStream::Write` (`FStreams.cpp:146`) when `WriteFile` fails while a member is
extracted - target volume full, a removed USB stick, a network share gone. The user sees the
Retry / Abort box with the wrong word form.

**The fix (`FStreams.cpp:38-50`):** the number is taken with `va_start` / `va_arg(arglist,
UInt32)` / `va_end` (both callers pass a `UInt32`: `:146` `size`, `:244` `size`; `:244` uses
templates without `{!}`, so the argument is read only when there is a plural form) and given to
`ExpandPluralString` in a local `CQuadWord`.

**Probe row:** extract a member larger than the free space of a small target volume (a 1 MB VHD
or a RAM disk prepared by the probe): the box text must be "Could not write N bytes." with the
form that fits N, then an empty line and the Windows reason; and with a remaining size of 1:
"Could not write 1 byte." Hard to drive the size to 1 - the unit case is better.

**Unit case (if the choice is ever moved out):** `IDS_CANT_WRITE` expanded for 0, 1, 2, 5,
4194304 in English and Czech.

**Not sure about:** not compiled in the plug-in (`UInt32` and `CQuadWord` are used elsewhere in
the file; `CQuadWord count; count.SetUI64(...)` replaces the temporary whose address was taken).

---

## 3. `7zip.cpp:274-281` (`SysError`)

`msg[1024]` filled with `_TRUNCATE`, then joined with the Windows reason; a very long path
shortens the message. A message, never a name that is used; 130 added the tail trim. Not a
defect - nothing changed.

## 4. `7zip.cpp:206`, `:240` (`Warning`, `Error(HWND, ...)`)

Still `LoadStr`; no caller in the plug-in (130 found none, a search for `Warning(` / `Error(h`
callers confirms the 130 table). Unreachable - left; when a caller with a name is added they
need `LoadStrU8` like `Error(resID, ...)`.
