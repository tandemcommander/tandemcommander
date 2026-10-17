# Research: Release Preparation Skill `tandem-release` (feature 243)

Inputs: the analysis of 2026-10-17 (`temp/tandem-release/PODKLADY.md`, not
tracked; its content is condensed here), the release commits of 0.1.1–0.1.10,
`backlog/RELEASE.md`, `tools/winget/publish.ps1`, `.github/workflows/winget-publish.yml`,
`src/common/salupdcheck.h`, the published GitHub release bodies (read through
the public API) and the spec's clarifications.

## Findings that shape the design

| # | Finding | Source |
|---|---------|--------|
| F1 | A release edits 8 records by hand: `spl_vers.h` (MINORB, `VERSINFO_BUILDNUMBER`, build-history comment), `tandemcommander.iss` (`MyAppVersion`), `CHANGELOG.md` (heading, lead), `PRIVACY.md` (validity paragraph, `Last updated`), `CLAUDE.md` (product line, *Status*), `architecture/12-project-reference.md` (product line), `backlog/RELEASE.md` (*Current release*), `release_notes/release_notes_v<ver>.md`. Everything else that carries the version is derived from the `spl_vers.h` macros or is history. | version sweep of the tree; commits 00899218, 4c852fe9, e176e6e6 |
| F2 | Nothing checks that `MyAppVersion` equals `VERSINFO_SALAMANDER_*`; `publish.ps1` only warns on the installer's ProductVersion. | `publish.ps1:249-252` |
| F3 | `publish.ps1` reads the date with `'^##\s+\[' + [regex]::Escape($Version) + '\]\D*(\d{4}-\d{2}-\d{2})'` (no match = WARNING + today) and the summary = first block of non-blank lines after the heading (stops at a blank line or `#{1,6}\s`), cleaned (links → text, `**` and backticks removed, — – “ ” ‘ ’ → ASCII, whitespace collapsed), cut at 900 at the last space with `...`, wrapped at 76 columns into a 2-space block; the template renderer then drops every line whose trimmed text starts with `#`. | `publish.ps1:119-207` |
| F4 | The workflow publishes on `release: published` from a checkout of the **tag**: the changelog at the tag is what reaches winget. | `.github/workflows/winget-publish.yml:41-66` |
| F5 | The in-app check accepts only `v<canonical x.y.z>` (1–5 digits, no leading zeros), not draft/prerelease, the exact asset `tandemcommander-<ver>-x64-setup.exe`. | `salupdcheck.h:89,194-226,1121-1210` |
| F6 | Published GitHub bodies are byte-identical to `release_notes/` files (0.1.1, 0.1.5, 0.1.9; 0.1.8 differs by one line added on GitHub). Files: UTF-8 without BOM, LF in git, CRLF in the work tree (`core.autocrlf=true`, `* text=auto`). No body ever carried SHA-256 / VirusTotal. | GitHub API, `git ls-files --eol` |
| F7 | Changelog headings were lost twice by later edits (4a00dc82, e5487658); a section was dated as released two days early (80dbdd86 → e6466db8); drafted changelog texts stayed in fix-logs (e6466db8). | git history |
| F8 | 0.1.10's lead lacks `**Build 194.**`; `[0.1.11] — unreleased` has no lead at all (winget would take the first bullet). | `CHANGELOG.md:12,509` |
| F9 | `spl_vers.h` is UTF-8 **with** BOM; the Markdown records and the `.iss` have no BOM; all are LF in git and CRLF in the work tree. | `head -c3`, `git ls-files --eol` |
| F10 | Done backlog items are removed (no `done` status); a person step is open while its folder exists. Item `type: person-step`. | `specs/242-backlog-system/contracts/item-format.md` |
| F11 | The constitution is at **3.1.0** (`CLAUDE.md` says v3.0.0 — stale); its *Release Documentation* requires the Added/Changed/Fixed/Removed groups and lists bump records without `PRIVACY.md` and the project reference. | `.specify/memory/constitution.md:178-232` |
| F12 | The stale `PrivilegesRequiredOverridesAllowed` claim of `tools/winget/README.md:204` is not in the existing item `winget-records-stale-claims-from-072-audit` (which covers FEATURE-HISTORY and fix-log claims). No item covers the old copyright notices (`salopen.rc:27`, `src/setup/setup.rc`, `remove.rc2:42`, `sfx7zip/resource.rc2:35`). | `backlog/items/` |
| F13 | Plugin interface 107 is unchanged since `v0.1.9`. | `git diff v0.1.9 HEAD -- spl_vers.h` |

## Decisions

### R1 — A standard-library Python tool owns the mechanics; the skill owns the wording

