# Fix log: feature 088 — plug-in interface 107

Branch `088-plugin-interface-107`, based on `087-7zip-2603-rar`. All
decisions were taken by the author (maintainer away, "use the recommended
option"); they are listed in `spec.md` *Clarifications*.

## Analysis of the artefacts (before implementation)

Every functional requirement has a task (FR-001/002 → T003–T005, FR-003 →
T006–T007, FR-004/005 → T009–T012, FR-006 → T013, FR-007 → T004, FR-008 →
T017–T019, FR-009 → T016, FR-010 → T004/T019/T020, FR-011 → T003, FR-012 →
T023). No constitution conflict: the interface was documented first
(contract, header comments, version history), the change is an append.

## S1 — the interface

- `spl_vers.h`: `LAST_VERSION_OF_SALAMANDER` 107, history entry;
  `REQUIRE_LAST_VERSION_OF_SALAMANDER` no longer names "0.1.0 build 184"
  (cores with 106 are released) — it says interface 107, after 0.1.8.
- `spl_gen.h`: `IsUnattendedClose`, `SetWindowClosesUnattended` appended
  after `ThemeSubclassPropSheetFrame`; corrected buffer sizes.
- `spl_base.h`: `SAL_MAX_PATH_UTF8` (`#ifndef`, the same guard in
  `src/common/salpath.h`) and `CSalMaxPathBuffer`.
- Core: `CSalamanderGeneral` overrides (`plugins.h`, `zip.cpp`); the
  declaration is the window property `SALCLOSEAPP_WINDOW_PROP`; the
  enumeration of `DecideCloseApp` reads it (`GetPropA`, nothing is sent);
  `SalCloseAppWindowIsForeign` lets a declared window pass.
- saltests: 1900 → **1918** (declared windows in the decision, the B3 rule).

## S2 — the viewers and FTP

Code Viewer, Markdown Viewer, PictView, Database Viewer: the viewer window is
declared at `WM_CREATE`; `Release()` during an unattended close closes the
windows without the question (`CloseAllWindows(FALSE, 5000)`, threads
`KillAll(FALSE, 5000)`), never forced. FTP: no *"cancel existing
operations?"* during an unattended close; with operations it returns FALSE.

## S3 — buffers

- PictView (`pictview.cpp`, `render1.cpp`), Database Viewer (2 sites), and
  the plug-ins not built by default (mmviewer, demoview, demoplug incl. the
  `newDirs` of `SalSplitGeneralPath`): `CSalMaxPathBuffer` instead of
  `char[MAX_PATH]`. mmviewer keeps `MAX_PATH` buffers everywhere else, so it
  refuses a longer name instead of opening it. The three were compiled with
  MSBuild into `%TEMP%` (they are off in `plugins.cfg`).
- B3: `CSalamanderGeneral::GetFileNameForOldViewer` (`zip.cpp`), the rule
  `SalViewerNameFitsPlugin` (`src/common/salplugver.h`), the plug-in's
  version stored by `SetBuiltForVersion` in `CPluginData::InitDLL`.
- T020: `CheckAndCreateDirectory`'s `firstCreatedDir` is filled with
  `strcpy` from a `SAL_MAX_PATH_UTF8` working path (`salamdr3.cpp:1264`) —
  the header comment said `MAX_PATH`; corrected (contract B2). No in-tree
  plug-in passes that buffer (demoplug's use is commented out).

## Independent review — ACCEPT, four SHOULD-FIX, all fixed

Reviewer: a separate agent, read-only. No blocker; the ABI is a pure append,
the FTP condition is right in all four combinations, no viewer shows a box
or calls the main thread on close, `GetPropA` is safe across threads.

1. **PictView declared windows that hold an unsaved image** (pasted,
   scanned, captured — the "name" is `<Clipboard>` and the like): closing
   would lose it, against contract A2. Fixed: `UpdateEnablers` withdraws the
   declaration while such an image is shown and declares again for a file.
2. **The fail-safe "unknown window" entry** of `DecideCloseApp` reused a slot
   of a static array without setting the new field, so after a failed
   enumeration it could count as declared. Fixed (`ClosesUnattended = FALSE`).
3. **Contract B3 / FR-009 said "no further file"**, the code steps over a
   too-long name and goes on. The code is the better behaviour; contract and
   spec aligned.
4. **An abandoned unattended close went on** closing the windows of the
   other plug-ins and unloading them. `CPlugins::UnloadAll` now stops at the
   first refusal during an unattended close; documented in contract A2.

NITs fixed: the thread wait is 5 s too; `fileName[0] = 0` guarded for a NULL
buffer; `<stdlib.h>` in `spl_base.h`; a stale comment in
`codeview/viewer.cpp`. Recorded, not changed: demoplug passes the FS
contract's `targetPath` on to `SalSplitGeneralPath` (its size is the core's
buffer, not the plug-in's).

## Probes (GUI, no person)

Written and first run by a separate agent, re-run by the author after the
review fixes; they reuse feature 080's drivers (`rm_probe.ps1` performs the
installer's Restart Manager sequence; messages are posted to the windows of
the started process only). The registry key of the program was exported
before and compared after every run: identical each time.

`probe/viewers_probe.ps1` — Debug build after the review fixes, **10 / 10**:

| | State | Result |
|---|---|---|
| P1–P4 | one window of each viewer | Restart Manager shutdown 0 after 1.4 s, process ended, no window left, nothing shown |
| P5 | all four viewers | 0 after 1.6 s, ended |
| N1a | PictView + its *Image Properties* dialog | declined (351) after 0.0 s, all windows kept, nothing shown |
| N1b | Database Viewer + *Go to Record* | declined after 0.0 s |
| N2 | Configuration dialog | declined after 0.0 s (080 regression) |
| N3 | normal exit (WM_CLOSE) with a Code Viewer window | the plug-in's question appears, *No* keeps the program and the window — unchanged |
| R1 | no viewer | 0 after 1.3 s, ended (080 regression) |

The only window that appears during a positive close is the core's own wait
window (class `SalamanderSaveBits`), which appears in R1 too.

`probe/longpath_probe.ps1` — a folder path of 349 characters, **10 / 10**:
PictView and the Database Viewer open the first file and step next, next,
previous (titles of 401 and 374 characters change to the expected file);
process alive, no run-time check, no crash report.

`probe/oldplugin_probe.ps1` — SC-005 and B3: the **PictView of the
installed 0.1.8 (interface 106)** in a copy of the new Release tree:
it loads and opens the picture (L1 PASS); *next / previous* do nothing on
the long path (L2–L4 "fail" as designed — the names are stepped over) and
the process stays alive with no run-time error (L9 PASS); its undeclared
window still makes the program decline (P3, P5 "fail" as designed), while
every other scenario passes with the new plug-ins on the Release build.

## Gates

| Gate | Result |
|---|---|
| `build.cmd` Debug | succeeded, encoding guard `TOTAL: 0` |
| `build.cmd full release` | succeeded, runtime closure OK |
| saltests | 1918 / 0 |
| plug-ins off by default (mmviewer, demoview, demoplug) | compile |
| interface diff (`src/plugins/shared/*.h`) | additions at the end of the class, one constant, one helper class, comments |
| `PRIVACY.md` | no change: no network, storage, credential, crash-report or installer change |

## Owed to a person

`quickstart.md`: a real update over an installed version with a viewer open;
PictView with a pasted image (the program must decline — the probe does not
touch the clipboard); the Code and Markdown viewers' own dialogs; a
non-viewer plug-in window (File Comparator); sign-out and shutdown.

## Left for later

- Windows of other plug-ins (File Comparator, Batch Renamer, Disk Map,
  Checksum) still decline an update; each needs its own decision on what
  would be lost.
- `.specify/memory/constitution.md` still says "interface version 105" in
  one place — a governance document, left to the maintainer.
