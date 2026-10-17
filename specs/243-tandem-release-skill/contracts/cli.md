# Contract: `tools/release/release.py`

Run from the repository root: `python tools/release/release.py <command> …`.
Standard library only. Output is English, UTF-8. Exit codes: **0** success /
no findings, **1** refused or findings, **2** usage error.

Common options: `--date YYYY-MM-DD` (release date; default today, local
time), `--root PATH` (repository root; default: the folder two levels above
the script — used by the tests), `--offline` (do not ask the remote; the
remote tag state becomes `unknown`).

## `status <version> [--json]`

Reads only. Prints the release context (data-model.md) as `key: value` lines,
or one JSON object with `--json`. Sections of the text output, in order:

```text
version: 0.1.10   tag: v0.1.10   installer: tandemcommander-0.1.10-x64-setup.exe
date: 2026-10-17 (17 October 2026)
previous: 0.1.9 (tag v0.1.9, build 193)   build: 194
branch: main   head: c3319ffa   clean: yes   lock: free
tag-local: no   tag-remote: no
source: 0.1.10 build 194   interface: 107 (unchanged since v0.1.9)
state: prepared-earlier
features: 124-241 (118)   issues: #3 #5 #6 #7 #8
release-branches: release-0.1.10 (00899218, 9 commits not in HEAD) …
gating: open pictview-own-photos-pipette-histogram-print — PictView by hand: …
gating-candidates: drag-drop-paste-routes-194-228-230-240-by-hand — …
warning: <text>                      (zero or more)
refused: <reason>                    (zero or more; exit 1 if any)
```

Refusal reasons (one line each, all that apply):
`version-form`, `tag-exists`, `not-higher`, `line-change` (MAJOR.MINORA
differ), `dirty-tree`, `lock-held`, `copyright-year`, `detached-head`,
`inconsistent: <why>`, `no-previous-tag` (also when the previous tag exists
only on the remote). Remote tags are read with one `ls-remote` of `v*` and
merged with the local ones.

Warnings: `branch-not-main`, `minorb-skip`, `remote-unknown`,
`remote-tags-not-fetched`, `date-past`, `date-range`,
`build-dir` (`OPENSAL_BUILD_DIR` set and not the folder the `.iss` packs from),
`certificate` (expiry within 60 days), `release-branch-ahead`.

Features of the release are the numbers cited in parentheses —
`(feature 134; GitHub #7)`, `(features 138-140)` — in the changelog region
above the previous release; a first paragraph is a lead only when it starts
with `**Build ` (or is the lead of the target's own dated section); any other
first paragraph is a prose entry and stays in the body.

## `stamp <version> [--dry-run]`

Refuses (exit 1, nothing written) when `status` would refuse; warnings do not
refuse. Applies the mechanical edits of research R9 to the 8 records,
preserving BOM and line endings, writing only files whose content changes.
Prints one line per change `<path>:<line>: <old> -> <new>` (shortened),
then, for a changelog fold, the lead paragraphs it dropped:

```text
dropped-lead: [0.1.11] (line 14): <text>
```

and finally `changed: N file(s)` or `unchanged`. With `--dry-run` it prints
the same and writes nothing. Second run on the same day: `unchanged`, exit 0.

Placeholders it may write (and `check` rejects): `TODO-SUMMARY`,
`TODO-KIND`, `TODO-PRIVACY`, `TODO`.

## `check <version>`

Reads only. Verifies every record (research R9) for the version, the build
(`prev_build + 1`), the release date and the previous version. Prints
findings `<path>:<line>: <rule>: <message>` and a last line `findings: N`.
Rules:

| Rule | Meaning |
|------|---------|
| `source-version` | `VERSINFO_SALAMANDER_*` ≠ target |
| `source-build` | `VERSINFO_BUILDNUMBER` ≠ build |
| `build-history` | no / more than one `// N - Tandem Commander x.y.z (` entry, or it holds `TODO` |
| `interface-text` | interface changed since prev but `REQUIRE_…` does not say `first shipped in version <target>` |
| `installer-version` | `MyAppVersion` ≠ target |
| `changelog-heading` | no `## [x.y.z] — <date>` or a different date |
| `changelog-unreleased` | an `unreleased` heading remains |
| `changelog-history` | the headings from prev down differ from the tag list (missing, duplicate, order) |
| `changelog-lead` | no lead, lead is a list item, lacks `**Build N.**`, contains `#`, or holds `TODO` |
| `winget-summary` | summary cut (> 900), empty, or a wrapped line starts with `#` |
| `privacy-version` | no `This statement describes Tandem Commander <target>` |
| `privacy-previous` | no `In <prev>, the version before it,` or `TODO-PRIVACY` remains |
| `privacy-date` | `Last updated <date>.` missing |
| `claude-product` | product line of `CLAUDE.md` ≠ target / build / date / prev / prev build / tag, or its feature range ≠ the cited features |
| `claude-status` | `## Status (<date>)` missing, the paragraph does not say `prepared for the <target> release`, or names "the tree prepared for the release (<other date>)" |
| `reference-product` | product line of the project reference differs (same fields) |
| `release-current` | `## Current release: <target> (build N) — prepared, not published` missing, no `Gating person steps:` list, "the tree prepared for the release (<other date>)", or the feature range missing from the section |
| `notes-missing` | `release_notes/release_notes_v<target>.md` missing |
| `notes-header` | title or `**Released <d Month yyyy> · build N · Windows 11 or newer, 64-bit · <kind>**` wrong |
| `notes-sections` | a section other than New / Changed / Fixed / Removed, an empty one, or a wrong order |
| `notes-footer` | the last line is not the fixed footer |
| `notes-issues` | an issue `#n` of the changelog section is not in the notes |
| `notes-todo` | `TODO` remains |
| `notes-encoding` | BOM present |

## `summary <version>`

Reads only. Prints the winget summary exactly as `publish.ps1` would compute
it, its length, the wrapped YAML lines, and `dropped-line: …` for every
wrapped line the renderer would drop. Exit 1 if `winget-summary` or
`changelog-lead` would be reported.
