# Contract: version numbering, release tool checks, changelog heading, crash report name (343)

Amends `specs/243-tandem-release-skill/contracts/records.md` (record formats unchanged) and the
release tool's checks.

## Rule (stated once, in `backlog/RELEASE.md` *Version numbering*)

`MAJOR.MINOR.PATCH` (Semantic Versioning; in the sources the upstream names
`VERSINFO_SALAMANDER_MAJOR / MINORA / MINORB` stay):

- **MINOR** (`0.2.0`, `0.3.0`): a regular release - new features or user-visible changes.
- **PATCH** (`0.2.1`): fixes only; when `main` already carries features, it is made from a branch
  at the release tag.
- **MAJOR**: a deliberate break; `1.0.0` when the maintainer declares the product stable.
- The build number rises by one with every release, whatever the step.
- The plug-in interface version and plug-ins' own versions are independent.
- The configuration root does not depend on the version (contract `config-root-migration.md`).

## `release.py`

| Code | Kind | Condition |
|---|---|---|
| `line-change` | — | **removed** |
| `minorb-skip` | — | **replaced** by `version-step` |
| `version-step` | warning (evaluate) | target ∉ {`x.y.(z+1)`, `x.(y+1).0`, `(x+1).0.0`} of the previous release |
| `patch-kind` | warning (check) | target is `x.y.(z+1)` of the previous release and the lead's Kind contains no `fix` (case-insensitive) |
| `not-higher`, `tag-exists` | refusal | unchanged |

The skill asks before going on after `version-step` (as it asked after `minorb-skip`) and shows
`patch-kind` with the check's findings.

## `CHANGELOG.md`

Entries of finished, unreleased work go under `## [Unreleased]` (no version, no date). The release
turns it into `## [x.y.z] — YYYY-MM-DD` with the lead. The legacy form `## [x.y.z] — unreleased`
stays readable by the tool but is no longer written.

## Crash report name

`VERSINFO_SAL_SHORT_VERSION` = `"<MAJOR>.<MINORA>.<MINORB>" SAL_VER_PLATFORM` (`0.2.0x64`).
`SalFormatBugReportName` accepts `A-Z a-z 0-9` and `.` in the version tag, a dot neither first nor
last nor doubled; output `TC0.2.0X64-YYYYMMDD-HHMMSS[-n].TXT`.
