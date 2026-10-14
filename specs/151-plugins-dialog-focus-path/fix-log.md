# Fix log: 151 - the Plugins dialog's Focus path

Backlog: `specs/NEXT-WORK.md` 5b (150's review).

## Before (by reading)

`IDB_PLUGINFOCUS` (`dialogs5.cpp`): `GetModuleFileName` (A) into `char buf[MAX_PATH]`,
`strcpy(s, "plugins\\")`, `strcat(s, DLLName)` - no bound (an install folder near 259 bytes
overflows the stack buffer); the folder in the code page while the panel takes UTF-8 (a non-ASCII
install folder was named wrongly); `strrchr(...) + 1` without a NULL check; then `strcpy` into
`FocusPlugin[MAX_PATH]`.

## Work

- `dialogs.h`: `CPluginsDlg::FocusPlugin` is a `CSalHeapString` (the header includes `salheapstr.h`,
  header-only); `GetFocusPlugin()` returns `Text()`.
- `dialogs5.cpp`: `GetModuleFileNameU8` (069) into `exe[3 * MAX_PATH]`, `Printf("%.*s\\plugins\\%s")`
  - or the absolute DLLName copied whole; the dialog closes only when the path was built.

## Review (refute-first agent, 2026-10-14)

No critical finding. Taken over: clang-format of the member block; `Text()`. Recorded in
`specs/NEXT-WORK.md` item 19 (the install-path chain): the plug-in loader has the same pattern
(`plugins1.cpp` `CPluginData` load, `LoadLanguageModule`, `plugins2.cpp` `GetPluginDataFromSuffix`:
`GetModuleFileName` A + unbounded `strcat`, then `LoadLibrary` A) - an install folder near 250 bytes
overflows at every plug-in load, before this Focus is reachable; `DLLName` is code page for a plug-in
added in the session (the Add dialog's A file picker) and UTF-8 after a restart. LOW: a failed build
of the path leaves the dialog open without a word.

## After

- Debug build clean; `check_encoding.py` TOTAL 0; `probe/result.txt` P1 PASS (also on an older build:
  a regression row).
