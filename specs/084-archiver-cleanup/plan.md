# Implementation Plan: Working Archivers Only

**Branch**: `084-archiver-cleanup` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/084-archiver-cleanup/spec.md`

## Summary

**The problem.** Every external archiver in Tandem Commander is started
through a helper, `utils\salspawn.exe`, which no build has ever shipped, so
none of them has ever worked. Of the 12 built-in archivers, 7 are MS-DOS
programs that 64-bit Windows cannot run.

**What this feature changes:**

- **Direct launch.** The product starts archivers directly, in a kill-on-close
  job object, behind a wait window that gains a **Cancel** button. The helper
  and its error-code multiplexing are deleted.
- **Two archivers left.** The built-in archiver table shrinks to two rows:
  - **7-Zip console** (new): browse and unpack formats no plug-in handles,
    starting with ARJ and LZH, through a new tested parser for `7z l -slt`.
  - **RAR (WinRAR console)**: packing only.

  Both run with UTF-8 list files and output, and both are offered only while
  their program is found.
- **Removed.** Every other row goes, together with its panel parsers, error
  tables, DOS-specific code paths, menu items and texts.
- **Upgrade cleanup.** A one-time, targeted migration (configuration version
  105 → 106) removes stored entries that refer to removed archivers, and
  leaves plug-in and own-path custom entries untouched.
- **RAR out of the box.** RAR is read through the 7zip plug-in's own engine,
  which already contains 7-Zip's RAR decoder. This becomes reachable only after
  a **separate, earlier feature upgrades the vendored 7-Zip 16.04 to 25.x**,
  because the old RAR code has known remote-code-execution bugs. That stage of
  084 is blocked on it; every other stage is not.

Details and rationale: [research.md](research.md).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS 2022).
PowerShell 5.1 for the probes; Python 3.13+ for the translation tooling,
`check_encoding.py` and the inventory check.
**Primary Dependencies**: pure WinAPI (`CreateProcessW` via
`SalCreateProcess`, `CreateJobObjectW` / `AssignProcessToJobObject` /
`TerminateJobObject`, registry reads for Autoconfiguration). The in-tree 7-Zip
engine (`src/plugins/7zip/7za`, upgraded by the prerequisite feature). No new
third-party code.
**Storage**: `HKCU\Software\Tandem Commander\0.1\Packers & Unpackers\*`.
`THIS_CONFIG_VERSION` 105 → **106** (targeted migration,
[contracts/config-migration-106.md](contracts/config-migration-106.md)).
**Testing**: `saltests.exe` (baseline 1527; new groups for the `-slt` parser
and the migration decisions); `build.cmd full` / `full release`; probes under
`specs/084-…/probe/` (launch and cancel, migration, inventory cross-check);
fixtures from libarchive's test suite; GUI and clean-machine steps owed to a
person where noted in [quickstart.md](quickstart.md).
**Target Platform**: Windows 11+, x64 (Win32 configurations kept buildable).
**Project Type**: desktop application (WinAPI), MSBuild solution.
**Performance Goals**:
- Panel refresh is not slowed: availability is cached per archiver and never
  checked per file.
- Listing through 7-Zip costs no more than one process start plus parsing.
**Constraints**:
- Plug-in interface version 106 unchanged (FR-011), and no
  `src/plugins/shared/` diff.
- Version stays 0.1.8 / build 192 until a release.
- The `unrar` plug-in stays off.
- Plug-in associations must survive the migration (feature-016 lesson).
- Translation bundle-ordinal hazard (feature 079).
- Constitution III: only code the change touches is modernised.
**Scale/Scope**:
- ≈ 10 core files edited: `pack.h`, `pack1-3.cpp`, `packers.cpp`,
  `packac.cpp`, `dialogsp.cpp`, `dialogs3.cpp`, `fileswn7.cpp`,
  `mainwnd2.cpp`, `plugins2.cpp`.
- 2 new pure units: `src/common/sal7zlist.*` and `src/common/salarcmig.*`.
- 1 project removed: `salspawn`.
- ≈ 72 strings removed, ≈ 15 new strings, 8 languages refreshed.
- ≈ 20 help pages.
- The 7zip plug-in: RAR registration, volume callback, wide password prompt.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|-----------|------------|
| I. Build Reproducibility | PASS. One project leaves the solution and the generated filter follows. No manual step. No new external download: the RAR route uses the source-built in-tree engine, so no RARLAB binary. |
| II. Backward Compatibility | PASS, with documented deprecation. The removed archivers never worked in any Tandem Commander release (the helper was never shipped; spec Context and Assumptions), so nothing that works regresses. The migration is version-gated (105 → 106, the house mechanism) and keeps plug-in and own-path custom entries byte-identical. Removing entries that refer to removed archivers is the user's explicit choice (clarification Q4) and is disclosed in `CHANGELOG.md`. Downgrade to 0.1.8 is documented as unsupported (M6). |
| III. Incremental Modernization | PASS. Delivered in independently revertible stages (see *Delivery stages*). The DOS-variable expansion for custom entries is deliberately kept, not refactored. The translation-tool defect is recorded, not fixed here. |
| IV. Windows Platform Commitment | PASS, with licence note. Pure WinAPI; no new third-party code. The RAR decoder inside the in-tree 7-Zip engine is "LGPL + unRAR restriction". The maintainer accepted exposing it on 2026-10-01 (research R4). It has been in every shipped `7za.dll` since 0.1.0, and is now documented in `doc/third_party.txt`. Not a new conflict; an existing one, made explicit. |
| V. Plugin Architecture Preservation | PASS. No plug-in ABI change (FR-011). Plug-in packers and associations are untouched by the migration. The 7zip plug-in gains RAR through its existing registration calls, gated by its own `ConfigVersion`. |
| VI. UI Consistency | PASS. No new dialog template. `CExecuteWindow` gains one standard push button. The two dialogs' combo boxes switch to item-data mapping with no visual change. No process-wide visual change. |
| Release Documentation | PASS. `CHANGELOG.md` `[Unreleased]` covers: removed archivers and the reason, RAR not yet readable (stage S7 blocked on NEXT-WORK item 8 — the plan's "RAR out of the box" is not delivered by 084), Cancel, the 7-Zip entry, migration and downgrade notes. `PRIVACY.md` is not triggered (research R11), to be re-checked at the end. |

**Post-design re-check (after Phase 1)**: unchanged. The design adds two pure
units in `src/common/` (house precedent 071/078/080), one configuration-version
bump with a targeted migration, and one dependency on a separate feature. No
Complexity Tracking entries.

## Delivery stages

Each stage is one or more commits and is independently reviewable and
revertible.

| # | Stage | Spec | Blocked on |
|---|---|---|---|
| S1 | Direct launch (no helper) + job object + Cancel + new error wording; `salspawn` removed | US2, FR-001/005/006 | — |
| S2 | Archiver table reduced to 7-Zip + RAR; removed rows, parsers, hacks, `PACK*INDEX`, variables, menu items; UTF-8 I/O rows; `externalArchivers[]` | US3, FR-002/003/008 | S1 |
| S3 | `-slt` parser (pure, tested) + 7-Zip browse/unpack wiring | FR-016 | S2 |
| S4 | Availability cache, hiding in BuildArray and in the Pack/Unpack dialogs, Autoconfiguration (registry → known folders → restricted scan) | FR-009/017 | S2 |
| S5 | Migration 106 (pure decisions + load-block wiring) and the new fresh defaults | US4, FR-007 | S2 |
| S6 | Strings removed / added, 8-language refresh (079 procedure), help pages, `third_party.txt`, `04-dependencies.md` + CLAUDE.md corrections, inventory, CHANGELOG | US3/US5, FR-012–015 | S2–S5 |
| S7 | RAR through the 7zip plug-in: registration, volume callback, wide password prompt | US1, FR-004 | **7-Zip 25.x upgrade feature** |

## Project Structure

### Documentation (this feature)

```text
specs/084-archiver-cleanup/
├── spec.md              # feature specification (with Clarifications)
├── plan.md              # this file
├── research.md          # Phase 0: R1–R11
├── data-model.md        # Phase 1: archiver row, association, custom entry, run, listing record, availability, migration rules
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── archiver-launch.md         # C1–C6
│   ├── config-migration-106.md    # M0–M6
│   └── 7z-slt-listing.md          # P1–P4
├── checklists/requirements.md
├── inventory.md         # FR-014 deliverable (written in S6)
├── fix-log.md           # running record (implementation)
├── probe/               # launch, migration, inventory probes + fixtures
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── pack.h, pack1.cpp, pack2.cpp, pack3.cpp     # launch (S1), table rows (S2), 7z wiring (S3), availability (S4)
├── packers.cpp                                  # default custom entries (S2/S5)
├── packac.cpp                                   # Archivers Autoconfiguration (S4)
├── dialogsp.cpp, dialogs3.cpp, fileswn7.cpp     # config pages, Pack/Unpack dialogs (S4)
├── mainwnd2.cpp                                 # THIS_CONFIG_VERSION, migration call (S5)
├── plugins2.cpp                                 # externalArchivers[] fallback (S2)
├── texts.rh2, lang/texts.rc2, lang/lang.rc      # strings (S6)
├── salspawn/                                    # DELETED (S1)
├── vcxproj/salspawn/, vcxproj/salamand.sln      # project removed (S1)
├── common/sal7zlist.{h,cpp}                     # NEW pure -slt parser (S3)
├── common/salarcmig.{h,cpp}                     # NEW pure migration decisions (S5)
├── saltests/saltests.cpp                        # new test groups (S3, S5)
└── plugins/7zip/                                # RAR exposure (S7)
help/src/hh/salamand/*.htm                       # FR-012 (S6)
translations/*/salamand.slt, translations/ui-overrides.json   # FR-013 (S6)
doc/third_party.txt, architecture/04-dependencies.md, CLAUDE.md, CHANGELOG.md   # S6
```

**Structure Decision**: the existing single-solution layout. New pure logic
goes to `src/common/` so `saltests` can link it. UI and registry glue stay in
`src/`.

## Complexity Tracking

No constitution violations to justify.
