# Tandem Commander — Backlog

All planned work: bugs, features, improvements, debts, decisions and steps
owed to a person. **The order of rows is the priority**, top first. Only the
maintainer triages and reorders; agents add new items to *Inbox* and nothing
else. Each row links to its item's description `items/<slug>/desc.md`, which
is the only source of the item's data: every column except **#** and the
row's place is written by `bin/backlog.sh sync` (every
changing command of the tool runs it). Manage the backlog with
`/tandem-backlog`; run one item autonomously with `/tandem-backlog-implement`.
Formats: `specs/242-backlog-system/contracts/`. Runs: `RUNS.md`. Release
procedure: `RELEASE.md`.

Last triaged: 2026-10-17

## In progress

| # | Item | Type | Sev | Area | Feature |
|---|---|---|---|---|---|
| 1 | [Archive pack refuses a long folder silently](items/archive-pack-refuses-a-long-folder-silently/desc.md) | bug | 6 | archives | 243 |

## Next

| # | Item | Type | Sev | Area | Who | Effort | Status |
|---|---|---|---|---|---|---|---|
| 1 | [Disk Map context menu crash](items/disk-map-context-menu-crash/desc.md) | bug | 8 | other-plugins | agent | - | blocked |
| 2 | [FTP per-server encoding flag](items/ftp-per-server-encoding-flag/desc.md) | improvement | 3 | ftp | agent | - | open |

## Decisions for the maintainer

| # | Item | Sev | Area | Status |
|---|---|---|---|---|
| 1 | [Ship the Network plug-in?](items/ship-network-plugin/desc.md) | 4 | plugin-api | open |

## Person steps

| # | Item | Area | Status |
|---|---|---|---|
| 1 | [Release 0.1.10 person checks](items/release-0-1-10-person-checks/desc.md) | build-release | open |

## Inbox

| Item | Type | Sev | Area | Source | Created |
|---|---|---|---|---|---|
| [Typed path with a \| pipe \[brackets\]](items/typed-path-with-a-pipe-brackets/desc.md) | bug | 2 | panels-ui | manual | 2026-10-17 |

## Parked

| Item | Area | Reason |
|---|---|---|
| [Help footers still say Open Salamander](items/help-footers-still-say-open-salamander/desc.md) | help-docs | cosmetic, one mechanical pass when wanted |

## Rejected

| Item | Area | Reason |
|---|---|---|
| [B-2 systemic comparison](items/b-2-systemic-comparison/desc.md) | encoding | maintainer 2026-10-04 |

## Legend

The first column of each table is the allowed value; the tool reads the
vocabularies from here. Adding a value = adding a row.

### Types

| Value | Meaning |
|---|---|
| `bug` | the program does something wrong |
| `feature` | a new capability |
| `improvement` | an existing capability made better |
| `tech-debt` | internal work with no direct user-visible change |
| `decision` | a question only the maintainer can answer |
| `person-step` | a check or action that needs a person (real keyboard, clipboard, hardware, a server, a release step) |

### Statuses

| Value | Meaning | Section |
|---|---|---|
| `new` | recorded, not triaged | Inbox |
| `open` | triaged, waiting for work | Next / Decisions / Person steps |
| `blocked` | triaged, cannot proceed now — `reason` says why | Next / Decisions / Person steps |
| `in-progress` | a feature is being implemented — `feature` says which | In progress |
| `parked` | deliberately not now — `reason` says why | Parked |
| `rejected` | decided not to do — re-open only with a new reason | Rejected |

A finished item is removed (git, `specs/FEATURE-HISTORY.md` and the
feature's spec keep the record); there is no `done` status.

### Severity

| Value | Meaning |
|---|---|
| `9`–`10` | data loss or a crash in a common scenario |
| `7`–`8` | data loss in a narrow scenario, or a crash in an unusual one |
| `4`–`6` | a function does not work; a workaround exists |
| `1`–`3` | cosmetic or wording |
| `0` | trivial |

For features and improvements the number expresses importance on the same
scale.

### Areas

| Value | Meaning |
|---|---|
| `build-release` | build, signing, installer, winget, CI, releases |
| `translations` | translation pipeline, language files, layout of translated dialogs |
| `encoding` | UTF-8 / WTF-8 contracts, code-page residue, text in controls and titles |
| `long-paths` | long paths and names, buffers, refusals instead of cuts |
| `file-ops` | copy, move, delete, rename, attributes in the core |
| `data-safety` | same-file guards, safe replace, links — anything that can lose data |
| `panels-ui` | panels, menus, dialogs, keyboard, command line of the core |
| `viewer` | the built-in viewer and the Code / Markdown viewers' core side |
| `archives` | archives in the core, the disk cache, external archivers, ZIP and 7-Zip plug-ins |
| `plugin-api` | the plug-in interface, loading, closing for an update |
| `webview` | the shared WebView2 host |
| `privacy-security` | network communication, credentials, `PRIVACY.md` claims |
| `ftp` | the FTP plug-in |
| `sftp` | the SFTP plug-in |
| `pictview` | the PictView plug-in |
| `other-plugins` | every other plug-in (Registry Editor, Renamer, Undelete, Disk Map, Checksum, …) |
| `help-docs` | the manual, README, architecture and project documents |
| `tooling` | probes, checkers, scripts, the backlog itself |

### Sources

| Value | Meaning |
|---|---|
| `manual` | added by hand |
| `github#N` | GitHub issue N (`issue.md` holds its text) |
| `review:NNN` | found by a review of feature NNN |
| `leftover:NNN` | left open by feature NNN |
| `measure:NNN` | found by measuring during feature NNN |
| `probe:NNN` | found by a probe of feature NNN |
| `next-work` | migrated from `specs/NEXT-WORK.md` with no identifiable origin |

### Who

| Value | Meaning |
|---|---|
| `agent` | an agent can do it alone |
| `person` | needs a person |
| `both` | an agent does most of it; a person finishes or checks |

### Effort

| Value | Meaning |
|---|---|
| `S` | hours |
| `M` | about a day |
| `L` | several days or a feature series |
| `?` | unknown |