- **Decision**: `tools/release/release.py` (Python ≥ 3.13, standard library
  only, like `tools/backlog/backlog.py`) with commands `status`, `stamp`,
  `check`, `summary`. The skill `/tandem-release` calls them and writes the
  texts that need judgement: the changelog lead, the build-history comment's
  summary, the privacy "version before it" sentence, the release notes, the
  *Status* paragraph of `CLAUDE.md`, *Current release* of `RELEASE.md`.
- **Rationale**: every recorded release mistake (F7, the moving dates) is a
  mechanical one; numbers and dates are deterministic and testable. The
  backlog tool proved the pattern (feature 242).
- **Alternatives**: everything in skill instructions (rejected: the dates and
  numbers in 8 files are exactly what drifted by hand); a PowerShell tool
  (rejected: the backlog tool and the checkers are Python; Python is already a
  build requirement).

### R2 — Release state is derived, never stored

- **Decision**: `status` derives the state from git tags, `spl_vers.h` and the
  changelog: `released` (tag exists), `prepared-today`, `prepared-earlier`
  (version and build already set, dated section of the version, or a date ≠
  the release date anywhere), `not-prepared` (source at the previous version),
  `inconsistent` (anything else → stop).
- **Rationale**: FR-015 idempotence; no extra file to drift.

### R3 — Version and build rules

- **Decision**: version regex `^(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})$`
  (same as F5). `PREV` = highest tag `v<canonical>` below the target (tags not
  in canonical form are ignored). Target must be > `PREV`; MAJOR.MINORA must
  equal `PREV`'s (stop otherwise); MINORB ≠ PREV.MINORB + 1 → the skill asks.
  Build = `VERSINFO_BUILDNUMBER` read from `git show v<PREV>:src/plugins/shared/spl_vers.h`
  plus 1. Remote tag: `git ls-remote --tags origin refs/tags/v<ver>`; when the
  remote cannot be reached, `status` reports `remote: unknown` and the skill
  asks the maintainer.

### R4 — Changelog fold algorithm (mechanical part)

- **Decision**: in the region above the `PREV` section, every heading must be
  `[x.y.z]` (dated or `unreleased`), `[Unreleased]`, or `[higher] — unreleased`;
  a dated heading of another version → `inconsistent`. `stamp`:
  1. collects the sections in order (top first);
  2. if more than one section is to be folded and any of them has `###`
     groups → refuse (the skill merges by hand; never the case today) —
     implemented stricter than first planned, because bullets of an
     ungrouped section cannot be placed into groups mechanically;
  3. writes one heading `## [x.y.z] — <date>`, then the lead: the existing lead
     of the `[x.y.z]` section if any, else the first lead found, else the
     placeholder `**Build N.** TODO-KIND release. TODO-SUMMARY` (a placeholder
     makes `check` fail until the skill replaces it);
  4. then all entries, top section first, other sections' lead paragraphs
     dropped from the body and printed in the output for the skill to merge;
  5. verifies that the heading sequence from `PREV` down equals the tag list.
- A "lead paragraph" = the non-blank, non-heading lines between a heading and
  the first blank line, when the first of them is not a list item (`- `, `* `,
  `1. `).

### R5 — Winget summary is reproduced exactly

- **Decision**: `summary` reimplements F3 (extraction, clean-up, 900 cut,
  76-column wrap) and reports the lines that the renderer would drop. `check`
  fails when: no lead, the lead starts with a list marker, the summary was cut
  (> 900), a wrapped line starts with `#`, the lead contains `#` at all
  (stricter rule of FR-009), or the lead does not start with `**Build N.**`.
- **Rationale**: the script never fails on these (F3); the result is public.

### R6 — Gating person steps come from `RELEASE.md`

- **Decision**: *Current release* of `RELEASE.md` has a list
  `Gating person steps:` whose lines name backlog slugs in backticks. `status`
  reports each as `open` (folder exists, status not `rejected`) or `done`
  (folder removed). When *Current release* is about another (published)
  version, the list is empty; `status` then reports **candidates**: open
  `person-step` items whose text names a feature number of the release's
  changelog section. The skill asks (FR-004a) when at least one listed step is
  open and shows the candidates; the maintainer's answer decides which go into
  the new list.
- **Alternatives**: a new item field `gates: <ver>` (rejected: changes the
  item format of feature 242 for one consumer).

### R7 — File encoding and line endings are preserved byte-for-byte

- **Decision**: the tool reads bytes, remembers BOM and the dominant line
  ending of each file, edits in `\n` form and writes back with the same BOM and
  ending, atomically (temp file + replace). A file it does not change is never
  rewritten (idempotence, SC-003).

### R8 — Dates

- **Decision**: release date = `--date` or `datetime.date.today()`. Records:
  `YYYY-MM-DD`. Release notes: `f"{d.day} {MONTHS[d.month-1]} {d.year}"`
  with an English month table (no locale dependence). The date must be ≥ the
  previous tag's commit date and not later than today + 30 days (sanity).

### R9 — Records the tool sets and checks

