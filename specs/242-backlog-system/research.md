# Research: Backlog System Outside `specs/` (242)

Measured on 2026-10-17 at `7993914c` (branch `242-backlog-system`).

## R1 — Runtime of the backlog tool

- **Decision**: one Python 3 script using the standard library only,
  `tools/backlog/backlog.py`, with its tests beside it
  (`tools/backlog/test_backlog.py`, fixtures in `tools/backlog/fixtures/`),
  run as `python tools/backlog/backlog.py <command>` and
  `python -m unittest tools/backlog/test_backlog.py`.
- **Rationale**: the build already requires Python (`check_encoding.py`,
  measured: Python 3.14.6 on this machine). `check_encoding.py` is run the
  same way — plain `python`, no `uv` environment. Standard library only means
  no new dependency and no network at install (project rule: everything
  vendored, zero package downloads in the build).
- **Alternatives**: a `uv` entry point in `tools/pyproject.toml` — rejected,
  it would need `uv sync` before the first use and drags the translation
  dependencies (`anthropic`, `tree-sitter`); PowerShell — rejected, the
  project's checkers are Python and PowerShell 7 is missing on this machine
  (memory: env quirks); no tool, rules only in the skill — rejected, FR-015 /
  FR-016 require a check runnable without the assistant.

## R2 — Metadata header format of `desc.md`

- **Decision**: a front-matter block between two `---` lines, in a strict
  subset of YAML: one `key: value` per line, keys from a fixed list in a
  fixed order, scalar values unquoted, lists in flow form `[a, b]` (empty
  `[]`), no comments, no nesting, no multi-line values. The value is
  everything after the first `": "`, so titles may contain colons. `-` means
  "empty" for `verified`, `effort`, `feature` and `reason`.
- **Rationale**: standard library has no YAML parser (measured: `import yaml`
  fails). A strict subset is parsed by a few lines of code, any YAML-aware
  editor or viewer still renders it, and the fixed order makes diffs and
  hand edits predictable.
- **Alternatives**: full YAML with a vendored parser — rejected (dependency
  for a 15-line header); a Markdown table as header — rejected, worse to edit
  and not recognised by viewers as metadata.

## R3 — Vocabularies live in the legend of `BACKLOG.md`

- **Decision**: the allowed values of `type`, `status`, `area`, `who`,
  `effort` and the source forms are tables under `## Legend` in
  `BACKLOG.md`; the tool reads them from there. The severity scale is a table
  there too (for people; the tool only checks 0–10).
- **Rationale**: FR-005 says new values are added "only by changing the
  legend" — making the legend the single source means the tool and the
  people read the same list, and adding an area is one table row, no code
  change.
- **Alternatives**: vocabularies hard-coded in the tool — rejected, two
  sources would drift.

## R4 — Overview tables and synchronisation

- **Decision**: each section of `BACKLOG.md` is a `## <Section>` heading with
  one Markdown table. A row is identified by the slug in its link
  `items/<slug>/desc.md`; the link text is the item's title. `sync` rewrites
  every cell except the row's position and section, renumbers the ordered
  sections and leaves all text outside the section tables untouched.
  Unordered sections (*Inbox*, *Parked*, *Rejected*) are sorted by the
  tool: *Inbox* by `created` then slug (newest last), the other two by area
  then slug.
- **Rationale**: FR-011 / FR-012 / FR-017. Identifying rows by slug (not by
  position or title) means a hand edit that only moves lines is always safe.
- **Alternatives**: generating the whole file from a separate order file —
  rejected, the maintainer wants to see and edit the order in `BACKLOG.md`
  itself.

## R5 — Slugs

- **Decision**: derived from the title: Unicode NFKD, combining marks
  dropped (so `č` → `c`), lower case, every run of other characters → one
  hyphen, trimmed, cut at a hyphen to at most 60 characters. A collision is
  refused with the existing item named; the caller chooses another title or
  passes an explicit slug. Slugs are validated by
  `^[a-z0-9]+(-[a-z0-9]+)*$`.
