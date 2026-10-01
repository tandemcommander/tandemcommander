# Research: plug-in interface 107

Facts gathered read-only on 2026-10-01 (branch base `087-7zip-2603-rar`).

## R1 — How the core decides today

`CMainWindow::DecideCloseApp` (`src/mainwnd3.cpp:621-696`) fills a
`CSalCloseAppSnapshot` and calls the pure `SalCloseAppDecide`
(`src/common/salcloseapp.cpp`). D8: `EnumWindows` over the process's
top-level windows; a visible window of an unknown kind that is not a
captionless tool window is *foreign* → decline. The core keeps no registry of
plug-in windows. **Decision**: the window carries the declaration itself (a
window property read with `GetProp` in the enumeration callback): no message
is sent, no cross-thread wait, the decision stays side-effect-free, and a
destroyed window cannot leave a stale entry (the system drops a window's
properties with the window).
*Alternatives rejected*: asking the window with a registered message
(side effect, can hang on a busy thread); a core-side list of handles (stale
handles, handle reuse); a per-plug-in flag "all my windows are safe" (the core
cannot map a window to a plug-in).

## R2 — How plug-ins are unloaded on that path

`mainwnd3.cpp:7008` → `CPlugins::UnloadAll` → `CPluginData::Unload`
(`plugins1.cpp:3115-3130`): `Release(parent, CriticalShutdown)`; when it
returns FALSE during an unattended close the plug-in stays loaded and the
close is abandoned (already built by feature 080). So a plug-in only has to
not ask. The four viewers share one pattern:

```cpp
BOOL ret = ViewerWindowQueue.Empty();
if (!ret && (force || <MessageBox>(…) == IDYES))
    ret = ViewerWindowQueue.CloseAllWindows(force) || force;
```

(`codeview.cpp:166`, `mdview.cpp:118`, `pictview.cpp:624`,
`dbviewer.cpp:398`). `CWindowQueue::CloseAllWindows(force, waitTime = 1000)`
posts `WM_CLOSE` to every window and polls. **Decision**: during an
unattended close skip the question and call `CloseAllWindows(FALSE, 5000)` —
not `force`, which would also terminate threads; 5 s is well inside the
Restart Manager's 30 s and covers a WebView2 window that is still starting.

## R3 — The signal

`UnattendedClose` (`src/salamdr1.cpp:372`) is a core global, set only around
the re-entered exit in `WM_ENDSESSION` (`mainwnd3.cpp:6422/6426`).
`IsCriticalShutdown` is the model: declared `spl_gen.h:3457`, implemented
`zip.cpp:5288`. **Decision**: `IsUnattendedClose()` appended to
`CSalamanderGeneralAbstract`, returns the global. A `PLUGINEVENT_*` was
considered: it needs no vtable slot but arrives as a separate call a plug-in
must remember; the query is simpler and matches the existing method.

## R4 — FTP

`ftp.cpp:381-418` asks *"cancel existing operations?"* when its operation
list is not empty. Feature 080 could not establish whether that state is
reachable past D7/D8. **Decision**: with the signal, FTP returns FALSE
without asking (operations are never cancelled by an update).

## R5 — The buffer contract

`spl_gen.h:2702/2726` say *"at least MAX_PATH"*; the core copies with
`lstrcpyn(fileName, …, SAL_MAX_PATH_UTF8)` (`salamdr6.cpp:205,223`). The
panel source builds names up to `SAL_MAX_PATH_UTF8` (`fileswnb.cpp:1334`);
the Find source stays within `MAX_PATH`. The 104 migration guide
(`doc/plugin-vnext-migration.md` §2) already says no `MAX_PATH` buffer may
hold a full path — the header comment was simply never updated.

Overflowable call sites in the tree: pictview `pictview.cpp:2317`,
`render1.cpp:3194`; dbviewer `dbviewer.cpp:1030,1460`; and, not built by
default, mmviewer `renmain.cpp`, demoview `viewer.cpp`, demoplug
`viewer.cpp`. Codeview already uses a heap buffer of the right size; mdview
does not call the service.

`SAL_MAX_PATH_UTF8` lives in `src/common/salpath.h` (core only); six plug-ins
restate it as a private `U8_MAX_PATH`. **Decision**: define
`SAL_MAX_PATH_UTF8` in `spl_base.h` (guarded with `#ifndef`, the core header
guarded the same way) and correct the comments.

The same wrong sizes are documented for `SalSplitGeneralPath` (`path`,
`newDirs`) and `SalSplitWindowsPath` (`path`): `salamdr5.cpp:1017,1076,1088`
work with `SAL_MAX_PATH_UTF8`. Only demoplug calls them. Corrected in the
same change (FR-010).

Other `MAX_PATH` outputs in `spl_gen.h` were traced: the core bounds them by
`MAX_PATH` (`GetTargetDirectory`, `GetPluginFSName`, `GetRootPath`,
`ResolveSubsts`, …) — no change. Three core functions copy without a bound
from sources that are themselves bounded (`SalGetTempFileName`,
`EnumInstalledModules`, `CheckAndCreateDirectory`'s `firstCreatedDir`): not
part of this contract correction; `CheckAndCreateDirectory` is examined in
T012 and recorded.

## R6 — Older plug-ins

The core knows the caller (`CSalamanderGeneral::Plugin`) and its
`BuiltForVersion` (`plugins1.cpp:2223-2237`). **Decision**: below 107 the
viewer file-name services deliver only names that fit `MAX_PATH`, otherwise
"no further file" (contract B3) — the core honours the contract the binary
was built against.

## R7 — Version mechanics

`spl_vers.h:255` `LAST_VERSION_OF_SALAMANDER`, history comment above it;
precedent commits for 105/106 touched `spl_vers.h`, `spl_gen.h`,
`src/plugins.h`, `src/zip.cpp`. `PLUGIN_REQVER` stays 104. The constitution
(§V) requires the interface to be documented before modification: the
contract and the header comments are written first (T003–T004).
`REQUIRE_LAST_VERSION_OF_SALAMANDER` still names "0.1.0 build 184"; cores
with interface 106 are released, so the text must name the next version
(0.1.9 is the working name of *Unreleased*; the build number is set at the
release) — it is worded without a build number.

## R8 — Verification without a person

Feature 080's probes drive a built program: `probe/rm_probe.ps1` performs
the Restart Manager sequence, `tc_drive.ps1` / `wnd_probe.ps1` drive and
inspect windows. They are reused: open a window of each viewer (by starting
the Debug build and sending F3 on prepared files, or `-`command line`), run
`rm_probe.ps1`, expect exit 0 and no remaining process; then the negative
cases. The pure rule gets unit tests (`TestCloseApp080` extended). The
buffer guard (B3) is a pure decision and gets a unit test; the plug-in
buffers are verified by a long-path folder driven through the same GUI
driver in the Debug build (run-time checks on).
