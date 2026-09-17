# Feature Specification: Fix the two product findings of the antivirus review

**Feature Branch**: `077-fix-antivirus-findings`
**Created**: 2026-09-17
**Status**: Draft
**Input**: User description: "Implementuj doporučené úpravy v kódu, resp. sestavení instalátoru dle kontextu, resp.: Dva reálné nálezy v produktu, které stojí za opravu: 1. tandemcommander.exe při každém startu přepisuje kód kernel32 v paměti (src/callstk.cpp:76 — VirtualProtect + WriteProcessMemory trampolíny přes SetUnhandledExceptionFilter; učebnicový inline hook; Symantec SONAR to u salamand.exe už označil; patch odstranit, důvod z roku 2005 už neplatí). 2. Instalátor neobsahuje Visual C++ runtime, přestože všech 25 PE modulů linkuje CRT dynamicky (vcruntime140, vcruntime140_1, msvcp140, concrt140); upstream to řešil skriptem !populate_build_dir.cmd, náš build.cmd full to nedělá a .iss redist nespouští; na stroji bez redistributable instalace proběhne a program nenastartuje (chybí VCRUNTIME140.dll). Nejlevnější oprava: přibalit čtyři Microsoftem podepsané DLL do stromu a vyjmout je z podepisovacího sweepu."

