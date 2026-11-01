# Implementation Plan: A WSL server path offers its distributions as the share list

**Branch**: `373-wsl-share-list` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/373-wsl-share-list/spec.md`

## Summary

The share-list job of feature 125 (`CUncSharesJob::Read`, `src/shares.cpp`) asks
`NetShareEnum` first and the network providers (`WNetOpenEnumW`) only when the list was
refused; "network path not found" (53) skips the providers. WSL's Plan 9 provider answers only
the providers' question, so `\\wsl.localhost` / `\\wsl$` end in error 53. The fix: error 53
with no share also asks the providers - second, after `NetShareEnum`, where Windows already
knows a missing server and answers 1203 within milliseconds (research R1) - and shows the
first error (53) when they give nothing. The decision moves into pure rules of
`src/common/saluncserver.h` with saltests checks; 51 / 1231 / 1232 keep today's route.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI - `netapi32` (`NetShareEnum`), `mpr` (`WNetOpenEnumW`, `WNetEnumResourceW`) - both already linked and used by `shares.cpp`
**Storage**: N/A (nothing stored)
**Testing**: `saltests` (pure rules), hidden-desktop GUI probe `probe/wslshares_probe.ps1` (real route, no seam)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: a missing server: time to the error within 2 s of today's (1.3 s for a name, 21 s for an address that never answers)
**Constraints**: the second question only after the first failed (never first, never in parallel); no new UI string; worker thread and wait window of 125/193 unchanged
**Scale/Scope**: one function (`CUncSharesJob::Read`), three inline rules in one header, saltests checks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle (constitution v4.0.0) | Check | Result |
|---|---|---|
| I Build reproducibility | no new dependency, no project change | PASS |
| II Backward compatibility | every first-way error other than 53-with-no-share takes the same route as before (the rule table, saltests); SMB servers unchanged | PASS |
| III Incremental modernization | a local change in the job; the rule goes into the existing header | PASS |
| IV Windows commitment | WinAPI only | PASS |
| V Plug-in architecture | no plug-in interface touched; the Network plug-in branch of `ChangeDir` stays first | PASS |
| VI UI consistency | the menu and the error box of 125, no new text | PASS |
| Public claims (`PRIVACY.md`) | "asks that server, through Windows, for the list of its shared folders" stays true - the same second route of 125, one more answer leads to it; no new address | PASS (no change) |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/373-wsl-share-list/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R4
├── data-model.md        # the decision table
├── quickstart.md        # how to verify
├── checklists/requirements.md
├── probe/wslshares_probe.ps1, probe/result_*.txt
├── fix-log.md
└── tasks.md             # /speckit-tasks
```

No `contracts/`: the change has no interface another component or plug-in relies on (the job
and its rules are internal to the core).

### Source Code (repository root)

```text
src/common/saluncserver.h   # + SalUncServerNotFoundErr, SalUncShareListAsksProviders,
                            #   SalUncProviderListError (feature 373)
src/shares.cpp              # CUncSharesJob::Read uses the rules
src/saltests/saltests.cpp   # checks of the three rules
```

**Structure Decision**: the existing core files of feature 125; no new file in `src/`.

## Design

`CUncSharesJob::Read` after the `NetShareEnum` loop (today):

```text
notFound = firstErr in {53, 51, 1231, 1232}
if notFound                                    -> Error = firstErr
else if firstErr != 0 and Count == 0           -> providers; Error = (providers ok and Count > 0) ? 0 : firstErr
else if firstErr == ERROR_MORE_DATA            -> Error = firstErr
```

After:

```text
if SalUncShareListAsksProviders(firstErr, Count)          (firstErr != 0, Count == 0, and
                                                            firstErr is not 51 / 1231 / 1232)
    -> providers; Error = SalUncProviderListError(firstErr, providerErr, Count)
else if SalUncServerNotFoundErr(firstErr) or firstErr == ERROR_MORE_DATA
    -> Error = firstErr
```

The only route that changes is `firstErr == 53` with `Count == 0` (the providers are asked).
53 after shares were already read (a later round of `NetShareEnum` failing) keeps
`Error = 53` with the shares shown (as today: `SalUncShareListStep` shows a non-empty list).
The provider loop itself (names after the last backslash, `RESOURCETYPE_DISK`, `Add`, sort) is
unchanged; the comment at the `notFound` test is rewritten to give the measured reason.

## Complexity Tracking

None.
