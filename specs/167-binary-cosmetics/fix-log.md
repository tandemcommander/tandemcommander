# Fix log: 167 - binary cosmetics of the 076 review (sqlite.dll version, CFG, dead path)

Backlog: `specs/NEXT-WORK.md` item 17 (077 cosmetics; 076 `review-report.md` section 3.4 and its
recommendation 6).

## State found

Of recommendation 6: `7zwrapper.dll` no longer exists (the 7-Zip plug-in ships `7za.dll` only),
`HIGH_PRIORITY_CLASS` is gone from the tree, `IsDebuggerPresent` stays (`callstk.cpp`: no Bug
Report dialog while a debugger runs - a real use). Left: `utils\sqlite.dll` without a version
resource (empty company, product, version), no Control Flow Guard in any binary, and the dead
`SalGetProcessId` whose pre-Vista path carried the string `ZwQueryInformationProcess`.

## Work

- `src/vcxproj/sqlite/sqlite.rc` (+ the project, `sqlite_base.props` include path): a version
  resource - SQLite's own file version 3.28.0 (`SQLITE_VERSION` of the vendored source), the
  product version of the program, "public domain" as the copyright, Tandem Commander as the
  builder. Checked on the Debug build: the file properties show every field.
- `src/salamdr6.cpp`, `src/salamand.h`: `SalGetProcessId` removed - no caller anywhere (core,
  plug-ins); 81 lines, the string `ZwQueryInformationProcess` with them.
- `src/Directory.Build.targets`: Release only, `/guard:cf` for the compiler (`ControlFlowGuard`)
  and the linker, for every project of the solution (Debug keeps `/ZI`, which CFG excludes).

- `src/plugins/filecomp/vcxproj/fcremote/fcremote_base.props`: `TcNoControlFlowGuard` - the
  helper is linked without the CRT, so it has no load configuration: the first Release build set
  the CFG flag on it without effect (LNK4266, `dumpbin`: Control Flow Guard, load config 0).

## Verification

- Debug build: BUILD SUCCEEDED; `sqlite.dll` properties: company, description "SQLite 3.28.0
  database engine (public domain), built for Tandem Commander", file version 3.28.0, product
  version 0.1.10 (x64), copyright, original name.
- `build.cmd full release`: BUILD SUCCEEDED, no LNK4266. `dumpbin /headers` over the Release
  tree: all 29 code files carry Control Flow Guard (the Microsoft runtime DLLs had it already),
  `fcremote.exe` excepted on purpose.
- The Release build (CFG) on the hidden desktop: 097 arcwork 390 / 0 / 21 n/a, 119 packleft
  104 / 0 / 8, 127 mixed 19 / 0 / 3, 088 viewers (Code Viewer and Markdown Viewer = WebView2,
  PictView, Database Viewer) 9 / 1 - identical to Debug; the one FAIL (N3) is the probe counting
  Windows 11's UAC input indicator windows as stray (item 18). Registry identical after each.
- `SalGetProcessId` / `ZwQueryInformationProcess`: no occurrence left outside `common/dep`.
