# Implementation Plan: An FTP change made as another user or through another port reaches the running uploads

**Branch**: `345-ftp-upload-cache-user-port` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/345-ftp-upload-cache-user-port/spec.md`

## Summary

Feature 341 made every change report of `CUploadListingCache` (`src/plugins/ftp/operats9.cpp`)
invalidate the listings of every other cache entry **with the same user and port** under another
host name (`InvalidateOtherNamesOfServer`), and made `AddOrUpdateListing` refuse a panel listing
started before a change stamped **under another host with the same user and port**
(`ChangedUnderOtherName`). Another user or another port was kept as "another server"; the probe
measured the data loss for both (rows USER-REN, PORT-REN, ALL-REN, SEED-USER, SEED-PORT FAIL at
ad3eb597).

The fix widens both tests from "same user and port, another host" to "any other identity" -
another host, another user or another port: `InvalidateOtherNamesOfServer` invalidates every entry
except the reported identity's own (`exact`), and `ChangedUnderOtherName` counts every stamp
whose identity is not the listing's own. `FindServer` and `StampChange` keep the exact identity
(they locate the entry / stamp of the identity itself). The identity comparison for "own"
(host `StrICmp`, user exact with `anonymous` = none, port) is kept in one place in the class
(a small static helper used by `FindServer`, `StampChange` and `ChangedUnderOtherName`), so "own"
means the same thing everywhere.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; FTP plug-in (`src/plugins/ftp`)
**Storage**: N/A
**Testing**: hidden-desktop probe `specs/345-ftp-upload-cache-user-port/probe/ftp345_probe.ps1`
(USER-REN, PORT-REN, ALL-REN, ALIAS-REN, SAME-REN, SEED-USER, SEED-PORT, SEED-SAME) with 323's
`ftpmini_hide.py` (two instances, ports 2145 / 2146, one folder); regressions 341's
`ftp341_probe.ps1` and 323's `ftp302_probe.ps1`; saltests unchanged (0 failed)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL `ftp.spl`)
**Performance Goals**: a report walks the few cached entries; an invalidated listing costs one
`LIST` while uploads under two identities exist (accepted, spec *Clarifications*)
**Constraints**: no new network communication beyond listing a folder an upload already lists
(PRIVACY.md unaffected), no plug-in interface, UI string, registry or file change
**Scale/Scope**: 2 FTP source files (`operats.h`, `operats9.cpp`)

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency - PASS |
| II. Backward compatibility | no ABI, registry, configuration or file-format change - PASS |
| III. Incremental modernization | two conditions widened, one helper - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plug-in architecture | internal FTP plug-in classes only - PASS |
| VI. UI consistency | no UI change - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/345-ftp-upload-cache-user-port/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ftp345_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/plugins/ftp/operats.h     # CUploadListingCache declarations and comments
src/plugins/ftp/operats9.cpp  # InvalidateOtherNamesOfServer, ChangedUnderOtherName, FindServer, StampChange
```

**Structure Decision**: the two FTP files 341 changed; no new file. A pure-rule header with
saltests (stop-rules §2.5) is not added: the rule left is "not the own identity", a three-field
equality already used by `FindServer`; the probe proves the behaviour (recorded in research.md).

## Complexity Tracking

None.
