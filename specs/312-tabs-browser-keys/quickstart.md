# Quickstart - validating 312

## Build and unit rules

```powershell
.\build.cmd
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"   # TestTabKeys312: table, labels, closed list, page mapping
python tools/check_encoding.py --strict
```

`build.cmd full` (language modules) fails until the maintainer runs the two-stage `.slt` refresh
for the new strings and the changed dialogs (`translate.merge --templates`, rule 084).

## GUI probe (hidden desktop)

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\312-tabs-browser-keys\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\312-tabs-browser-keys\probe\tabs312_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

The probe backs up `HKCU\Software\Tandem Commander`, starts the program on a fixture under
`%TEMP%\tc312`, and drives keys by AttachThreadInput + SetKeyboardState + sent WM_KEYDOWN to the
panel list and the command line (as `specs/093-unicode-dialogs/probe/cmdline_probe.ps1`). Rows:

| Row | Expected |
|---|---|
| classic-keys | option off: Ctrl+Shift+T adds a tab, Ctrl+Shift+W closes it, Ctrl+Shift+PgDn/PgUp switch, Ctrl+PgDn enters the focused folder, Ctrl+PgUp goes up, Ctrl+T / Ctrl+W / Ctrl+Shift+G add no tab |
| classic-labels | option off: the Tabs submenu labels equal the 0.1.10 strings; Reopen has no key |
| browser-keys | option on: Ctrl+T adds, Ctrl+W closes, Ctrl+PgDn/PgUp switch (no folder change), Ctrl+Shift+T reopens, Ctrl+Shift+PgDn/PgUp switch |
| browser-cmdline | option on, focus in the command line with typed text: Ctrl+T adds a tab, Ctrl+W closes, Ctrl+Shift+T reopens; the typed text stays |
| browser-labels | option on: New Tab `\tCtrl+T`, Close Tab `\tCtrl+W`, Next `\tCtrl+Page Down`, Previous `\tCtrl+Page Up`, Reopen `\tCtrl+Shift+T` |
| tabs-off | option on, tabs off: Ctrl+T adds no tab, Ctrl+PgDn enters the folder |
| reopen-state | close a tab with a sort / filter / selection set, reopen: same folder, position, sort, selection |
| reopen-others | four tabs, Close Other Tabs, reopen x3: the original order |
| reopen-empty | no closed tab: the Reopen item is disabled |
| page-lastpage | a stored `Last Focused Page` = 8 (Keyboard in 0.1.10) without the new value: the dialog opens Keyboard (now 9) |
| page-list | Tabs page: list rows for the classic mode; click the option: rows for the browser-like mode at once |
| page-disable | uncheck Show tabs: the option and the list are disabled |
| toggle-menus | Options > Show > Tabs with 2 tabs: the close question; No keeps tabs |

Real keyboard (both modes, panel and command line) and the Tabs page in eight languages: owed to
a person (NOT DRIVEN on the hidden desktop).
