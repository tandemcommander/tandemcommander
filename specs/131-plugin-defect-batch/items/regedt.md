# Feature 131 - Registry Editor (`src/plugins/regedt`)

Session 2026-10-13. Nothing was built or run; the verdicts are from reading. Read first:
`specs/129-regedt-wide-inserts/fix-log.md` (whole) and `specs/124-regedt-key-text/fix-log.md`
(sections 1-3). `LoadStrU8`, `FormatWideU8`, `ErrorHelperWide` and `SalWideInserts*` are not
touched: a template with `%ls` still leaves `ErrorHelper` at its first line.

Files changed: `regedt.cpp`, `finddlg.cpp`, `fs3.cpp`. No new string, no interface change.

## 6. `regedt.cpp:206` - unbounded `vsprintf` into `buf[2048]` in the error helper

**Note of 130:** registry key names can be long (`MAX_KEYNAME`), and a message has several
inserts.

**Found: the call was unbounded, but no caller of today can overrun it.** `ErrorHelper`
(`regedt.cpp:199-229`) has two paths since feature 129: a template with `%ls` goes to
`ErrorHelperWide` (heap, never cut); every other template was printed with `vsprintf` into 2,048
bytes. The callers of that narrow path (all `Error(` / `ErrorL(` calls of the plug-in were listed):

- a resource text without an insert - nearly all of them. `fs5.cpp:679` passes two names to
  `IDS_CREATE`, a template without an insert: they are ignored;
- `IDS_PROCESS2` (`"Unable to start %s."`) with `"reg.exe"` / `"regedit.exe"` (`export.cpp:143`,
  `fs5.cpp:1155`);
- `finddlg.cpp:1551`: the regular-expression text as the format (item 7).

The four templates that take key names (`IDS_OPENKEY`, `IDS_OPENKEY2`, `IDS_ACCESS`, and the two
"to itself" ones) have `%ls` and take the wide path. So: a defect in the code, **not reachable**
with the present callers; it becomes one the day a `%s` template gets a name.

**Fix (as the brief says for an unbounded call):** `_vsnprintf_s(buf, sizeof(buf), _TRUNCATE, ...)`.
One thing came with it: the next statement appended a space with `strcat` when the text did not
end in one - with a text that now may fill the buffer that would write one byte past it, so the
space is added only when there is room (`strlen(buf) + 1 < sizeof(buf)`). `FormatMessage` after it
was already bounded (`2048 - l`).

The text of this path is code-page text (a `LoadStr` template), so no UTF-8 tail is trimmed.

**Test:** no GUI row can make the difference visible today (no caller reaches the limit). A
regression row is enough: any plain error of this path, e.g. New > Key with the name of an
existing key, or Change Directory to `reg:\NOSUCHROOT` (`IDS_BADPATH`) - the message is the
template's text as before. The rows of the probes of 124 and 129 cover the wide path.

**Not sure:** nothing about the call; the list of callers is a search for `Error(` and `ErrorL(`,
not a reading of every file.

## 7. `finddlg.cpp:1551` - the regular-expression error text as a printf format, with an unrelated system text appended

**Note of 130 / 129:** `Error(GetParent(), err)` passes the text of
`SalRegExp->GetLastErrorText()` as the FORMAT with no arguments, and the helper appends the
system text for whatever `GetLastError()` held at entry.

**Found:**
- The format: **real in the code, not reachable with the texts read.** The text comes from the
  core (`src/zip.cpp:3578` -> `CRegularExpression::GetLastErrorText`, `src/common/regexp.cpp`): a
  fixed sentence per error ("Unmatched ().", "Nested *?+.", ...), translated in the core. The
  English ones have no `%`; the translations of the core were not read.
- The appended system text: **real, reachable.** `Error(HWND, const char*, ...)`
  (`regedt.cpp:243-253`) reads `GetLastError()` first and `ErrorHelper` adds
  `FormatMessage(lastError)` when it is not zero. Nothing sets the last error to zero between the
  user's click and this call; `Set` of the regular expression does not report through it. What is
  there is the left-over of an earlier call.

**Reach:** Registry Editor panel, Find (Alt+F7), check *Regular expression*, pattern `(`, Find:
the message is `Unmatched ().` followed, when the thread's last error is not zero, by an
unrelated sentence of Windows (which one, and whether any, depends on what ran before in that
thread - not measured).

**Fix (`finddlg.cpp`, `CFindThread::Init`):**

```
HWND parent = GetParent();
SetLastError(ERROR_SUCCESS);
Error(parent, "%s", err);
```

