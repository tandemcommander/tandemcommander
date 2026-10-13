# Feature 131 - File Comparator (`src/plugins/filecomp`)

Session 2026-10-13. Nothing was built or run; the verdict is from reading. File changed:
`dialogs4.cpp` (one statement).

## 5. `dialogs4.cpp:101` - the font description printed into `LOGFONT::lfFaceName`

**Note of 130:** `sprintf` of `"%d pt. %s"` (`IDS_FONTDESCRIPTION`) into the 32-byte `lfFaceName`
of a `LOGFONT`: overruns the stack for a font name longer than about 22 characters.

**Found: real, reachable.** `CPropPageGeneral::LoadControls` (`dialogs4.cpp:85-124`) made a copy
`logFont` of the page's `LogFont` to create the sample font, and then reused the copy's
`lfFaceName` (32 bytes, `LOGFONTA` - the plug-in is not a Unicode build) as the buffer of the
text shown in the edit field `IDE_FONT`:

```
sprintf(logFont.lfFaceName, LoadStr(IDS_FONTDESCRIPTION), <points>, LogFont.lfFaceName);
SetWindowText(hEdit, logFont.lfFaceName);
```

`"10 pt. "` is 7 characters, a face name has up to 31: 39 bytes with the terminator into 32. The
exact limit: with a two-digit size a face name of **25 characters or more** overruns (24 fits
exactly: `Cascadia Mono ExtraLight`); with a one-digit size 26. The template has 9 characters in
every translation (measured over `translations/*/filecomp.slt`), so the language does not matter.
`lfFaceName` is the last member of the structure and `logFont` a local variable: the bytes after
it on the stack are overwritten (up to 7, more with a three-digit size).

**Reach:** Plugins > File Comparator > Configuration, page General (the function runs at
`WM_INITDIALOG` and after every use of the font button) with a fixed-pitch font whose name has 25
characters or more - chosen with the button *Font > Custom*, or taken from the internal viewer
(`Configuration->InternalViewerFont`, the *Automatic* choice). Such names are common among
programmers' fonts: `JetBrainsMono Nerd Font Mono` (28), `CaskaydiaCove Nerd Font Mono` (28),
`DejaVu Sans Mono for Powerline` (30). Effect: undefined; with the stack cookie the program ends
when the page is opened. Not run - the arithmetic is the evidence.

**What the text is for:** the description of the chosen font, shown in the read-only edit field
`IDE_FONT` of that page, drawn in the font itself.

**Fix:** a buffer of its own, bounded - the form the Database Viewer already has
(`src/plugins/dbviewer/dialogs.cpp:401-406`, `char buf[LF_FACESIZE + 200]` + `_snprintf_s`; read
to compare, not edited):

```
char fontDescr[LF_FACESIZE + 200];
_snprintf_s(fontDescr, _TRUNCATE, LoadStr(IDS_FONTDESCRIPTION), <points>, LogFont.lfFaceName);
SetWindowText(hEdit, fontDescr);
```

The sink (`SetWindowText`, A) and the template (`LoadStr`) are unchanged: template and face name
are both code-page text here. `logFont` is not used after this point in the function, so nothing
depended on the overwritten face name.

**Test:**
- GUI row: install or pick a fixed-pitch font with a long name (if none is installed: the
  registry value of the plug-in's font can be written by the probe with a 28-character face name -
  the font need not exist for the text to be composed); open the configuration page; expected
  `GetWindowText(IDE_FONT)` = `<n> pt. <whole face name>`, the page stays open, exit code 0.
  Before the fix: the program ends (or the text is right and the stack is damaged).
- No pure rule, no unit case.

**Not sure:**
- What exactly follows `logFont` on the stack of the built function, so what the user saw before
  the fix (a crash is expected, not measured).
- Whether the configuration stores the face name where a probe can write it without the font
  dialog (not read).
- Other `sprintf` calls of the plug-in were not reviewed - the item was this line.
