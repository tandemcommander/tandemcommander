# Implementation Plan: A server's share list that needs a password offers the sign-in

**Branch**: `285-share-list-sign-in` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/285-share-list-sign-in/spec.md`

## Summary

`CFilesWindow::PickServerShare` (feature 125) reads a server's shares on a worker and, when the
list is refused, shows the error. Now a refusal of the logon-failure class (`IsLogonFailureErr`,
the class `CheckAndConnectUNCNetworkPath` uses for a full share path) first offers Windows'
sign-in dialog for the server - `SignInToUncServerW` (new, `drivelst.cpp`):
`WNetAddConnection3W(parent, {RESOURCETYPE_ANY, remote "\\server\IPC$"}, NULL, NULL,
CONNECT_INTERACTIVE | CONNECT_PROMPT)` on the UI thread (the prompt flag added after the review),
wide, with the messages of `RestoreNetworkConnection` for
an unmapped path. After a successful sign-in the list is read again (once); a cancel ends like Esc
in the list; a failure ends like an error. The route's decision and the sign-in target are pure
rules in `src/common/saluncserver.h` (`SalUncShareListStep`, `SalUncSignInTarget`) with
`saltests` checks. A Debug-only seam answers the sign-in in the probe.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only (`mpr.dll` `WNetAddConnection3W`, `WNetGetLastErrorW` - already linked, used by feature 264)
**Storage**: none (nothing stored; the Windows connection lasts for the session, no `CONNECT_UPDATE_PROFILE`)
**Testing**: `saltests` (pure rules); hidden-desktop probe `probe/signin_probe.ps1` (Debug seams of 125 + the sign-in seam of this feature)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `src/`)
**Performance Goals**: none new - the list waits as in 125 (400 ms quiet, then the wait window); the dialog is Windows'
**Constraints**: no new UI string (FR-010); never cut a name (refuse); never through an `A` API (FR-007); the plug-in route untouched
**Scale/Scope**: one function changed (`PickServerShare`), one function added (`SignInToUncServerW`), two header rules

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project file change (`mpr.lib` is linked already; header-only rules) | PASS |
| II. Backward compatibility | only a share list refused with a logon failure changes - from "error" to "sign-in, then the list or the error"; every other result and the plug-in route unchanged (FR-006); no registry, no stored data | PASS |
| III. Incremental modernization | the new sign-in is wide (the old `RestoreNetworkConnection` is left as it is); rules in `src/common/` with tests | PASS |
| IV. Windows commitment | WinAPI only; Windows' own credential dialog | PASS |
| V. Plugin architecture | no plug-in API change; `SalWNetAddConnection2Interactive` untouched | PASS |
| VI. UI consistency | the dialog and the messages of the full share path's sign-in; the list, wait window and messages of 125; no new text | PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/285-share-list-sign-in/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/sign-in.md          (the route, the sign-in, the Debug seam)
├── checklists/requirements.md
└── probe/signin_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/common/saluncserver.h   SalUncShareListStep, SalUncSignInTarget (new, pure, header-only)
src/saltests/saltests.cpp   TestUncShareListSignIn285 (checks of both rules)
src/drivelst.cpp            SignInToUncServerW (new: wide interactive sign-in + messages + Debug seam)
src/consts.h                declarations of SignInToUncServerW, IsLogonFailureErr; SIGNIN_* results
src/fileswnb.cpp            PickServerShare: the list is read in a loop of at most two rounds;
                            between them the sign-in
specs/125-unc-server-shares/contracts/probe-seam.md   the two new seam variables listed
```

**Structure Decision**: core only. `PickServerShare` keeps the wait, the cancel and the menu code
of 125 unchanged inside the loop.

## Complexity Tracking

None.
