# Research — 077 fix-antivirus-findings

Decisions for every unknown in the plan's Technical Context. Facts verified
on 2026-09-17 on the maintainer's machine unless stated otherwise.

## R1 — Where the build takes the runtime files from

**Decision**: from the Visual Studio installation `build.cmd` already
locates through `vswhere` (`VS_INSTALL`), at
`<VS_INSTALL>\VC\Redist\MSVC\<redist-version>\x64\Microsoft.VC143.CRT\`,
where `<redist-version>` is the content of
`<VS_INSTALL>\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt`
(this is the same file `VsDevCmd.bat` reads to set `VCToolsRedistDir`).
On this machine: `14.40.33807` → the directory exists and holds
`vcruntime140.dll` 14.40.33810.0 etc., all with a valid Authenticode
signature by *CN=Microsoft Windows Software Compatibility Publisher,
O=Microsoft Corporation*.

**Rationale**: no hard-coded absolute path (constitution), no dependency on
`VsDevCmd` having been run, deterministic (the redist version is pinned by the
VS installation that also provides the default toolset — the two files
`Microsoft.VCToolsVersion.default.txt` and `Microsoft.VCRedistVersion.default.txt`
both say 14.40.33807 here, so the shipped runtime can never be older than
the compiler that built the product).

**Alternatives considered**: `%VCToolsRedistDir%` (only set inside a
developer command prompt — `build.cmd` is designed to run from a plain
shell); the legacy `src\vcxproj\!populate_build_dir.cmd` (hard-coded
absolute paths, manual step — exactly what the constitution forbids);
running `vc_redist.x64.exe` from the installer (rejected by the user's
decision and by the spec; also needs elevation and adds ~25 MB);
static CRT (`/MT`) (rejected — CRT objects cross module boundaries between
the application and 20 plugins).

## R2 — Which runtime files, and how the set is kept honest

**Decision**: the copied set is a fixed list in `build.cmd`
(`vcruntime140.dll vcruntime140_1.dll msvcp140.dll concrt140.dll`), and a
separate check (`tools/check_runtime_deps.py`) proves after every Release
build that **every** shipped PE's runtime imports (static and delay-load)
resolve to a file in the tree root. The check fails the build when a module
imports a runtime DLL that is not shipped (for example a future
`msvcp140_atomic_wait.dll` pulled in by `std::atomic::wait`), which is the
signal to extend the list.

**Rationale**: FR-004 asks the build to *derive and verify*; verifying a
fixed list is simpler and more reviewable than copying whatever the scan
finds (a scan-driven copy could silently ship files nobody looked at), and
it fails in the right direction. Verified today (`dumpbin /dependents` over
all 25 modules): only `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`,
`MSVCP140.dll` (7zip, codeview, filecomp, mdview), `CONCRT140.dll`
(tandemcommander.exe) and the Universal CRT forwarders `api-ms-win-crt-*`
(part of Windows 10+, not shipped — FR-006).

**Runtime-name pattern** used by both the check and the signing exemption:
`^(vcruntime140|vcruntime140_1|vcruntime140_threads|msvcp140(_[a-z0-9_]+)?|concrt140|vccorlib140|vcamp140|vcomp140|mfc140[a-z]*|mfcm140[a-z]*)\.dll$`
(case-insensitive).

## R3 — Import-table parser

**Decision**: a stdlib-only Python script (`struct`, `os`, `sys`, `re`)
that walks `*.exe *.dll *.spl *.slg` under the tree (skipping
`\Intermediate\`), parses the PE headers, the import directory (entry 1) and
the delay-load directory (entry 13), collects DLL names, and reports every
runtime-pattern name that is not present in the tree root. Exit 0 = closure
holds; exit 1 = a list of `<module> needs <dll> (not shipped)`; exit 2 =
usage/parse error. Python is already a hard build prerequisite (feature 052
guard), so this adds no dependency.

**Alternatives considered**: `dumpbin /dependents` from the build script
(needs the VS environment and per-file process spawns; output parsing in
batch is brittle); `pefile` (third-party — not available, and the build
must not need a package install).

## R4 — Signing exemption rule

**Decision** (amends the 050 contract §1 "per-file behaviour"):

1. A candidate whose Authenticode signature is `Valid` and whose signer
   subject contains `O=Microsoft Corporation` is **exempt**: never stripped,
   never re-signed, counted as verified. Reported in the summary as
   `Exempt (Microsoft): N` and per file only with `-Verbose`-style listing
   in the final verification.
2. A candidate whose file name matches the runtime-name pattern (R2) and
   is **not** validly Microsoft-signed makes the run **fail** before any
   file is touched (pre-flight), naming the file — a corrupt or wrong copy
   of a runtime DLL must not be signed with the project certificate and must
   not ship.
3. Everything else keeps today's behaviour: skip iff valid and signed by the
   configured thumbprint; otherwise strip a stale table and sign — this
   preserves certificate rotation (FR-008) and still signs the unsigned
   third-party files (`7za.dll`, `7zwrapper.dll`, `sqlite.dll`, `exif.dll`).

`-VerifyOnly` exits 0 iff every non-exempt candidate is signed by the
configured certificate and every runtime-named file is Microsoft-valid.

**Rationale**: stripping Microsoft's signature from a Microsoft DLL would be
legal (redistribution licence) but reputation-negative and pointless; rule 2
guards the supply chain of the one file class the project does not build;
rule 3 keeps the 050 semantics for everything the project *does* build.

## R5 — Replacement for the kernel32 patch

**Decision**: delete `PreventSetUnhandledExceptionFilter`,
`PreventSetUnhandledExceptionFilterAux` and `MyDummySetUnhandledExceptionFilter`
(`src/callstk.cpp:60-141`) and the call at `:283`. Keep the supported
registration `SetUnhandledExceptionFilter(TopLevelExceptionFilter)` at
`:264` and its restore at `:403`. Add one small helper,
`void CallStk_ReassertTopLevelExceptionFilter()`, that calls
`SetUnhandledExceptionFilter(TopLevelExceptionFilter)` again (ignoring the
returned previous filter unless it is neither ours nor NULL, in which case a
`TRACE_I` notes that a foreign filter was displaced), and call it from
`AddNewlyLoadedModulesToGlobalModulesStore()` (`src/bugreprt.cpp:2650`),
which the main window already runs every 15 s on `IDT_ADDNEWMODULES` — the
routine that exists precisely to notice modules loaded into the process
(shell extensions, icon handlers) after start.

**Rationale**: the spec allows re-registration by supported means only
(FR-012). The 15-second timer is the one existing periodic point on the UI
thread that already deals with newly loaded modules, so a foreign
top-level filter installed by a shell extension is displaced within 15 s
without any new timer, hook or per-call-site change. The original motives
for the patch are void: the product ships no shell extension of its own,
all shipped modules share one dynamic CRT, and the Universal CRT's invalid
parameter path ends in `__fastfail` (no filter of any kind sees it).
`SetUnhandledExceptionFilter` remains exported and behaves the same on all
supported Windows versions.

**Alternatives considered**: `AddVectoredExceptionHandler` (rejected —
vectored handlers run before frame-based handlers and would see every
exception the program handles itself, including the `__try` blocks around
shell-extension calls; turning that into "is this really unhandled?" needs
the very heuristics that make crash reporters fragile); re-asserting after
each plugin load (`plugins1.cpp:2177`) or after every shell-extension call
(dozens of sites, no benefit over the timer); doing nothing (allowed, but
the timer version costs three lines).

## R6 — How to prove crash reporting still works

**Fact**: when a debugger is attached, `UnhandledExceptionFilter` hands the
second-chance exception to the debugger and **does not call** the filter
registered with `SetUnhandledExceptionFilter`. So a crash provoked while
`cdb` is attached never reaches `TopLevelExceptionFilter` — which is
consistent with feature 075's experience that GUI paths misbehave under
`cdb`.

**Decision**: inject the fault with `cdb` and **detach before it is
dispatched**: attach non-invasively enough to set the main thread's
instruction pointer to an unmapped address (`~0 r rip=0`), then `.detach`;
the thread resumes at address 0, faults with no debugger present, the
supported filter runs, `salmon.exe` writes the bug report and the minidump
into `%LOCALAPPDATA%\Tandem Commander\` (`BugPath` from `salmoncl.cpp:112`)
and shows its dialog, which the probe closes after the files exist. For the
"crash inside a shipped plugin" variant the instruction pointer is set to the
image base of a loaded plugin module (`zip.spl`), whose header page is not
executable: the faulting address then lies inside the plugin's module range
and the report attributes it to the plugin. The probe is committed as
`probe/crash_inject.ps1` and is run **before** the change once (harness
baseline: today's build must produce a report, otherwise the harness is
wrong) and **after** the change twice per variant. `cdb.exe` 10.0.26100.7705
is present under `C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\`.

**Human alternative** (if the injection ever proves flaky): build
`demoplug` (off in `plugins.cfg`; `src/plugins/demoplug/demoplug.cpp:486-488`
contains a deliberate `*p = 0` crash command) and invoke its menu command.

## R7 — The "clean Windows without the runtime" start

**Fact**: this session is not elevated; Windows Sandbox is not installed
(`WindowsSandbox.exe` absent, feature enablement needs admin + reboot);
Hyper-V is present but `Get-VM` is denied for this user; Docker Desktop
offers Linux containers only.

**Decision**: the literal scenario (User Story 1, acceptance 1) is recorded
as an **owed human step** in `fix-log.md` and `quickstart.md` (the pattern
feature 075 used for its GUI scenarios) with the exact steps. What this
session delivers instead, and why it is sufficient evidence short of the
real thing:

1. static closure — `check_runtime_deps.py` proves every runtime import of
   every shipped module resolves inside the tree, and that the runtime DLLs
   themselves import only each other and the Universal CRT / system DLLs;
2. loader precedence — `probe/check_loaded_crt.ps1` starts the built
   program and proves (from the process's module list) that all four
   runtime modules were loaded from the application directory, not from
   `System32`, although this machine has the system-wide runtime — the
   loader's application-directory-first search order is what makes the
   clean machine equivalent;
3. packaging — a real silent per-user install/uninstall of the built
   installer shows the four files arrive in the program folder and leave
   with it.

## R8 — Debug builds

**Decision**: unchanged. Debug binaries link the debug CRT
(`vcruntime140d.dll` etc.), which is not redistributable and is present on
every developer machine through Visual Studio; Debug trees are never
shipped. The copy step and the check are Release-only.

## R9 — Packaging test and protecting the archived installer

**Decision**: the installer script needs no change — `[Files]` packages
`Release_x64\*` recursively, and the runtime DLLs sit in the tree root, so
they land in `{app}` with `ignoreversion` (correct for application-local
files; the "shared system files" warning in the .iss does not apply because
nothing is installed system-wide). The packaging proof is a real
`/VERYSILENT /CURRENTUSER /DIR=<scratch> /NOICONS /SUPPRESSMSGBOXES /NORESTART`
install followed by a silent uninstall (`unins000.exe /VERYSILENT`), twice.
Because the version string is still 0.1.7, `build_setup.cmd` would
overwrite the archived published installer in `setup/output` — the archive
copy is moved aside before the first packaging build and restored (hash
`6731E146…F64DD`, cf. `tools/winget/manifests/0.1.7`) afterwards; the test
installers are kept in the session scratchpad. This PC carries a
machine-wide installation of Tandem Commander 0.1.7
(`HKLM\…\Uninstall\{35C0B0DC-…}_is1`, `C:\Program Files\Tandem Commander\`);
the per-user scratch install uses the HKCU uninstall scope and an explicit
`/DIR`, and the test records that the machine-wide folder and key are
untouched before and after.

## R10 — Version and changelog

**Decision**: no version/build bump in this feature (constitution ties the
bump to the release); the `CHANGELOG.md` entry text ("Fixed" section) is
drafted in `fix-log.md` for the ship gate, exactly as feature 075 did.

## R11 — Import-table proof for the patch removal

**Decision**: `dumpbin /imports tandemcommander.exe` must list neither
`WriteProcessMemory` nor `VirtualProtect` after the change (both are used
nowhere else in the executable — verified by ripgrep over `src/` excluding
vendored 7-Zip, setup, tserver, translator). `IsDebuggerPresent`
(`bugreprt.cpp:576`) and the other imports named in the review stay — they
are outside this feature's scope and have legitimate uses.
