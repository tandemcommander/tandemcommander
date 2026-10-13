# Research: feature 126 (GitHub issue #6)

## R1 - What can be verified without the old Windows

| Claim | How it was checked | Result |
|---|---|---|
| the two functions are static imports of the main program | `probe/pe_imports.py list` (own PE parser) and `dumpbin /imports` on the Release executable | both under `KERNEL32.dll` |
| no other shipped file imports them | `probe/pe_imports.py find` over the Release tree (218 PE files: program, plug-ins, language modules, helpers, runtime DLLs) | only `tandemcommander.exe` |
| minimum Windows versions | learn.microsoft.com, `appmodel.h` reference | `GetPackagesByPackageFamily`: Windows 8 / Server 2012; `GetPackagePathByFullName`: Windows **8.1** / Server 2012 R2 (the report says "Windows 8" for both - the second is newer still) |
| the failure mode | loader semantics: an unresolved static import ends process creation with `STATUS_ENTRYPOINT_NOT_FOUND` (0xC0000139) before the entry point; with `SEM_FAILCRITICALERRORS` (ErrorMode 2, usual on servers) no dialog | consistent with the report; **not reproduced** (no such system here) |
| "the only two missing functions on Server 2008 R2" | - | **not verifiable here**; the reporter checked about 5,500 imports with `GetProcAddress` on the server |

- **Decision**: treat the report as valid; say in the answer exactly what was and was not
  verified.

## R2 - Start there or refuse there?

The project supports Windows 11+ (README, constitution IV). The code still has a Windows 7
floor (`salamdr1.cpp`: "You need at least Windows 7 to run this program."; `WINVER=0x0601` in
the build). The installer has no `MinVersion`.

- **Decision**: remove the accidental load-time dependency and change nothing else. Older
  systems stay unsupported and untested; **a start there was not verified** - only the import
  table was. Two more preconditions of a start on Windows 7 are known from the review and are
  outside this change: the Universal C runtime (`api-ms-win-crt-*`, update KB2999226 - the
  installer ships the VC++ runtime DLLs but not the UCRT), and the two WebView2 plug-ins
  (`codeview.spl`, `mdview.spl`), which statically import `advapi32!EventSetInformation`
  (documented for Windows 8+) through `WebView2LoaderStatic.lib` - a plug-in that does not load,
  not a program that does not start. A deliberate floor ("requires Windows 10/11" with a message) would be a product
  decision for the maintainer, and it too needs the process to start first - i.e. this fix.
- **Alternative rejected**: `/DELAYLOAD:kernel32.dll` - kernel32 cannot be delay-loaded.
- **Alternative rejected**: `MinVersion` in the installer - it would stop installing, not fix
  the silent failure of an existing or portable copy, and it is a support-policy change.

## R3 - Shape of the code

The report's patch keeps three function-local statics (`resolved`, two pointers) written
without synchronisation; the lookup is called from the settings dialog and when a shell is
started.

- **Decision**: no cached state. `SalShellResolvePackageApi(CSalShellPackageApi*)` asks
  `GetModuleHandleW(L"kernel32.dll")` + two `GetProcAddress` on every lookup (microseconds, a
  handful of calls per session) - trivially thread-safe. The lookup proper is
  `SalShellPackagePath(const CSalShellPackageApi*, family, buf, size)`: with a NULL parameter or
  a NULL member it answers FALSE and an empty buffer. `CSalShellOsProbe::GetPackagePath` is the
  two together.
- Both functions are required: Windows 8.0 has only the first one - "no packages" there.
- `#include <appmodel.h>` is no longer needed (the pointer types are spelled out).

## R4 - Tests

- **saltests** (`TestPackageApi126`): fakes with scripted answers cover every branch of the
  lookup - absent table, each member absent, first call not asking for a buffer, zero packages,
  the second call failing, the path call failing, a path that does not fit (refused, buffer
  empty), the success path with a non-ASCII folder, NULL family / buffer. The real resolver on
  the test machine must find both functions (Windows 11) and report a made-up family as absent.
- **Live** (`probe/package_live.ps1`): `saltests.exe --package-path <family>` must print the
  folder that `Get-AppxPackage` reports (Windows Terminal is installed on this machine), and
  fail for a family that does not exist.
- **Import tables** (`probe/pe_imports.py`): `diff` of the Release executable before and after -
  exactly the two entries removed, nothing added; `check` over the Release tree - 0 files.
- **Not possible here**: a start on Windows 7 / Server 2008 R2. Recorded as owed (to the
  reporter or to a person with such a machine); the answer to the issue asks for it.