The text is an insert of the literal format `"%s"` (the literal has no `%ls`, so the helper keeps
its narrow path, bounded by item 6), and the last error is zero when the helper reads it, so
nothing is appended. `GetParent()` (`dialogs.h:45`, the plug-in's own inline function) is
evaluated before the last error is cleared. The existing string `IDS_REGEXPERR`
("Regular expresion class error: %s") is not used anywhere in the plug-in; it was left unused -
the other plug-ins show the core's text alone too (`dbviewer.cpp:997`).

The encoding is unchanged: the core's text goes to the same message box as before.

**Test:** GUI row - Find in the Registry Editor with *Regular expression* checked and the pattern
`(` (and `[a`, `*`): expected a message box whose text is exactly the core's sentence for that
error in the language of the program and nothing after it; the Find window stays. To make the
"before" state certain the probe can precede it with an action that leaves an error (a Change
Directory to a key that does not exist).

**Not sure:** which thread runs `Init` and therefore which left-over error the user saw before the
fix; whether any translation of the core's regular-expression texts holds a `%`.

## 8. `fs3.cpp:218` - `MAX_KEYNAME` passed as the size of a `3 * MAX_KEYNAME` buffer

**Found: a defect in the code - a name that fits its buffer is cut - whose effect cannot be
reached today.** `CPluginFSInterface::AcceptChangeOnPathNotification` (`fs3.cpp:203-231`) builds
the panel's own path as UTF-8 and compares it with the notified path:

- `WStrToU8(key, MAX_KEYNAME, CurrentKeyName)` into `char key[3 * MAX_KEYNAME]`: a key path whose
  UTF-8 form needs more than 512 bytes (171 CJK letters, or 256 accented ones - well inside the
  511 characters of `CurrentKeyName`) fails the conversion; `WStrToU8` (`utils.h:51-57`) then
  terminates the partial text at byte 511. So `key` is a cut name, possibly cut inside a
  character;
- `SalPrintf(path2, MAX_FULL_KEYNAME + MAX_PATH, ...)` into
  `char path2[3 * MAX_FULL_KEYNAME + MAX_PATH]`: the same slip, 805 instead of 1,895 bytes;
- `char path1[MAX_PATH * 2]` + `lstrcpyn(path1, path, MAX_PATH * 2)`: the notified path cut at 519
  bytes.

Effect: for a key with such a name the two paths never compare equal (or a cut one equals a
prefix by accident) - the panel would not be refreshed after a change, or refreshed without
need. **Nothing is created, deleted or opened with these texts.**

**Why unreachable:** nobody posts a change notification with a registry path. The plug-in calls
`PostChangeOnPathNotification` once, for the disk directory of an exported file
(`export.cpp:162`); its own panels are refreshed by the change monitor (`chmon.h`). A notification
of another sender has a disk path or another file system's name and fails the comparison at the
prefix `fsName:`.

**Fix (the brief asks for it):** the three sizes are the sizes of the buffers -
`WStrToU8(key, sizeof(key), ...)`, `SalPrintf(path2, sizeof(path2), ...)`, and `path1` has the
size of `path2` (a notified path longer than any path of this file system returns at once: it
cannot be equal to one).

**Test:** none through the GUI (no sender). If a pure rule is wanted later: "does the notified
path equal the panel path or a parent of it" as an inline function of two UTF-8 strings and the
flag `includingSubdirs` - cases: equal; equal but for trailing backslashes; parent with / without
the flag; a longer sibling (`...\Key` vs `...\Key2`); a 600-byte key.

**Not sure:** that no other plug-in or the core posts paths of the form `reg:\...` (searched only
in `src/plugins/regedt`).

## Seen on the way, not changed

- `fs5.cpp:76-77`: `char keyNameA[MAX_KEYNAME]; WStrToStr(keyNameA, MAX_KEYNAME, key)` - a
  code-page copy of a key name; what it is used for was not read.
- `fs3.cpp:195` (of the tree before): `WStrToU8(newName, MAX_PATH, keyName)` - the new key's name
  returned to the panel in the interface's 260 bytes; a longer name is cut by a failed conversion
  (the name is only focused). Not followed.
- `finddlg.cpp:1507`: `SalPrintfW(base, 50, ...)` into `WCHAR base[50 + MAX_PREDEF_KEYNAME]` - the
  size passed is smaller than the buffer; a translated "Searching: HKEY_..." of 50 units or more
  would be cut (bounded, display only).
