# Research: Remove the salmon.exe Crash Reporter

**Feature**: 079 | **Date**: 2026-09-19

All facts below were read from the working tree at commit 473d7d6 (branch
`079-remove-salmon-crash-reporter`). Line numbers are indicative.

## R1. What salmon does today, and what the main application does itself

| Duty | Who does it today | Where |
|------|-------------------|-------|
| Start the helper at every launch, high priority, inherit 4 event handles | main app, before the CRT starts | `src/salmoncl.cpp` `SalmonInit` / `SalmonStartProcess`, called from the WinMain wrapper in `src/salamdr1.cpp:101` |
| Read/create the machine UID under `HKCU\Software\Tandem Commander\Bug Reporter` (global mutex `Global\TandemCommanderBugReporterRegistryMutex`) | main app | `salmoncl.cpp` `SalmonGetBugReportUID` |
| Tell the helper which `.slg` to load, wait for `Done` (INFINITE), show `IDS_SALMON_NOT_RUNNING` on failure | main app | `salmoncl.cpp` `SalmonSetSLG`, called from `salamdr1.cpp:4088` |
| Ask the helper to scan the report folder and offer old reports; main thread blocks in the wait | main app | `salmoncl.cpp` `SalmonCheckBugs`, called from `salamdr1.cpp:4605` after the main window exists |
| On a crash: copy `EXCEPTION_RECORD`/`CONTEXT` to shared memory, signal `Fire`, wait `Done`, then compose `BugPath\BaseName.TXT` | main app | `salmoncl.cpp` `SalmonFireAndWait`, called from `CCallStack::HandleException` (`src/callstk.cpp:713`) |
| Compute `BaseName` = `UID-NC<shortver>-YYMMDD-HHMMSS[-n]` (uppercased), create the folder, write a minidump | **helper** | `src/salmon/minidump.cpp` `GetReportBaseName`, `GenerateMiniDump` (folder creation via `dbghelp!MakeSureDirectoryPathExists`; dbghelp is never found, so neither the folder nor the dump is created) |
| Write the text report (`Tandem Commander Bug Report File`, exception, registers, call stacks, modules) | main app | `callstk.cpp` `CCallStack::CreateBugReportFile` from `ThreadBugReportF` (6 s budget) or inline as fallback |
| Show the crash dialog `IDD_SALMON_MAIN` while the app writes the report and terminates | **helper** | `src/salmon/dialogs.cpp`, template in `src/lang/lang.rc:2094` |
| Special notices: shell-extension crash (`IDS_SHELLEXTCRASH`), icon-overlay-handler crash | main app | `callstk.cpp` `ThreadBugReportF`, `InformAboutIconOvrlsHanCrash` |
| Terminate with exit code 1 | main app | `HandleException` → `TerminateProcess(GetCurrentProcess(), 1)` |
| Publish the helper's PID in the inter-instance process list so a *Break* from another instance can foreground it | main app | `src/tasklist.h` `CProcessListItem::SalmonPID`, `src/tasklist.cpp:574-584` |

**Consequence for the design**: the only two duties the main application must
take over are (a) naming the report and creating its folder, and (b) telling
the user. Everything else already lives in-process.

**Observation (latent defect)**: because the helper never creates the folder,
today's text report is written only when `%LOCALAPPDATA%\Tandem Commander\`
already exists (created earlier by, e.g., the WebView2 user data folder). On
a machine where it does not exist, `CreateFile(CREATE_NEW)` fails and no
report is written at all. The in-process replacement fixes this.

## R2. Where the closing message is shown

**Decision**: the message box is shown by the existing bug-report thread
(`ThreadBugReportF`), immediately after it has written the report and shown
the existing special notices; the crashing thread, which already waits up to
6 s for the report, then waits (without a time limit) for a new
`MessageDone` event before terminating. If the bug-report thread is not
available or did not answer within the 6 s budget, the crashing thread writes
the report itself (as today) and shows the message box itself.

