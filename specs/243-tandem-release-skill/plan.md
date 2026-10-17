# Implementation Plan: Release Preparation Skill `tandem-release`

**Branch**: `243-tandem-release-skill` | **Date**: 2026-10-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/243-tandem-release-skill/spec.md`

## Summary

One command, `/tandem-release <x.y.z>`, brings the repository into the state
from which that version is released the same day. A standard-library Python
tool `tools/release/release.py` owns everything mechanical — the release
state, the refusals, the version/build/date edits in eight records, the
changelog fold, the reproduction of the winget summary and the consistency
check — with unit tests on a miniature repository. The skill adds the
judgement: the maintainer's questions (not on `main`, open gating person
steps, an open backlog decision), the content review of the release delta
and the privacy triggers, the wording of the changelog lead, the build
comment, the privacy sentence, the release notes, *Status* and *Current
release*, and one local commit. It never builds, tests, signs, tags, pushes
or publishes. The release procedure records (`backlog/RELEASE.md`,
`CLAUDE.md`, the constitution 3.1.0 → 3.2.0) are aligned to one list of
release records; two out-of-scope findings go to the backlog *Inbox*.

## Technical Context

**Language/Version**: Python ≥ 3.13, standard library only (3.14.6 measured);
Markdown for the skill and records
**Primary Dependencies**: git (tags, `ls-remote`, `show`), `tools/backlog/backlog.py`
(lock status, decisions, *Inbox*), `tools/check_encoding.py`
**Storage**: the eight release records in the repository; no state file
**Testing**: `python -m unittest tools/release/test_release.py` (miniature
repository built in a temp folder from `tools/release/fixtures/`);
quickstart V2–V6 on the real tree and a throw-away worktree
**Target Platform**: Windows 11 developer machine (Git Bash and PowerShell)
**Project Type**: repository tooling (CLI script + assistant skill + records);
no product code change
**Performance Goals**: `status`, `stamp`, `check` each under 3 s (one
`ls-remote` excepted)
**Constraints**: byte-preserving edits (BOM, CRLF work tree); idempotent;
nothing pushed, tagged or published; repository text English
**Scale/Scope**: 4 tool commands, ~24 check rules, 8 records, 1 skill (2
files), edits to `backlog/RELEASE.md`, `CLAUDE.md`, the constitution,
`specs/FEATURE-HISTORY.md`; 2 backlog *Inbox* items

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / rule | Assessment |
|------------------|------------|
| I. Build reproducibility | Pass — the tool is not part of `build.cmd`; no dependency added. |
| II. Backward compatibility | Pass — no product, configuration or plug-in change; the tool refuses a MAJOR.MINORA change (registry root rule of *Release Documentation*). |
| III. Incremental modernization | Pass — tooling only. |
| IV. Windows commitment | Pass — runs with the Python the build already needs. |
| V. Plug-in architecture | Pass — `LAST_VERSION_OF_SALAMANDER` is only checked, changed never by the tool. |
| VI. UI consistency | N/A. |
| *Release Documentation* | **Amended by this feature** (clarification 4, FR-024): groups optional, lead `**Build N.** <Kind> release.` required, the record list moved to `backlog/RELEASE.md`. Amendment with rationale and version 3.2.0 per the amendment procedure — justified, not a violation. The bump-in-the-same-change rule is enforced more strictly than before (the tool and `check`). |
| Development workflow: single concern, English commits | Pass — one feature; `[243] …` commits; the skill's own commit `Version x.y.z: …` follows the established release commit style. |
| `PRIVACY.md` rule (CLAUDE.md) | Pass — no network or stored-data change; the skill enforces the rule at each release (FR-017). |
| `CHANGELOG.md` | Pass — internal tooling, no user-visible change, no entry. |

Re-check after Phase 1: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/243-tandem-release-skill/
├── spec.md
├── plan.md              # this file
├── research.md          # F1–F13, R1–R16
├── data-model.md
├── quickstart.md        # V1–V6
├── contracts/
│   ├── cli.md           # release.py commands, refusals, check rules
│   ├── records.md       # the eight records and their formats
│   └── skill.md         # /tandem-release steps, questions, report
├── checklists/requirements.md
├── fix-log.md           # running log during implementation
└── tasks.md             # /speckit-tasks
```

### Source and data (repository root)

```text
tools/release/
├── release.py           # status, stamp, check, summary
├── test_release.py
└── fixtures/            # miniature records for the test repository
    └── README.md

.claude/skills/tandem-release/
├── SKILL.md
└── reference.md

changed: backlog/RELEASE.md (Release records, Preparing = run the skill,
         temp/ → release_notes/, date list, SHA-256 step removed, closing-pass
         commit 8e5d6c8a, Current release gains "Gating person steps:"),
         CLAUDE.md (Product identity points to the list; constitution v3.2.0;
         Where-things-are row; one standing-rule line 243),
         .specify/memory/constitution.md (3.2.0),
         specs/FEATURE-HISTORY.md (entry 243)
added:   2 backlog Inbox items (review:243)
```

**Structure Decision**: a self-contained `tools/release/` beside
`tools/backlog/` (same style: SPDX header, docstring, stdlib, unittest with
fixtures); the skill in `.claude/skills/` next to `tandem-backlog`.

## Implementation order

1. Tool core: record I/O (BOM, EOL, atomic write), version/tag/build logic,
   `status` with states, refusals and warnings; fixtures; tests.
2. `stamp` (all eight records, fold, PRIVACY shift, notes skeleton,
   idempotence); tests.
3. `check` (all rules) and `summary` (exact replica of `publish.ps1`); seeded
   defect tests; replica compared with the PowerShell function on the real
   changelog of 0.1.9 (published manifest `tools/winget/manifests/0.1.9`).
4. `RELEASE.md`: the *Gating person steps:* list in *Current release* (the
   four slugs of 0.1.10), *Release records*, procedure fixes; `CLAUDE.md`;
   constitution 3.2.0.
5. Skill `SKILL.md` + `reference.md`.
6. Validation V2, V3 on the real tree; V4/V5 on a throw-away worktree.
7. Backlog *Inbox* items; FEATURE-HISTORY entry; independent refute-first
   review of tool and skill; fixes; closing report.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution amendment (3.2.0) | The maintainer chose to keep the bullet form of 0.1.10+ and to require the build lead (clarification 4) | Regrouping ~120 entries adds nothing for users; leaving the rule as is keeps a known contradiction |
