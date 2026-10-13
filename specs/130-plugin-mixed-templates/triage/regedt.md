# Triage: regedt (feature 130)

Read: all 124 lines with `LoadStr` / `LoadStrW` / `LoadStrU8` and every `FormatWideU8`,
`sprintf`, `strcat`, `GetErrorText`, `FormatMessage` in the plug-in's sources, after features
124, 127 and 129. No build, nothing run. **Nothing changed** - those features left no
reachable mixed composition; what is left is recorded below.

## 1. How the names are encoded

- Registry names are wide inside the plug-in (`WCHAR` everywhere) and UTF-8 where they go to
  the core (`WStrToU8`, `DupStrA(LoadStrW(...))`, `fs2.cpp:553`, `utils.cpp:146-150`).
- The plug-in has its own `LoadStrU8(int, char*, int)` (`regedt.cpp:86`), `FormatWideU8`
  (`regedt.cpp:114-128`) and `ErrorHelperWide` (`regedt.cpp:132-197`) - kept, none added.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `fs2.cpp:518-524`, `662-668` | `IDS_ENUMKEY` by `LoadStrU8` | `GetErrorText` UTF-8 | `SalMessageBoxEx` | RIGHT AS IT IS (127) |
| `fs3.cpp:681-684` | `IDS_CONFIRNNONEMPTYDELETE` by `LoadStrU8` | key name UTF-8 | `SalMessageBox` | RIGHT AS IT IS (127) |
| `fs3.cpp:1168-1171` | `IDS_REPLACEVAL` by `LoadStrU8` | value name UTF-8 | `SalMessageBox` | RIGHT AS IT IS (127) |
| `utils.cpp:142-152` `RegOperationError` | error id by `LoadStrU8` | `GetErrorText` UTF-8 appended; the name is its own argument (UTF-8) | `DialogError` | RIGHT AS IT IS (127) |
| `fs4.cpp:424-430`, `487` | `IDS_SELECTED*` by `LoadStrU8` (plural) | numbers | information line | RIGHT AS IT IS (124) |
| `fs5.cpp:343-344` | `"%ls\\%ls"` by `FormatWideU8` | wide names | `DialogQuestion` name argument; `IDS_COPYCLASSNAME` is the separate text argument | RIGHT AS IT IS (129) |
| `fs5.cpp:875-881`, `1027-1029` | `IDS_CREATETARGET`, `IDS_CANT*TOITSELF2` by `FormatWideU8(id, ...)` | wide names | `SalMessageBox` | RIGHT AS IT IS (129) |
| `regedt.cpp:199-203` -> `ErrorHelperWide` | templates with `%ls` (`IDS_OPENKEY`, `IDS_OPENKEY2`, `IDS_ACCESS`) loaded wide by id | wide names, `FormatMessageW` reason | `SalMessageBox` (UTF-8) | RIGHT AS IT IS (129) |
| `regedt.cpp:204-220` `ErrorHelper`, the narrow path | any other error template (cp) by `LoadStr` | arguments: `export.cpp:143` and `fs5.cpp:1155` pass one (`"reg.exe"` / `"regedit.exe"`, ASCII) for `IDS_PROCESS2`; `fs5.cpp:679` passes two wide names to `IDS_CREATE`, whose English template has no insert (they are ignored); `FormatMessageA` reason (cp) | `SalMessageBox` | RIGHT AS IT IS (all code page) |
| `fs3.cpp:724-729` | none: `fullName` (fs name + UTF-8 path), `GetErrorText` and `IDS_DELVAL` are three separate arguments | - | `DialogError` | RIGHT AS IT IS (no composition) |
| `fs3.cpp:131-132`, `fs5.cpp:694-719`, `finddlg.cpp:1507`, `fs.cpp:111, 384-391`, `finddlg2.cpp:283-300` | wide templates (`LoadStrW`; the plural ones expanded in the code page and widened by `StrToWStr`) | wide names, numbers | wide dialogs / status bar | RIGHT AS IT IS |
| `finddlg2.cpp:240-241` | `IDS_FOUNDITEMS2` (cp) | number | `SetWindowText` A | RIGHT AS IT IS |
| `regedt.cpp:393-397` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGINNAME`, `IDS_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS |
| `export.cpp:76`, `finddlg.cpp:1406`, `fs5.cpp:445, 983` | none: name (UTF-8) and the question / error text (cp) are separate arguments | - | `DialogQuestion` / `DialogError` | RIGHT AS IT IS (no composition) |
| `finddlg2.cpp:250-251` (the scanner's hit) | `MINIMIZED_FINDING_CAPTION` + `IDS_FF_NAME`, `IDS_FF_NAMED` + masks | - | - | RECORDED - **inside a comment block** (`finddlg2.cpp:243-257`, `/* ... */`): dead text, not compiled (`IDS_FF_NAME` / `IDS_FF_NAMED` are defined nowhere in the plug-in) |
| `finddlg.cpp:1549-1551` | the text of `SalRegExp->GetLastErrorText()` is passed **as the format string** of `Error(HWND, const char*, ...)` | no arguments | `ErrorHelper` -> `vsprintf(buf, message, arglist)` -> `SalMessageBox` | RECORDED (see 4.1) - not a mixed text: the reason is a `LoadStr` text of the core (code page, feature 127's fix log) and so is everything appended |
| menus, column names (`fs4.cpp:267-292`), wait windows, captions, the constant message boxes | constant texts | - | core / `A` controls | RIGHT AS IT IS |

Counts: 0 fixed, 15 rows right as they are, 2 recorded.

## 3. Reaching fixed places

None.

## 4. Other defects seen (not fixed)

1. `finddlg.cpp:1551` `Error(GetParent(), err)`: a regular-expression error text is used as a
   **printf format**. (a) A `%` in it would read arguments that were never passed
   (`vsprintf` with an empty argument list - undefined; a text with `%ls` would even be routed
   to `ErrorHelperWide`, which takes `const WCHAR*` from the list). The core's error texts were
   not read for a `%`; the user's pattern is not part of the text as far as `GetLastErrorText`
   was followed (not followed into the core). (b) `Error(HWND, const char*, ...)` takes
   `GetLastError()` at entry (`regedt.cpp:246`) and `ErrorHelper` appends the system's text for
   it when it is not 0 - after a failed regular expression that is whatever the last API left,
   an unrelated sentence. The safe form is `Error(GetParent(), "%s", err)` with the last error
   cleared - a one-line change that was not made because the row is outside this feature's
   class.
2. `regedt.cpp:204-206`: `vsprintf` into `buf[2048]` without a bound, then `FormatMessage`
   appended with the rest of the buffer (bounded). Today's only arguments are `"reg.exe"` / `"regedit.exe"`.
3. `regedt.cpp:86-94` `LoadStrU8` gives an **empty** text when the template does not fit the
   caller's buffer (recorded already in 127: 600 bytes at `utils.cpp:142`, the longest template
   is about 110).
4. `fs3.cpp:724-726`: `sprintf(fullName, "%s:\\", fsName)` + `GetCurrentPath(fullName + l)` +
   `SalPathAppend(..., MAX_FULL_KEYNAME + 30)` - the buffer is sized in characters of a wide
   key name, the content is UTF-8 (up to three bytes per character): a deep key with
   non-ASCII names may not fit; `GetCurrentPath`'s bound was not followed.
5. `IDS_REGEXPERR` (`"Regular expresion class error: %s"`) has no use in the sources.
