# Quickstart: feature 093 - text outside the code page

## Automated (repeatable; windows only on a hidden desktop)

Every probe that opens a window is run through the launcher, so nothing
appears on the desktop in use:

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log out.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\093-unicode-dialogs\probe\dialogs_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
... the same with probe\cmdline_probe.ps1 and probe\pwd_gui_probe.ps1
powershell -File specs\093-unicode-dialogs\probe\pwd_engine_probe.ps1      (console only)
```

Expected: dialogs 139 PASS / 0 LOSSY / 0 FAIL (one menu row may be NOT
DRIVEN on the hidden desktop), command line 63 / 0, passwords 29 / 0, engine
53 / 0. The probes save and restore `HKCU\Software\Tandem Commander`; **do
not change settings in an installed Tandem Commander while one runs** - the
restore would undo them.

## Owed to a person (a real keyboard; Release build)

1. **Menus by keyboard - the first thing to check.** Main window: Alt+L, F,
   E, C, P, O, R, H each open their menu; a letter then picks an item; Esc
   closes. Find Files (Alt+F7): Alt+F, M, E, V, O the same. With a Czech
   layout also Alt + an accented letter: nothing unexpected happens.
2. **Find Files** in a folder named in Cyrillic or Chinese (on a Czech
   Windows): *Look in* shows the folder's real name; type a mask with such
   characters; the file is found; reopen Find: the histories show the text.
3. **Configuration**: Hot Paths - type such a path, OK, reopen: unchanged.
   User Menu - an item with such a command: select it, OK, reopen: unchanged.
   Rename a list item in place (F2) with such characters.
4. **Command line**: Ctrl+Enter on a file named `日本.txt` inserts the name;
   type and paste such text; Ctrl+Backspace, Ctrl+Left/Right, Home/End,
   selection with Shift; drag a file from the panel onto the command line;
   run `copy nul "<such a name>"`; recall it from the history (Ctrl+E /
   the drop-down).
5. **7-Zip passwords**: pack a 7z archive with the password `heslo-ř`; open
   it in the 7-Zip program with `heslo-ř`. Open an archive made by 0.1.8 with
   an accented password, typing the password you used then. A wrong password:
   one message. F3 on a file inside an encrypted archive; then another file -
   no second prompt.
6. An input method editor (Chinese/Japanese input), if available: type into
   Find, Configuration and the command line.

## Not testable here

A system with a double-byte code page; a keyboard layout whose code page
differs from the system's.