**Rationale**:
- A message box runs a modal message loop on the calling thread and
  dispatches every message addressed to that thread's windows. On the
  crashing thread (usually the main thread) that would run the main window's
  paint/timer handlers on top of the frames that just faulted, inviting a
  nested crash. The bug-report thread owns no windows, so its modal loop only
  serves the message box. This is the same thread the existing
  shell-extension crash notice is shown from.
- The 6 s wait stays as the budget for *writing the report*; the user-driven
  wait for the message must not be bounded by it, hence a second event.
- The Task List *Break* raises its exception on the task-list control thread,
  so the message appears even when the main thread is hung (the scenario the
  Break exists for).

**Alternatives considered**:
- Inline `MessageBox` on the crashing thread only: simplest, but the
  re-entrancy hazard above; rejected as the primary path, kept as the
  fallback.
- A dedicated dialog template (a slimmed `IDD_SALMON_MAIN`): more UI to
  translate and maintain for a one-button message; rejected (spec
  assumption: message box in the house style).
- Detached child process to show the message: reintroduces exactly the
  helper-process pattern this feature removes; rejected.

**Hardening applied while rewriting `HandleException`** (both cases are made
more likely by an in-process modal message, and both sit in the lines being
rewritten):
- A nested exception on the thread that is already handling one would spin
  forever in `while (ExceptionExists) Sleep(1000)`; the handling thread's id
  is recorded and a re-entry on that thread terminates the process at once.
- A crash *inside* the bug-report thread would time out, then
  `SuspendThread` its own thread before the inline retry, freezing forever;
  when the current thread is the bug-report thread, the handshake is skipped
  and the report is written inline directly.

## R3. Report file naming