| Record | `stamp` sets | `check` verifies |
|--------|--------------|------------------|
| `spl_vers.h` | MAJOR/MINORA/MINORB, `VERSINFO_BUILDNUMBER`; inserts `// N - Tandem Commander x.y.z (TODO-SUMMARY; see CHANGELOG.md)` before `// ! DULEZITE` if no entry for N exists | macros = target; entry `// N - Tandem Commander x.y.z (` exists exactly once, no `TODO`; entries for N-1… untouched; `LAST_VERSION_OF_SALAMANDER` and `REQUIRE_…` changed only if the interface changed since `PREV` |
| `tandemcommander.iss` | `MyAppVersion` | = target |
| `CHANGELOG.md` | fold (R4), heading date | R4/R5; no `unreleased` heading; headings of all tags present once, in order |
| `PRIVACY.md` | `describes Tandem Commander <ver>`, `Last updated <date>.`; for a new version shifts `In <PREV-old>, the version before it,` → `In <PREV-old>:` and inserts `In <PREV>, the version before it, TODO-PRIVACY.` | version, date, `In <PREV>, the version before it` present, no `TODO` |
| `CLAUDE.md` | product line: version, build, `release dated`, feature range (min–max of `feature N` in the section), previous version / build / tag; `## Status (<date>)` | same values; *Status* paragraph names the version and "prepared for the <ver> release" |
| `architecture/12-project-reference.md` | product line, same fields | same values |
| `backlog/RELEASE.md` | heading `## Current release: <ver> (build N) — prepared, not published` | heading, a commit hash, the `Gating person steps:` list |
| `release_notes_v<ver>.md` | new file: skeleton (title, header line with `TODO-KIND`, `## New`/`## Changed`/`## Fixed`/`## Removed` with `TODO`, footer); existing: date and build of the header line | title, header regex, allowed sections only and none empty, the fixed footer, no `TODO`, every `#n` issue of the changelog section present, no BOM |

### R10 — Verification inside the skill

- **Decision** (clarification 2): `release.py check <ver>` and
  `python tools/check_encoding.py --strict`; nothing else. The build-dir and
  certificate warnings are computed by `status` (environment variable
  `OPENSAL_BUILD_DIR` vs the `.iss` source path; `RELEASE.md` *Standing
  dates*).

### R11 — Commit and refusals

- **Decision**: preconditions in `status` (exit 1 with a reason line per
  failed condition): tag local/remote, version form, ordering, MAJOR.MINORA,
  clean tree (`git status --porcelain` empty), backlog lock free
  (`python tools/backlog/backlog.py lock status`), copyright year (the year in
  `VERSINFO_COPYRIGHT` of `src/versinfo.rh2` ≥ release year). Branch ≠ `main`
  is reported, not refused (the skill asks). One commit:
  `Version x.y.z: the tree prepared for the release (YYYY-MM-DD)`, body from a
  file (never item text on a command line, lesson of 242).

### R12 — Constitution amendment 3.1.0 → 3.2.0

- **Decision**: MINOR (guidance materially changed): *Release Documentation*
  — groups optional, bullets citing feature/issue accepted, the lead
  `**Build N.** <Kind> release.` required, the list of release records
  replaced by a pointer to `backlog/RELEASE.md` *Release records* and
  `/tandem-release`. Sync Impact Report on top; `CLAUDE.md` row corrected to
  v3.2.0.

### R13 — One list of release records

- **Decision**: the authoritative list lives in `backlog/RELEASE.md` (new
  section *Release records*, the table of R9 in prose); `CLAUDE.md` *Product
  identity* and the constitution point to it; the skill's `reference.md` and
  the tool implement it (the tool's docstring names the list).

### R14 — Tests

- **Decision**: `python -m unittest tools/release/test_release.py` builds a
  miniature repository in a temp folder (`git init`, the 8 records in
  miniature from `tools/release/fixtures/`, commits and tags `v0.1.0`,
  `v0.1.1`) and covers: each state of R2, each refusal, fold with 0/1/2
  unreleased sections, lead handling, idempotence (second `stamp` writes
  nothing), BOM and CRLF preservation, the summary replica against expected
  outputs (incl. a `#` line and a > 900 lead), the release-notes checks, and
  a seeded defect per `check` rule.

### R15 — Backlog items for out-of-scope findings

- **Decision**: two *Inbox* items through `/tandem-backlog add`, source
  `review:243`: old copyright notices without the Tandem holder (area
  `build-release`), and the stale README claim (related
  `winget-records-stale-claims-from-072-audit`). `shellext.rc` gets no item
  (clarification 5).

### R16 — Validation on the real tree without preparing a release

- **Decision**: the quickstart runs `status` and `stamp --dry-run` for 0.1.10
  on the real tree, and a full skill run on a throw-away worktree
  (`git worktree add` of `main` in the scratch directory), which is removed
  afterwards. Preparing 0.1.10 for real stays the maintainer's run.
