# Implementation Plan: Backlog System Outside `specs/`

**Branch**: `242-backlog-system` | **Date**: 2026-10-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/242-backlog-system/spec.md`

## Summary

Replace the scattered backlog (`specs/NEXT-WORK.md`, five `REMAINING-WORK.md`
files, the deleted `issues/` and `features/`) with `backlog/`: an overview
`BACKLOG.md` that holds only order and sections, one folder per item with a
strict `desc.md` (metadata header + fixed sections), a run journal and a
release checklist. A standard-library Python tool `tools/backlog/backlog.py`
owns every mechanical change and the consistency check; two project skills
add the judgement — `/tandem-backlog` for management, and
`/tandem-backlog-implement` for one autonomous run of the Spec Kit flow per
item, with a lock, measure-first, stop rules and a fast-forward into local
`main`. All open entries are migrated with a ledger; project documents are
redirected; `NEXT-WORK.md` is deleted.

## Technical Context

**Language/Version**: Python ≥ 3.13, standard library only (3.14.6 measured)
for the tool; Markdown for skills and backlog files
**Primary Dependencies**: none new; Spec Kit git extension
(`create-new-feature.sh`, commit hooks) and `git` for the implement skill;
GitHub public REST interface for issue import (research R6)
**Storage**: files in the repository (`backlog/`), one unversioned lock file
in the git common directory
**Testing**: `python -m unittest tools/backlog/test_backlog.py` with
fixtures (one per check rule); quickstart scenarios V1–V9 for the skills
**Target Platform**: Windows 11 developer machine (Git Bash and PowerShell 5.1
both able to run the tool)
**Project Type**: repository tooling (CLI script + assistant skills + data
files); no product code changes
**Performance Goals**: `check` and `sync` on ~150 items under 2 seconds
**Constraints**: nothing under `specs/` touched by management operations
(SC-005); no dependency downloads; nothing pushed or published; backlog files
English, UTF-8 without BOM
**Scale/Scope**: expected 60–120 migrated items; ~10 tool commands; 2 skills;
edits to `CLAUDE.md`, `specs/FEATURE-HISTORY.md`, five `REMAINING-WORK.md`
notes; deletion of `specs/NEXT-WORK.md`, `issues/`, `features/`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / rule | Assessment |
|------------------|------------|
| I. Build reproducibility | Pass — the tool is not part of `build.cmd`; no new dependency; no network in the build. |
| II. Backward compatibility | Pass — no product, configuration or plug-in change. |
| III. Incremental modernization | Pass — tooling only. |
| IV. Windows commitment | Pass — runs on the Windows development machine with the Python the build already needs. |
| V. Plug-in architecture | Pass — untouched. |
| VI. UI consistency | N/A. |
| Development workflow: PRs against `main`, single concern | Pass with note — an autonomous run fast-forwards **local** `main` and never pushes; how the maintainer publishes (PR or push) is unchanged. One run = one feature = one concern. |
| Commits in English referencing the feature | Pass — `[NNN] …`, `backlog: …`, and the Spec Kit extension's `[Spec Kit] …` messages. |
| Release documentation (`CHANGELOG.md`) | Pass — no user-visible change, no entry (internal tooling, per the constitution's own exemption). |
| `PRIVACY.md` rule (CLAUDE.md) | Pass — the product's network behaviour and stored data are unchanged; the GitHub import is a maintainer tool. |
| Encoding guard / source rules | Pass — no C++ change; the Python file follows the existing `tools/*.py` style (SPDX header, docstring). |

Re-check after Phase 1: unchanged — the design adds no product code, no
build step and no publishing step.

## Project Structure

### Documentation (this feature)

```text
specs/242-backlog-system/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R14
├── data-model.md
├── quickstart.md         # V1–V9
├── contracts/
│   ├── item-format.md
│   ├── overview-format.md
│   ├── cli.md
│   └── skills.md
├── checklists/requirements.md
├── migration-ledger.md   # written during implementation (FR-040)
├── fix-log.md            # running log during implementation
└── tasks.md              # /speckit-tasks
```

### Source and data (repository root)

```text
backlog/
├── BACKLOG.md
├── RUNS.md
├── RELEASE.md
└── items/<slug>/desc.md [issue.md reply.md evidence/]

tools/backlog/
├── backlog.py            # check, sync, list, next, new, import-github, set,
│                         # log, verify, move, block/unblock, start, remove,
│                         # run-log, lock
├── test_backlog.py
└── fixtures/             # valid backlog + one seeded defect per rule

.claude/skills/tandem-backlog/
├── SKILL.md
└── reference.md
.claude/skills/tandem-backlog-implement/
├── SKILL.md
└── stop-rules.md

changed: CLAUDE.md, specs/FEATURE-HISTORY.md (header + entry 242),
         specs/{068,069,070,072,080}-*/REMAINING-WORK.md (one-line note)
deleted: specs/NEXT-WORK.md, issues/, features/
outside the repository: the assistant's memory pointer to NEXT-WORK
```

**Structure Decision**: a self-contained `tools/backlog/` folder (script,
tests, fixtures) beside the existing `tools/*.py` checkers; skills in the
project's `.claude/skills/` next to the Spec Kit skills; data in a new
top-level `backlog/`.

## Implementation order

1. Tool core: parsing of header, body, overview, legend; `check` with all
   rules; fixtures and tests (V1).
2. Changing commands: `new`, `set`, `log`, `verify`, `move`, `block`,
   `start`, `remove`, `sync`, `run-log`, `lock`, `next`, `list`,
   `import-github`; tests.
3. Empty `backlog/` skeleton (`BACKLOG.md` with legend, `RUNS.md`,
   `RELEASE.md`); `check` → 0.
4. `/tandem-backlog` skill (V4–V6 on a scratch copy, then reverted).
5. Migration with ledger (largest step; by reading; independent review of
   the ledger) → V2, V3.
6. Redirect `CLAUDE.md`, `FEATURE-HISTORY.md`; notes in `REMAINING-WORK.md`;
   delete `NEXT-WORK.md`; commit the deletion of `issues/` / `features/`;
   update the memory.
7. `/tandem-backlog-implement` skill and `stop-rules.md` (V7, V8; V9 is the
   maintainer's first real run).
8. Independent refute-first review of the tool, the skills and the ledger;
   `FEATURE-HISTORY.md` entry 242; closing report.

## Complexity Tracking

No constitution violations to justify.