**Decision**: `TC<shortver>-YYYYMMDD-HHMMSS.TXT`, upper-case, e.g.
`TC018X64-20260919-143007.TXT`, where `<shortver>` is
`VERSINFO_SAL_SHORT_VERSION` (major, minora, minorb digits plus the platform
tag, the same macro the old `BugName` used). On a collision (same second) a
`-1` … `-99` suffix is appended before the extension, probed with
`GetFileAttributesW`. Location: `%LOCALAPPDATA%\Tandem Commander\`
(`SHGetFolderPathW(CSIDL_LOCAL_APPDATA)`), created with `CreateDirectoryW`
if missing (the parent always exists).

**Rationale**: keeps the version and the timestamp the old name carried,
drops the machine UID (its only purpose was server-side grouping of
uploads) and the `NC` (Newt Commander) prefix, uses a four-digit year, and
keeps the `.TXT` extension the 077 probe and the manual look for.

**Alternatives considered**: keep the old `UID-NC…` scheme byte-for-byte
(would keep reading the registry UID, which the spec removes; rejected);
GUID-based names (unreadable for users who must find "the latest report";
rejected).

## R4. Encoding of the report path

**Decision**: the whole in-process path is wide: `SHGetFolderPathW`,
`CreateDirectoryW`, `GetFileAttributesW`, `CreateFileW`, `LoadStrW` for the
message template, `MessageBoxW` for the message; the caption is
`SALAMANDER_TEXT_VERSION` (ASCII) widened with one `MultiByteToWideChar`.
`CreateBugReportFile` takes a `const WCHAR*` file name (single call pair).

**Rationale**: the folder lives under the user profile; a profile name
outside the ANSI code page made the old ANSI `CreateFile` fail silently.
The crash code is raw WinAPI by design (minimum library use), so the house
`SalU8ToW` converters are not used here; plain `WCHAR` end to end is the
smallest correct form. The report's *content* stays as today (ANSI text
written by `PrintBugReport`).

## R5. Pure helper under unit test

**Decision**: the name formatter lives in `src/common/salbugreport.h/.cpp`
as `SalFormatBugReportName(WCHAR* out, int outLen, const char* shortVersion,
const SYSTEMTIME& t, int suffix)` (returns FALSE when it does not fit), and
is compiled into both `salamand.vcxproj` and `saltests.vcxproj`; new checks
in `TestBugReport079()` cover the format, the upper-casing, the suffix, the
absence of characters illegal in file names and the length bound. Folder
creation, collision probing and the message stay in `callstk.cpp` (they
need the file system and the language module).

**Rationale**: matches the house precedent (071 `salshell`, 078 `saltabs`:
pure rules in `src/common/` under `saltests`, which links only `src/common/`).

## R6. Inter-instance process list

**Decision**: `CProcessListItem::SalmonPID` is renamed `Reserved1`, stays a
`DWORD` at the same offset, and is always written as 0; the
`AllowSetForegroundWindow(Items[i].SalmonPID)` call on a Break is removed;
`extern HANDLE HSalmonProcess` goes; the mirror in `tools/salbreak/tasklist.*`
gets the same rename. `AS_PROCESSLIST_NAME` and the shared-memory version
stay.

**Rationale**: the header states the record is only ever appended to because
older instances read it; a 0.1.8 instance and a 079 instance can share the
list. An older instance breaking a 079 instance reads 0 and calls
`AllowSetForegroundWindow(0)`, which fails harmlessly (it did so already
whenever the helper had not started).

## R7. `EnableExceptionsOn64`

**Decision**: the function (which clears `PROCESS_CALLBACK_FILTER_ENABLED`
for a WOW64 process so kernel-callback exceptions reach the filter) is
moved verbatim from `salmoncl.cpp` into `salamdr1.cpp` as a static function
and called at the same point (before `WinMainCRTStartup`). It is a no-op for
the shipped x64 build; the Win32 configurations in the solution keep their
behaviour.

## R8. Language resources and translations

**Decision**:
- Remove `IDD_SALMON_MAIN` (template + DESIGNINFO block) from
  `src/lang/lang.rc`, `IDD_/IDC_SALMON_*` from `src/lang/lang.rh`, the 41
  `IDS_SALMON_*` lines from `src/lang/texts.rc2` and their defines from
  `src/texts.rh2`.
- Add two strings: `IDS_BUGREPORT_SAVED` ("A problem has occurred, forcing
  Tandem Commander to close.\n\nA bug report has been saved to:\n%s\n\nNothing
  is sent anywhere. If you want to help improve Tandem Commander, please attach
  this file to an issue at github.com/tandemcommander/tandemcommander/issues.")
  and `IDS_BUGREPORT_NOTSAVED` ("A problem has occurred, forcing Tandem
  Commander to close.\n\nThe bug report could not be saved to:\n%s"). The
  same two English texts are hard-coded in `callstk.cpp` as the fallback used
  when `HLanguage` is NULL.
- Refresh the eight enabled languages with the documented two-stage flow:
  `src\vcxproj\build_langs.cmd --export-templates --module salamand`, then
  from `tools\`: `python -m translate.merge --module salamand` (DeepL key in
  `temp\deepl_key.txt`), and add a usage-context entry for the two ids if
  `uicontext` needs it. Verify with a full build (all `.slt` import) and a
  grep that no `salamand.slt` still contains the removed strings.
- The three disabled languages (chinesesimplified, russian, ukrainian) are
  **not** refreshed, following the convention since feature 046 (their
  `salamand.slt` has not been touched by 055/071/078 either); the drift is
  already recorded as a precondition of re-enabling them.

## R9. Build, tooling and repository cleanup

- `src/vcxproj/salamand.sln`: remove the project line (146) and its ten
  configuration lines (873-882) for GUID `{41909C30-…}`. The generated
  `salamand.gen.slnf` follows automatically (gitignored, regenerated by
  `gen_plugins_filter.ps1` from the `.sln`).
- Delete `src/salmon/` (11 files + `res/`) and `src/vcxproj/salmon/` (5
  files); delete `src/salmoncl.cpp/.h` and their entries in
  `salamand.vcxproj` and `.filters`; add `src/common/salbugreport.cpp/.h`
  to `salamand.vcxproj`/`.filters` and `saltests.vcxproj`.
- `src/plugins/shared/baseaddr_x64.txt` / `baseaddr_x86.txt`: drop the
  `salmon` line (82).
- `tools/check_encoding.py:155`: drop `"salmon/"` from the exclusion list.
- `tools/brand/gen_icons.py:52`: drop `src/salmon/res/salmon.ico`;
  `tools/brand/README.md`: drop the three mentions.
- `build.cmd`: after the plugin/language reconcile stages, delete a stale
  `utils\salmon.exe` / `utils\salmon.pdb` from the output tree if present.
  **Why**: MSBuild `rebuild` only cleans projects still in the solution, so a
  developer's existing Release tree would keep the old binary and the
  installer packages the tree recursively (SC-001 would fail on any
  pre-existing tree). Same pattern as the removed-plugin cleanup of 007.
- Dead global `BugReportPath` (`src/tasklist.cpp:39`, `src/consts.h:1773`,
  comment names salmon, no reader) is removed.

## R10. Documentation and change log

- `architecture/01-project-overview.md:60`, `02-solution-structure.md:160`:
  remove the salmon rows; project count 82 → 81 where stated.
- `CLAUDE.md`: line 33 (copyright list of standalone `.rc` files), line 67
  (tree), key facts (project count), the 077 paragraph's "found on the way"
  note, and a new 079 paragraph under Recent Changes.
- `help/src/hh/salamand/othertask_tasklist.htm` and `dlgboxes_tasks.htm`:
  the Break now "writes a bug report and shows a message" instead of
  "invokes the Bug Report dialog"; wording limited to those sentences (the
  pages' 2023 Open Salamander footer is a separate follow-up, see 071).
- `CHANGELOG.md`: a new `## [Unreleased]` section at the top with a
  **Removed** entry (the helper and its start-up prompt), a **Changed** entry
  (crash message now shown by the program itself, report folder created on
  demand, report name), and no version bump.

