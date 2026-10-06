# Data Model: New Version Check

**Feature**: 123-new-version-check · **Date**: 2026-10-06

Names are proposals for the implementation; the rules are binding.

## Entities

### Version (`CSalUpdVersion`, pure)

| Field | Type | Rule |
|---|---|---|
| Major, Minor, Patch | unsigned | each parsed from 1–5 decimal digits |

- Parsed from a tag `v<major>.<minor>.<patch>` or from stored text
  `<major>.<minor>.<patch>`; any other form is invalid.
- Total order: lexicographic on (Major, Minor, Patch).
- The **installed version** is (`VERSINFO_SALAMANDER_MAJOR`, `_MINORA`,
  `_MINORB`); a beta suffix, if one is ever used, does not take part.

### Latest release (`CSalUpdRelease`, pure)

| Field | Source | Rule |
|---|---|---|
| Version | `tag_name` | valid Version |
| PublishedUtc | `published_at` | valid `YYYY-MM-DDThh:mm:ssZ` |
| (installer address) | constructed from Version | answer must contain the matching asset, `state == "uploaded"`, with exactly this address |
| (release-notes address) | constructed from Version | answer's `html_url` must equal it |

Addresses are never stored or carried from the answer; they are rebuilt from
Version whenever needed (`SalUpdInstallerUrl`, `SalUpdReleaseNotesUrl`).

### Check result (`CSalUpdResult`)

| Value | Meaning | Changes what is known? |
|---|---|---|
| `surNewer` | valid release, Version > installed | yes |
| `surUpToDate` | valid release, Version ≤ installed | yes |
| `surUnreachable` | no HTTP answer (no connection, DNS, TLS, timeout) | no |
| `surRefused` | HTTP 403 / 429 (rate limit) | no |
| `surUnexpected` | any other status, oversized, not JSON, record fails validation | no |
| `surCancelled` | the user cancelled, or the program is closing | no |

### Stored state (`CUpdateState`, registry — see contracts/stored-state.md)

| Field | Type | Default | Written when |
|---|---|---|---|
| CheckAtStartup | bool | **on** | option changed (configuration page or notification) |
| LastAttemptUtc | time | none | a check is claimed, before the request |
| LastAttemptAnswered | bool | false | the request ended: true if any HTTP status was received |
| LastSuccessUtc | time | none | result `surNewer` / `surUpToDate` |
| LatestVersion | Version | none | result `surNewer` / `surUpToDate` |
| LatestPublishedUtc | time | none | with LatestVersion |
| SkippedVersion | Version | none | *Skip This Version* |

Derived, never stored:

- **Known state for the About dialog**: `newer` if LatestVersion > installed;
  `upToDate` if LatestVersion exists and ≤ installed; `notChecked` otherwise.
  (After the user installs the new version, the same stored values read as
  `upToDate` — no clean-up step is needed.)
- **Start-up notification wanted**: result `surNewer` from an *automatic*
  check and Version ≠ SkippedVersion. A skipped version lower than a newer
  release no longer matters.

## Decisions (pure functions)

| Function | Inputs | Output |
|---|---|---|
| `SalUpdAutoCheckDue` | CheckAtStartup, LastAttemptUtc, LastAttemptAnswered, now | due / not due |
| `SalUpdParseLatestRelease` | answer bytes, length | `CSalUpdRelease` or failure |
| `SalUpdClassify` | release, installed version | `surNewer` / `surUpToDate` |
| `SalUpdStartupNoticeWanted` | result, release, SkippedVersion | bool |
| `SalUpdKnownState` | LatestVersion, installed version | newer / upToDate / notChecked |

`SalUpdAutoCheckDue`: not due if the option is off; due if there is no
LastAttemptUtc or it lies in the future; otherwise due when
`now − LastAttemptUtc ≥ 24 h` (LastAttemptAnswered) or `≥ 1 h` (not answered).

## State transitions of one check

```text
            claim (mutex, LastAttempt = now)
 idle ───────────────────────────────────────► running
   ▲                                             │
   │   surCancelled / exit                       │ answer or failure
   ├─────────────────────────────────────────────┤
   │                                             ▼
   │                               store result (success only)
   │                                             │
   │        automatic                            │ manual
   │   ┌───────────────┬─────────────┐   ┌───────┴────────┬──────────────┐
   │   ▼               ▼             ▼   ▼                ▼              ▼
   │ newer, not     newer but     other  newer          upToDate       failure
   │ skipped        skipped / up  (silent) (notice,     (message)      (message by class)
   │ (notice when   to date                activated)
   │  possible)     (silent)
   └───┴───────────────┴─────────────┴───────┴────────────┴──────────────┘
```

A manual request while a check is running attaches to it (the running check
is promoted to manual: its result is answered, the skipped version ignored).

## Notification choices

| Choice | Effect on stored state | Window |
|---|---|---|
| Download | none | opens the installer address in the default browser; closes |
| Release notes (link) | none | opens the release-notes address; stays open |
| Remind Me Later / Esc / close button | none | closes; shown again by the next automatic check that finds it |
| Skip This Version | SkippedVersion = Version | closes |
| Check box toggled | CheckAtStartup written at once | stays open |
| Installer closes the program (080) | none | destroyed, as Remind Me Later |

## Limits

| What | Limit |
|---|---|
| Answer size | 256 KB, larger is `surUnexpected` |
| JSON nesting | 32 levels |
| Extracted string length | 512 bytes (longer fails the field) |
| Version part | 5 digits |
| Whole request | 12 s deadline |
| Automatic requests | 1 per 24 h per user after an answered attempt; 1 per hour while the source cannot be reached |
