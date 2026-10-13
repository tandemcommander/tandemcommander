# Feature Specification: The program does not depend on Windows 8 functions to start

**Feature Branch**: `126-package-api-late-bind`
**Created**: 2026-10-13
**Status**: Draft
**Input**: GitHub issue #6 (`issues/issue_6.md`): "0.1.9 does not start on Windows Server 2008 R2 SP1 / Windows 7 SP1: no window, no message, exit code 0xC0000139. Cause: two functions used by the command-shell presets are imported statically and exist only since Windows 8." Target release 0.1.10.

## What was measured before this specification was written

There is no Windows 7 or Server 2008 R2 machine in this session, so the failure itself could
not be reproduced. What could be checked, was:

| Claim of the report | Check | Result |
|---|---|---|
| the program imports `GetPackagesByPackageFamily` and `GetPackagePathByFullName` statically | the import table of the Release `tandemcommander.exe`, read by an independent parser (`probe/pe_imports.py`) and by `dumpbin` | **confirmed** - both are in the import directory of `KERNEL32.dll` |
| they do not exist before Windows 8 | Microsoft's reference pages | **confirmed, and one is newer than reported**: `GetPackagesByPackageFamily` - Windows 8 / Server 2012; `GetPackagePathByFullName` - Windows **8.1** / Server 2012 R2 |
| a missing static import stops the process before any code runs, with `STATUS_ENTRYPOINT_NOT_FOUND` (0xC0000139) | how the Windows loader works | consistent; the program's own "You need at least Windows 7" message (`salamdr1.cpp`) can never be shown in that case |
| only the main program is affected | all 218 executable files of the Release tree scanned | **confirmed** - no plug-in, language module or helper imports either function |
| "these two are the only functions the server was missing" | - | **not verifiable here**; it rests on the reporter's test on the server |

The report is valid as far as it can be checked. One more fact matters for the decision:
the project supports **Windows 11 and newer** only (README, constitution principle IV); the
program's code, however, still declares Windows 7 as its floor and is built for that API level.
The two functions entered with feature 071 (command-shell presets) as an accident, not as a
decision to stop the program from starting on older systems.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The program starts wherever its own check lets it (Priority: P1)

A person installs the program on an older Windows (Windows 7 SP1, Server 2008 R2 SP1, also
Windows 8.0). It starts. Everything that needs newer Windows features simply behaves as if
those features were absent: a command shell that is distributed as a Store package is "not
found", exactly as on a Windows 11 machine without that package.

**Why this priority**: today the start fails silently - no window, no message, nothing in the
event log - which is the worst possible answer, and the cause is two calls in one function.

**Independent Test**: the program's import table no longer names the two functions; with the
functions "absent" the package lookup answers "not found" and nothing else changes.

**Acceptance Scenarios**:

1. **Given** the released program files, **When** their import tables are read, **Then** no file requires `GetPackagesByPackageFamily` or `GetPackagePathByFullName` at load time.
2. **Given** a system without those functions, **When** the program looks for a packaged command shell, **Then** the answer is "not found" and no error is shown.
3. **Given** a system without those functions, **When** the user opens the command-shell settings, **Then** the presets that are ordinary programs (Command Prompt, Windows PowerShell, an installed PowerShell 7 or Git Bash) are found as before.

---

### User Story 2 - Nothing changes on Windows 11 (Priority: P1)

On a supported system the command-shell presets find the same programs as in 0.1.9, including
the ones installed as Store packages (Windows Terminal, PowerShell from the Store).

**Why this priority**: the supported platform must not pay for the fix.

**Independent Test**: on Windows 11 the package lookup returns the same folder as Windows
itself reports for an installed package, and "not found" for a package that is not installed.

**Acceptance Scenarios**:

1. **Given** Windows 11 with a packaged shell installed, **When** the preset is located, **Then** the result is the same path as before the change.
2. **Given** a package family that is not installed, **When** it is looked up, **Then** the answer is "not found".

---

### Edge Cases

- Only one of the two functions exists (Windows 8.0 has the first, not the second): treated as "no packages" - both are needed.
- The lookup runs from several places and threads (settings dialog, starting a shell): resolving the functions must be safe to do more than once.
- A package path longer than the caller's buffer: refused ("not found"), never cut - as today.
- Windows versions the project does not support stay **unsupported**: the fix removes an accidental start failure; it is not a promise that everything works there.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: No shipped executable file may require `GetPackagesByPackageFamily` or `GetPackagePathByFullName` to be present for the program to load.
- **FR-002**: When either function is absent, looking up a packaged command shell MUST answer "not found" without an error message, and every other part of the program MUST be unaffected.
- **FR-003**: When both functions are present, the lookup MUST return exactly what it returned before the change (same path, same "not found" cases, same refusal of a path that does not fit).
- **FR-004**: The lookup MUST be safe when called from several threads.
- **FR-005**: The change MUST NOT alter the supported-platform statement of the project; the report to the issue MUST say plainly that Windows versions before Windows 11 remain unsupported and untested.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero of the shipped executable files list the two functions among their load-time requirements (today: one, the main program).
- **SC-002**: With the functions simulated as absent, the package lookup answers "not found" in 100 % of the test cases and never touches the caller's buffer beyond emptying it.
- **SC-003**: On this Windows 11 machine the lookup of an installed package returns the folder Windows reports for it; the unit tests of the command-shell presets pass unchanged.
- **SC-004**: The load-time requirements of the main program differ from the previous build by exactly these two entries.

## Assumptions

- Whether the program then really runs on Windows 7 / Server 2008 R2 cannot be verified in this session; the reporter states that it does with the same change. No test on those systems is claimed.
- The program's own minimum-version check (Windows 7) is left as it is; raising or removing it is a product decision outside this report.
- The installer is not changed (it does not restrict the Windows version today).
- The fix is released in 0.1.10.