- **Rationale**: FR-002; folder names stay plain ASCII on every file system
  and in every shell; refusal (not auto-suffixing `-2`) keeps two similar
  items from looking like one.

## R6 — GitHub import without the GitHub CLI

- **Decision**: `import-github N` reads the public issue and its comments
  through GitHub's public REST interface
  (`https://api.github.com/repos/tandemcommander/tandemcommander/issues/N`
  and `/comments`) with the standard library, unauthenticated. If `gh` is
  installed it MAY be used instead. The issue text goes verbatim into
  `issue.md` (title, URL, author, date, body, comments); `reply.md` starts as
  a placeholder with `state: not-sent`.
- **Rationale**: measured — `gh` is not installed (neither in Bash nor in
  PowerShell); the spec's assumption "GitHub CLI already used" was wrong and
  is corrected in the spec. The repository is public, 60 unauthenticated
  requests an hour are plenty. This is a maintainer tool, not the product:
  no `PRIVACY.md` change (the product's network behaviour is unchanged).
- **Alternatives**: the assistant's web fetch inside the skill — rejected,
  not runnable without the assistant and summarises instead of copying
  verbatim.

## R7 — Skill layout

- **Decision**: two project skills in the format of the existing Spec Kit
  skills (front matter `name`, `description`, `argument-hint`,
  `user-invocable: true`, `disable-model-invocation: false`):
  - `.claude/skills/tandem-backlog/SKILL.md` — router: operations, the rules
    for agents (Inbox only), when to run `check`; `reference.md` — item
    templates per type, how to write a good item, triage guidance.
  - `.claude/skills/tandem-backlog-implement/SKILL.md` — the run procedure
    (preconditions, selection, measure first, Spec Kit steps, stop rules,
    closing, journal); `stop-rules.md` — the list of maintainer-owned
    questions and stop conditions.
  Both call `tools/backlog/backlog.py` for every mechanical change, so the
  invariants are enforced by code, not by the model's care.
- **Rationale**: decided in the conversation (two skills, not one or many);
  the Spec Kit skills show the expected format.

## R8 — Run lock

- **Decision**: `backlog.py lock acquire|release|status` manages
  `<git-common-dir>/tandem-backlog-run.lock` (`git rev-parse
  --git-common-dir`, so a worktree shares the main repository's lock). The
  file is created atomically (exclusive create) and holds `started`,
  `slug`, `branch`, `host`. `status` reports age and "stale" past 24 hours.
  `release` refuses to remove a lock it was not told the slug of (`--slug`
  must match) unless `--force` is given — `--force` is for the maintainer.
- **Rationale**: FR-039; unversioned, so it never reaches a commit; exclusive
  create closes the race between two starts.

## R9 — Feature number and branch

- **Decision**: taken from the Spec Kit git extension
  (`.specify/extensions/git/scripts/bash/create-new-feature.sh --json
  --short-name <slug-or-shorter>`), which takes the highest number among
  `specs/NNN-*` folders and local and remote branches, plus one (measured in
  the script). The skill passes no `--number`.
- **Rationale**: clarification Q3; one numbering authority for hand-run and
  autonomous features.

## R10 — Commit sequence of a run

- **Decision** (all local, never pushed):
  1. Preconditions on `main`: clean working tree, lock acquired. A dirty
     tree or a held lock ends the run with nothing changed.
  2. Selection and measure first on `main`. *Not reproduced* → item
     `blocked` with reason "not reproduced at <commit>", log, journal line,
     one commit on `main` `backlog: <slug> not reproduced`.
  3. Branch via the git extension; item `in-progress` + `feature` + log.
  4. Spec Kit steps; after each, the extension's commit hook runs (its
     configuration enables commits after specify, clarify, plan, tasks,
     implement — measured in `git-config.yml`).
  5. Success: remove the item (FR-020), *Inbox* items for leftovers,
     `FEATURE-HISTORY.md` entry, `closing-report.md`, journal line, final
     commit `[NNN] <summary>`, then `git checkout main` +
     `git merge --ff-only <branch>`. A failing fast-forward is a stop.
  6. Stop: commit the work in progress on the branch (`[NNN] stopped:
     <reason>`), checkout `main`, set the item `blocked` with reason and log,
     journal line, one commit on `main` `backlog: <slug> blocked (<NNN>)`.
  7. Release the lock in every path.
- **Rationale**: clarifications Q2–Q5. Because the item's `in-progress`
  state exists only on the branch, the commit on `main` at a stop is what
  keeps the next run from taking the item again.

## R11 — Clarify inside an autonomous run

- **Decision**: the run invokes `speckit-clarify` and answers each question
  itself with the recommended option, recording it in the spec as
  "Assumption (autonomous run): …". Before answering it tests the question
  against the maintainer-owned list (`stop-rules.md`): `PRIVACY.md` or other
  public claims, network communication, the plug-in interface, installer /
  uninstaller behaviour, what is stored or where, translations policy,
  enabling or disabling a plug-in, release or version, anything the item's
  log records as the maintainer's decision. A hit stops the run (FR-034).
- **Rationale**: clarify is interactive by design; an autonomous run has no
  person to ask, and the project's standing rules name exactly these areas
  as needing the maintainer.

## R12 — Migration

- **Decision**: done by reading, section by section, with a ledger
  `specs/242-backlog-system/migration-ledger.md`: one row per open entry —
  source (file, section, entry label and first words), destination
  (`item:<slug>`, `merged:<slug>`, `release-checklist`, `done (feature NNN)`,
  `not migrated: <reason>`). Grouping rule: one item = one feature's worth;
  person steps grouped by feature or topic. `source` keeps the original
  origin (`review:NNN`, `measure:NNN`, `github#N`, …) where the entry names
  it, otherwise `next-work`. `created` is the date the entry was first
  recorded when known, otherwise the migration date; `verified` is `-` unless
  the entry records a check at a commit. The release procedure goes to
  `backlog/RELEASE.md`. Afterwards `specs/NEXT-WORK.md` is deleted and each
  `REMAINING-WORK.md` gets its one-line note (FR-044).
- **Rationale**: FR-040 – FR-044, SC-003. The old file mixes done, partly
  done and open text inside the same paragraphs; only reading can split it.
  The ledger makes completeness reviewable by an independent agent.
- **Scale (measured)**: `NEXT-WORK.md` 2,226 lines, about 120 struck-through
  passages and 89 "done, feature N"; the five `REMAINING-WORK.md` files 1,248
  lines. Expected outcome: on the order of 60–120 items.

## R13 — Encoding and formatting of backlog files

- **Decision**: UTF-8 without BOM, LF or CRLF as git normalises, Markdown.
  Tables are written with single spaces around cells (no column alignment),
  so a sync of one row changes one line.
- **Rationale**: the existing Markdown in `specs/` has no BOM (measured on
  `spec.md`); aligned columns would rewrite whole tables on every change.

## R14 — Project integration points (measured)

`specs/NEXT-WORK.md` is named as the place for planned work in `CLAUDE.md`
lines 18, 178, 192, in the header of `specs/FEATURE-HISTORY.md` ("open items
are tracked in `specs/NEXT-WORK.md`") and in the assistant's memory
(`next-work-after-winget.md`). `architecture/12-project-reference.md:163`
mentions "NEXT-WORK item 7" as history only (no change needed). Entries in
fix-logs and `FEATURE-HISTORY.md` that cite NEXT-WORK are history and stay.
`CLAUDE.md` also names a branch `ai-main` that does not exist locally
(measured) — recorded as an *Inbox* item, not changed here.
