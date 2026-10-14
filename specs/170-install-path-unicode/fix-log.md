# Fix log: 170 - the program starts and loads its plug-ins from any install folder

Backlog: `specs/NEXT-WORK.md` item 19, "the install-path chain (151's review: the plug-in
loader builds every plug-in's path with `GetModuleFileName` A + an unbounded `strcat` into
`MAX_PATH` ...) - measure by running from a folder with a Cyrillic name".

## Measured

`probe/install_path_probe.ps1`: the Debug tree copied into `%TEMP%\tc170\<folder>`, started
from there in Czech (ACP 1250); rows START (main window), LANG (Czech caption of Change
Directory), PLUGIN (Change Directory to `reg:\HKEY_CURRENT_USER` - the Registry Editor plug-in),
and FRESH: the first start after an update (`Plugins.ver Version (x64)` = 0: plugins.ver is
processed, `SearchForAddedSPLs`, `RemoveNoLongerExistingPlugins`) - the registered plug-ins
counted before and after.

| Case | Before (`Debug_x64_pre169`) | After |
|------|----------------------------|-------|
| ASCII folder (control) | PASS | PASS |
| CZ `Tandem Čeština` (inside code page 1250) | PASS | PASS |
| CYR `Tandem Жуk` | **does not start**: Debug box "LoadLibrary (126) ... Tandem ??k\lang\czech.slg" (Release: "File ... was not found or is not valid language file") | PASS (starts, Czech, plug-in) |
| CJK `Tandem 中文` | does not start (the same) | PASS |
| FRESH (Cyrillic folder, first start after an update) | does not start | PASS: plugins.ver processed, 20 of 20 plug-ins registered |

Before 8 / 4, after 21 / 0 (`probe/result_before.txt`, `result_after.txt`). A realistic case: a
per-user install under `%LOCALAPPDATA%` of a user whose name is in another script than the
system's code page.

## Cause

The program's own files were addressed through `GetModuleFileName` A (`?` for a character
outside the code page) and opened with `LoadLibrary` / `FindFirstFile` / `CreateFile` A: the
language module at start (`salamdr1.cpp`), the language dialog (`dialogs2.cpp`,
`CLanguage::Init` in `salamdr2.cpp`), the plug-in loader (`plugins1.cpp` `LoadLanguageModule`,
`InitDLL`; `plugins2.cpp`: plugins.ver, the `plugins` folder search, the check whether a
plug-in's file still exists, the registry load's plug-in folder). The plug-in paths were built
with an unbounded `strcat` into `MAX_PATH`.

## Work

- `src/common/salfileio.{h,cpp}`: `SalLoadLibrary` / `SalLoadLibraryQ` (LoadLibraryW of a UTF-8
  path, registered as `HANDLES` / `HANDLES_Q`), `SalGetModuleDirU8` (a module's folder as UTF-8,
  FALSE instead of a code-page form), `SAL_MODULE_PATH_U8`; `src/common/handles.{h,cpp}`:
  `C__Handles::LoadLibraryW`.
- The call sites above: UTF-8 paths, wide APIs, bounded copies - a path that does not fit is
  refused or left out, never cut; `RemoveNoLongerExistingPlugins` never removes a plug-in it
  could not check; the start-up error boxes show the UTF-8 path wide.
- Left on purpose: `EnumInstalledModules` (a plug-in service with a `MAX_PATH` buffer - an
  interface question, B-5); the shell extension's path (`salamdr1.cpp`, not shipped, 083); the
  other core sites (conversion tables, tips, toolbar pictures, ...) and the plug-ins' own lookups
  of their files - the next steps (NEXT-WORK).

Build: BUILD SUCCEEDED; saltests 22,323 / 0; `check_encoding.py` TOTAL 0.

## Review

See below.