## R11. Verification design

- **Builds**: `build.cmd full` (Debug x64, includes `check_encoding.py` and
  the `.slt` import for all enabled languages) and `build.cmd full release`;
  `saltests.exe` from `<out>\Debug_x64\saltests\`.
- **Tree checks**: `Get-ChildItem -Recurse` of both trees for `salmon*`;
  `tools/check_runtime_deps.py` on the Release tree; `sign_release.ps1`
  dry sweep (or `build.cmd full release sign` if the certificate is
  available; otherwise the sweep's file inventory is checked for the absence
  of the helper).
- **Crash probe**: `specs/079-…/probe/crash_inject.ps1`, derived from the 077
  probe: no longer waits for `salmon.exe`; after the fault it waits for the
  `.TXT`, then finds the `#32770` window owned by the process whose caption
  is `Tandem Commander <version>`, reads its text (`WM_GETTEXT` on the static
  control, id 0xFFFF), asserts it contains the report path, posts
  `WM_COMMAND IDOK`, waits for exit and asserts exit code 1. Targets `app`
  and `plugin` (zip.spl), 3 runs each (SC-004).
- **Start-up probe**: `specs/079-…/probe/startup_probe.ps1` with two modes:
  `-StaleReports` (plants three files — `.TXT`, `.DMP`, `.7Z` — and checks
  they are untouched afterwards) and `-FreshRegistry` (exports
  `HKCU\Software\Tandem Commander` to a `.reg` backup, deletes the `0.1`
  subkey, runs, then deletes the key the run created and imports the backup,
  verifying a known value came back). Both assert: exactly one process of the
  product, no `#32770` window owned by it within the settle time except a
  first-run language chooser (logged; answered with Enter), main window
  `Responding`, orderly exit on `WM_CLOSE`. Refuses to run while another
  `tandemcommander.exe` is running (protects the user's own instance and
  configuration).
- **Repository grep**: `git grep -i salmon` filtered to exclude `specs/`,
  `CHANGELOG.md`, `src/common/dep/`, `src/plugins/codeview/web/` and
  `temp/`; expected zero hits.
