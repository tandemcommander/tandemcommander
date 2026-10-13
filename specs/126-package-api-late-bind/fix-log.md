# Fix log: feature 126 - no Windows 8 functions needed to start (GitHub issue #6)

Branch `126-package-api-late-bind` from `125-unc-server-shares`. Session 2026-10-13, the maintainer away.

## 1. Measure first

No Windows 7 / Server 2008 R2 machine: the failed start was **not reproduced**. Verified
(research R1): the two static imports of `tandemcommander.exe` (own PE parser
`probe/pe_imports.py` and `dumpbin`); no other of the 218 PE files of the Release tree imports
them; Microsoft's minimum versions - `GetPackagesByPackageFamily` Windows 8,
`GetPackagePathByFullName` Windows **8.1** (the report says Windows 8 for both). Not verifiable
here: that these are the only functions missing on the server.

## 2. Decision

Remove the accidental load-time dependency; change nothing about what is supported (Windows
11+). A deliberate floor with a message is the maintainer's decision and would need this fix
first anyway (research R2).

## 3. The change

| File | Change |
|---|---|
| `src/common/salshell.h` | `CSalShellPackageApi` (the two functions as pointers), `SalShellResolvePackageApi`, `SalShellPackagePath` |
| `src/common/salshell.cpp` | the lookup through the table (unchanged logic); the resolver - `GetModuleHandleW(L"kernel32.dll")` + `GetProcAddress`, no cached state; `CSalShellOsProbe::GetPackagePath` = resolver + lookup; `#include <appmodel.h>` dropped |
| `src/saltests/saltests.cpp` | `TestPackageApi126`; `saltests --package-path <family>` for the live probe |

Differences from the patch in the report: no function-local statics (the lookup is reached from
more than one thread; they were written without synchronisation), and the lookup is testable
with the functions absent.

## 4. Traps met

- A test symbol named `Folder` collides with something in the Windows headers under
  `using namespace` (C2872) - prefix test globals.
- PowerShell: `& exe | Select-Object -First 1` ends the pipeline early and `$LASTEXITCODE`
  reads -1; collect the output first.

## 5. Tests

| What | Result | Record |
|---|---|---|
| saltests | 18,304 checks, 0 failed (18,277 before; `TestPackageApi126` = 27) | |
| import table, Release `tandemcommander.exe`, before -> after | 796 -> 794 static imports: the two removed, **0 added** | `probe/imports_result.txt` |
| import tables, whole Release tree (218 PE files) | 0 files with a static import of either function; the pre-fix executable fails the same check (control) | `probe/imports_result.txt` |
| live lookup on Windows 11 (26300) against `Get-AppxPackage` | 4 installed families return Windows' own folder; an invented family is "not found" - 5 PASS, 0 FAIL | `probe/package_live_result.txt` |
| `TestCommandShell071` (presets with a fake probe) | unchanged, passes | |
| start and exit of the Debug build (hidden desktop, two rows of the 125 probe) | exit code 0, no window, no report | |
| `tools/check_encoding.py` | `TOTAL: 0` | |
| Debug and Release builds | clean | |

Not possible here: a start on Windows 7 SP1 / Server 2008 R2 SP1 / Windows 8.0 - owed to a
person with such a system (the reporter is asked in the answer to the issue).

## 6. Independent review (read-only, refute-first)

No blocker; the change could not be refuted (prototypes compared with `appmodel.h` of four SDK
versions; the lookup is the old body line by line; all 5,466 static imports of the Release
tree looked through for other post-Windows-7 functions). Applied:

- `research.md` R2 said the program "then behaves on older systems as it did before feature
  071" - nothing measures that. Reworded; two further preconditions of a start on Windows 7 are
  named there and in the answer to the issue: the UCRT (KB2999226; the installer does not ship
  it) and `advapi32!EventSetInformation` imported statically by `codeview.spl` and `mdview.spl`
  through `WebView2LoaderStatic.lib` (a plug-in that does not load, not a failed start).
- four rows of `TestPackageApi126` checked an already empty buffer - every row now starts from
  a dirty one.

Noted: `saltests` itself expects both functions (it runs on a supported Windows); the fake's
"no package" answer differs from the real one (`ERROR_SUCCESS` with count 0) - the lookup
refuses both and the live row covers the real one.

## Second verification (2026-10-13, asked for by the maintainer)

Everything was built again from scratch (`build.cmd rebuild full`, Debug and Release), the
probes were run again on the fresh build and on the 0.1.9 control, and one independent agent
per feature was told to refute the fix and to write tests of its own.

The agent could not refute the change. Its own evidence: `salshell.cpp` compiled with
`WINVER=0x0601` has neither function among its unresolved imports; `static_assert` of both
pointer types against the `appmodel.h` prototypes; the late-bound addresses equal the statically
bound ones; for all 153 package families installed on this machine plus two invented ones the
result equals the direct API calls (155 of 155); 20,000 lookups leave the handle count unchanged.

On the fresh Release tree, with the agent's independent import reader: `tandemcommander.exe`
has 794 static imports and 12 delay-loaded (`winhttp`); **no file of the 218 imports either
function**. `probe/package_live.ps1`: 5 of 5.

Corrections:

- "all 5,466 static imports of the Release tree" (section 6) is not a number that can be
  reproduced: the tree has **5,289** import rows (static and delay-load together; the 189 `.slg`
  files have no import table).
- "No Windows 8 functions needed to start" is true for the program; two plug-ins (`codeview`,
  `mdview`) import `EventSetInformation` and do not load on Windows 7 - the answer to the issue
  says so, the changelog line now too.
- Still not verified by anyone: a real start on Windows 7 SP1 (needs the Universal C Runtime,
  KB2999226).
