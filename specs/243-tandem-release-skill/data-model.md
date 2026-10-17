# Data Model: Release Preparation (feature 243)

No database; the "data" are git tags and eight text records. The tool reads
them into the structures below on every call and never caches them.

## Version

| Field | Type | Rule |
|-------|------|------|
| major, minora, minorb | int 0–99999 | canonical text `^(0|[1-9]\d{0,4})(\.(0|[1-9]\d{0,4})){2}$` |
| text | str | `"{major}.{minora}.{minorb}"` |
| tag | str | `"v" + text` |
| installer | str | `"tandemcommander-" + text + "-x64-setup.exe"` |

Ordering: tuple comparison. `same_line(a, b)` ⇔ major and minora equal.

## Release context (computed by `status`)

| Field | Source |
|-------|--------|
| target | argument |
| date | `--date` or today (local) |
| prev | highest canonical tag `v*` below target (`git tag --list 'v*'`) |
| prev_build | `VERSINFO_BUILDNUMBER` in `git show <prev.tag>:src/plugins/shared/spl_vers.h` |
| build | `prev_build + 1` |
| branch | `git branch --show-current` |
| head | `git rev-parse --short HEAD` |
| tag_local / tag_remote | `git tag --list <tag>` / `git ls-remote --tags origin refs/tags/<tag>` (`yes` / `no` / `unknown`) |
| clean | `git status --porcelain` empty |
| lock | output of `python tools/backlog/backlog.py lock status` (`free` / holder) |
| copyright_year | year in `VERSINFO_COPYRIGHT` of `src/versinfo.rh2` |
| interface_changed | `LAST_VERSION_OF_SALAMANDER` at `prev.tag` ≠ in the work tree |
| source_version, source_build | macros in the work tree |
| state | see *State* below |
| features | sorted set of `NNN` from `feature[s] NNN[, NNN …]` in the release's changelog section(s) |
| issues | sorted set of `#n` / `GitHub #n` in the same section(s) |
| release_branches | local and remote branches `release-<target>*` with commits not in HEAD |
| gating | list of `{slug, title, status: open|done}` from *Current release* |
| gating_candidates | open `person-step` items naming a feature of `features` |
| warnings | build dir mismatch, certificate within 60 days, MINORB skip, branch ≠ `main`, remote unknown |
| refusals | list of reasons (non-empty ⇒ exit 1) |

## State

```text
not-prepared ──stamp──▶ prepared-today ──(commit; maintainer tags)──▶ released
      ▲                       │  ▲
      │                (day passes)│stamp
      │                       ▼  │
      └──(never)──────── prepared-earlier
inconsistent: any combination not listed below → refusal, no stamp
```

| State | Condition |
|-------|-----------|
| released | `tag_local` or `tag_remote` = yes |
| not-prepared | source = prev version and prev_build; no section of target with a date |
| prepared-today | source = target and build; changelog heading of target dated `date`; no `unreleased` section above prev; every record already at target/build/date (`check` passes) |
| prepared-earlier | source = target and build, and not prepared-today |
| inconsistent | source = neither; or a dated section of another version above prev; or source build ≠ build for the target |
| refused | the version is lower than the last release or changes MAJOR.MINORA (`not-higher`, `line-change`); the records are not examined |

## Changelog section

| Field | Rule |
|-------|------|
| heading | `## [<label>] — <date or "unreleased">` or `## [Unreleased]` |
| lead | lines from the first non-blank line after the heading to the next blank line, if the first line is not a list item |
| groups | `###` sub-headings, if any |
| entries | the remaining lines up to the next `## ` heading |

## Release record

| Field | Meaning |
|-------|---------|
| path | repository-relative |
| bom | bytes `EF BB BF` present |
| eol | `\r\n` or `\n` (dominant) |
| text | content with `\n` endings, BOM stripped |
| edits | list of `(line, old, new)` produced by `stamp` |

## Finding (output of `check`)

`<path>:<line>: <rule-id>: <message>` — rule ids in [contracts/cli.md](contracts/cli.md).

## Gating person step

Line of *Current release* in `backlog/RELEASE.md` under `Gating person steps:`
holding a backticked slug; `open` while `backlog/items/<slug>/desc.md` exists
with a status other than `rejected`, else `done`.