**Origin**: findings §3.2 and §3.3 of
[`specs/076-avast-false-positive-review/review-report.md`](../076-avast-false-positive-review/review-report.md)
(the review of a user report "Avast blocked and removed the program, and the
installation had a problem"). This feature implements exactly those two
findings. The cosmetic items of §3.4 (missing version resources, priority
class of the crash reporter, Control Flow Guard, dead pre-Vista code path)
are **out of scope** and stay listed there as follow-ups.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The program starts on a machine that has no Visual C++ runtime (Priority: P1)

A user installs Tandem Commander on a Windows machine that has never had
the Microsoft Visual C++ 2015–2022 runtime installed (a fresh Windows, an
old rarely-updated Windows 10, a locked-down corporate image). The
installer finishes, the program is launched from the installer's final
page or from the Start menu, and the main window appears with all shipped
plugins available. Today the same user sees *"The code execution cannot
proceed because VCRUNTIME140.dll was not found"* and concludes that the
installation is broken.

**Why this priority**: it is a hard start failure that affects every
released version (0.1.0–0.1.7) on such machines, it is the most plausible
reading of the reported "problem with the installation", and it is
independent of any antivirus.

**Independent Test**: install the release package on a clean Windows
installation with no Visual C++ redistributable present (a disposable
sandbox or virtual machine) and start the program; delivers a working
program where today nothing starts.

**Acceptance Scenarios**:

1. **Given** a Windows installation with no Visual C++ 2015–2022 runtime
   present, **When** the user runs the installer and launches Tandem
   Commander, **Then** the main window opens, Plugins Manager lists all
   shipped plugins as loadable, and no "DLL was not found" message appears.
2. **Given** a machine that already has a system-wide Visual C++ runtime
   (older or newer than the one shipped), **When** Tandem Commander starts,
   **Then** it starts exactly as before and behaves identically.
3. **Given** the installed program folder is copied to another machine or
   a USB drive (portable use), **When** it is started there, **Then** it
   starts without any separate runtime installation.
4. **Given** the user uninstalls Tandem Commander, **When** the uninstaller
   finishes, **Then** the runtime files installed with it are removed with
   the program folder and nothing system-wide was touched.

---

### User Story 2 - Starting the program no longer looks like malware to a behaviour shield (Priority: P2)

A user with a behaviour-based antivirus (Avast Behavior Shield / Hardened
Mode, Symantec SONAR, Defender's behaviour monitoring) starts Tandem
Commander. The program must do nothing at start that these shields are
built to catch: in particular it must not rewrite the executable code of an
operating-system module inside its own process. Today it patches a Windows
system function in memory on every start, and the executable's import
table advertises the memory-writing and page-protection functions used
for that patch — the single most suspicious runtime behaviour of the
product, and one that has already been flagged on the same code base once.

**Why this priority**: it removes a real trigger for false-positive
detections, which is the subject of the user report; it is second only
because the runtime fix is a hard failure while this one is a probability.

**Independent Test**: inspect the released executable — the functions used
for the patch are no longer referenced — and watch the program start under a
debugger or a behaviour monitor: no write to any system module's code
occurs. Crash handling is then exercised to prove nothing was lost.

**Acceptance Scenarios**:

1. **Given** the released executable, **When** its imported functions are
   listed, **Then** the memory-writing and page-protection-changing
   functions that existed only for the patch are absent.
2. **Given** the program is started with a monitor watching for
   modifications of loaded system modules, **When** it starts and runs,
   **Then** no such modification is observed.
3. **Given** the program is running, **When** an unhandled exception occurs
   in the application or in a shipped plugin, **Then** the bug reporter still
   produces the bug report and the minidump in the same location as before
   (crash-handling parity).
4. **Given** the program is running with an in-process third-party
   component (for example a shell extension) that replaces the top-level
   exception handler for its own purposes, **When** a crash occurs, **Then**
   the program has made a best-effort attempt to keep its own reporting in
   place by supported means only, and the documented limitation applies if
   that attempt was overridden.

---

### User Story 3 - The signed release keeps Microsoft's signature on the runtime files (Priority: P3)

The maintainer produces a signed release. The runtime files now in the
tree are published and signed by Microsoft; the project's signing sweep
must leave that signature untouched, must count those files as correctly
signed when verifying the tree, and must refuse to ship a runtime file
whose Microsoft signature is missing or invalid. Everything the project
builds is signed with the project certificate exactly as today.

**Why this priority**: without it the first signed release after the
runtime fix would either strip Microsoft's signature (replacing it with
the project's — legal but wrong and reputation-negative) or fail the
signing gate; it is a release-engineering concern, not a user-facing one.

**Independent Test**: run the signing sweep and its verification mode over
a release tree containing the runtime files; delivers a tree where every
file reports a valid signature by the expected publisher.

**Acceptance Scenarios**:

1. **Given** a release tree containing the runtime files, **When** the
   signing sweep runs, **Then** the runtime files are skipped, keep their
   original Microsoft signature, and the sweep's verification reports the
   tree as fully signed.
2. **Given** a runtime file in the tree whose Microsoft signature is
   invalid or absent (a corrupt or wrong copy), **When** the signing sweep
   runs, **Then** it fails and names the file instead of signing it with the
   project certificate.
3. **Given** a project-built file signed with a previous project
   certificate, **When** the sweep runs, **Then** it is re-signed with the
   current certificate as today (certificate rotation is unchanged).

---

### Edge Cases

- **Build machine without the redistributable files**: the toolchain is
  installed without the "C++ redistributable" component, or in a location
  the build does not expect. The build MUST stop with a clear message
  instead of producing a tree that lacks the runtime.
- **Version mismatch**: the runtime files must be at least as new as the
  compiler toolset that built the product; an older runtime would make the
  program fail with a missing-export error at start. The build takes the
  files from the toolchain that compiles the product, so they can never be
  older than it.
- **Third-party plugin built with a newer toolset**: because the runtime
  ships next to the program, it takes precedence over a newer runtime
  installed system-wide. A future third-party plugin compiled with a newer
  toolset than the shipped runtime would fail to load even on a machine
  that has the newer runtime installed. No such plugin exists today; the
  limitation is documented for plugin authors (ship the newest runtime the
  build machine offers).
- **Debug and development builds**: unchanged — they use the debug runtime
  that every developer machine has through Visual Studio.
- **Files not built by the project that are unsigned today**
  (`7za.dll`, `7zwrapper.dll`, `sqlite.dll`, `exif.dll`): still signed by the
  project as today; only files carrying a valid Microsoft signature are
  exempt.
- **An in-process component replaces the crash handler after start**:
  see User Story 2, scenario 4 — best effort by supported means, documented
  limitation; the program never patches code to win that contest.
- **Program folder copied without the runtime files** (a user hand-copies
  only the executable): fails as any program would; not a supported use.

## Requirements *(mandatory)*

### Functional Requirements

**Runtime shipped with the product**

- **FR-001**: The release output tree and the installer MUST include every
  Visual C++ runtime library that any shipped module requires, so that
  Tandem Commander and all shipped plugins start on a Windows installation
  where no Visual C++ redistributable is present.
- **FR-002**: The runtime libraries MUST be the Microsoft-published binaries
  of at least the compiler toolset version that built the product, and MUST
  be taken automatically from the build machine's toolchain by the single
  release build command — no manual copy step, no hard-coded absolute path
  (constitution: Build Reproducibility).
- **FR-003**: The release build MUST fail with a clear message when the
  runtime libraries cannot be located, instead of producing an incomplete
  tree.
- **FR-004**: The set of runtime libraries MUST be derived from what the
  shipped modules actually import (directly, and through the runtime's own
  dependencies), and the build MUST verify that the shipped set covers all
  runtime imports of every shipped module.
- **FR-005**: The installer MUST package the runtime libraries next to the
  program (application-local), and uninstallation MUST remove them with the
  program folder; nothing is installed or registered system-wide.
- **FR-006**: The Universal C Runtime, which is part of Windows 10 and
  later, is NOT shipped.

**Signing**

- **FR-007**: The signing sweep MUST NOT replace a valid Microsoft signature
  on the runtime libraries; it MUST treat such files as correctly signed in
  its verification mode; and it MUST fail, naming the file, when a runtime
  library lacks a valid Microsoft signature.
- **FR-008**: Files the project builds, and third-party files without a
  Microsoft signature, MUST continue to be signed with the project
  certificate exactly as today, including re-signing after certificate
  rotation.

**No code modification of system modules**

- **FR-009**: Tandem Commander MUST NOT modify the executable code of any
  loaded operating-system module, at start or at any later time. The
  in-process patch of the top-level exception filter function is removed.
- **FR-010**: After the change, the released main executable MUST NOT
  reference the process-memory-writing and page-protection-changing
  functions that existed solely for that patch.
- **FR-011**: Crash handling MUST keep working: an unhandled exception in
  the application or in a shipped plugin MUST still trigger the bug reporter
  and produce the bug report and minidump in the same place as before.
- **FR-012**: If a third-party component loaded into the process replaces
  the top-level exception filter, the application SHOULD re-establish its
  own by supported means only (re-registration, never code patching); if
  that is overridden, losing the report is an accepted, documented
  limitation.

**Scope and record**

- **FR-013**: Nothing else changes: the shipped file set is identical except
  for the added runtime files; the plugin interface version is unchanged;
  no configuration value moves or migrates; the existing automated tests
  pass unchanged.
- **FR-014**: The changelog entry for the next release MUST be drafted in
  the feature's record (as feature 075 did), stating in user terms that the
  program now starts without a separately installed Visual C++ runtime and
  that start-up no longer modifies system code; the version bump itself
  belongs to the ship gate, not to this feature.
- **FR-015**: The plugin-author limitation of application-local runtime
  deployment (edge case "third-party plugin built with a newer toolset")
  MUST be documented where plugin authors look (architecture notes).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a clean Windows installation with no Visual C++ runtime,
  installing the release package and starting Tandem Commander succeeds on
  the first attempt: the main window opens and all 20 shipped plugins load.
- **SC-002**: The released main executable references none of the
  functions that existed only for the in-process patch (0 occurrences in
  its import list), and a start-up run under a monitor shows 0
  modifications of loaded system modules.
- **SC-003**: A forced unhandled exception in the application and one in a
  shipped plugin each produce a bug report and a minidump in the same
  location as before the change (2 of 2 scenarios pass).
- **SC-004**: After the signing sweep, 100% of shipped executable files
  verify as validly signed — project-built and other unsigned files by the
  project certificate, runtime files by Microsoft — and the sweep's
  verification mode exits successfully on the first run and on a repeated
  run (idempotent).
- **SC-005**: The release build remains a single command; on a machine with
  the required toolchain it produces the runtime files without any manual
  step, and on a machine lacking them it stops with a message that names
  what is missing.
- **SC-006**: The existing automated test suite passes with the same
  result as before the change, and the shipped file set differs only by
  the added runtime files.

## Assumptions

- **Application-local deployment is the chosen mechanism** (the user's
  explicit decision: "přibalit … DLL do stromu"). Running Microsoft's
  redistributable installer from the setup, or static linking of the
  runtime, are out of scope; static linking is also unsuitable because the
  application and its plugins exchange runtime objects across module
  boundaries.
- The runtime libraries currently needed are `vcruntime140.dll`,
  `vcruntime140_1.dll`, `msvcp140.dll` and `concrt140.dll` (from the import
  tables of the 25 shipped modules, review §3.3); FR-004 makes the build
  derive and verify the set rather than trust this list, so later
  dependencies (for example additional STL helper libraries) are caught
  automatically.
- The build already locates Visual Studio through `vswhere`; the
  redistributable files are found relative to that installation.
- No third-party plugin exists today; the plugin-author limitation is
  documented, not engineered around.
- The original reasons for the in-process patch (a foreign C runtime in a
  shell extension re-installing its own filter; MSVC 2005 sanity checks
  calling the unhandled-exception path directly) no longer apply: the
  product ships no shell extension, all shipped modules share one runtime,
  and the modern runtime reports invalid parameters through a fast-fail
  path that no exception filter can intercept anyway.
- Verification of User Story 1 needs a clean Windows environment without
  the runtime (a disposable sandbox or a virtual machine). If none is
  available in the implementing session, the scenario is recorded as owed
  to a human step, as feature 075 did for its GUI scenarios — it is not
  skipped silently.
- Release, version bump and changelog publication happen at the ship gate
  in a separate change (constitution: Release Documentation); this feature
  drafts the entry.
- Debug builds are not shipped and are not changed.
