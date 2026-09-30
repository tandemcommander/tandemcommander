# Implementation Plan: Privacy Statement for the winget Catalogue

**Branch**: `083-privacy-policy-winget` | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/083-privacy-policy-winget/spec.md`

## Summary

Publish an accurate, plain-language privacy statement for Tandem Commander as
`PRIVACY.md` at the repository root and reference it from the winget locale
manifest template as `PrivacyUrl`, so that the catalogue submission
(microsoft/winget-pkgs#426090) no longer lacks the disclosure moderators have
been requesting from credential-storing packages. The work is evidence first:
a data-surface inventory of the main application, the 20 plugins enabled in
the default build and the installer (Phase 0, [research.md](research.md))
fixes every claim before any sentence is written; the statement is then
written against a content contract ([contracts/privacy-statement.md](contracts/privacy-statement.md)),
checked claim-by-claim by an independent reviewer, and kept true afterwards by
an update rule in `CLAUDE.md`. No product code, UI or translation changes.

## Technical Context

**Language/Version**: Markdown (GitHub-flavoured) for `PRIVACY.md`; YAML
template `tools/winget/templates/locale.en-US.yaml.in` rendered by
`tools/winget/publish.ps1` (Windows PowerShell 5.1)  
**Primary Dependencies**: winget manifest schema 1.10.0 (`PrivacyUrl`,
optional, defaultLocale); `winget validate`; GitHub (hosting of the rendered
document, private vulnerability reporting)  
**Storage**: N/A (documentation). The *subject* of the document is the
product's storage: `HKCU\Software\Tandem Commander\0.1`,
`%LOCALAPPDATA%\Tandem Commander\` (crash reports, WebView2 user data folder),
temporary files  
**Testing**: `publish.ps1 -Version <released>` (generate + `winget validate`,
no submit); HTTP status of the published URL; evidence cross-check by an
independent reviewer; reader test (SC-004)  
**Target Platform**: GitHub web rendering of `PRIVACY.md`; winget catalogue  
**Project Type**: documentation + release-tooling metadata for a Windows
desktop application  
**Performance Goals**: N/A  
**Constraints**: every claim evidence-backed (FR-003/FR-005); no reference to
the private reporting channel until it is enabled (FR-009, currently
`enabled: false`); no push to #426090 and no catalogue submission from this
feature (FR-010); template rule "no line inside a block scalar may start with
`#`" (template header)  
**Scale/Scope**: main app + installer + 20 enabled plugins (+ disabled
plugins only as far as they could ship); one document of roughly 1–2 pages

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Build Reproducibility | Not touched — no build input changes. `PRIVACY.md` is not packaged by the installer (see research R6). PASS |
| II. Backward Compatibility | No behaviour change; FR-010 forbids one. PASS |
| III. Incremental Modernization | One document, one template line, one instruction paragraph; each independently revertible. PASS |
| IV. Windows Platform Commitment | Not affected. PASS |
| V. Plugin Architecture Preservation | Plugins are only described, not changed; third-party plugins are named as outside the statement. PASS |
| VI. UI Consistency | No UI. PASS |
| Development Workflow — single concern | The feature is the disclosure only. Side findings (the `OpenSalamander-mdview` User-Agent, stale records from 072 § P0) are recorded, not fixed here. PASS |
| Release Documentation (`CHANGELOG.md`) | The statement changes nothing a user of the program experiences, so no changelog entry (research R7). It describes the product as released; if a later release changes data handling, that release's changelog and the statement change together (FR-007). PASS |

No violations; Complexity Tracking not needed.

**Post-design re-check (after Phase 1)**: unchanged — the design adds no code,
the contract only constrains document content, and the template change is one
optional field. PASS.

## Project Structure

### Documentation (this feature)

```text
specs/083-privacy-policy-winget/
├── spec.md
├── plan.md              # this file
├── research.md          # Phase 0: decisions + data-surface inventory with evidence
├── data-model.md        # Phase 1: statement, data surface, evidence, manifest field
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── privacy-statement.md   # what PRIVACY.md must contain and must not claim
│   └── winget-privacyurl.md   # the manifest field, its URL and generation rules
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks) — not created here
```

### Source Code (repository root)

```text
PRIVACY.md                                   # NEW — the statement
tools/winget/templates/locale.en-US.yaml.in  # + PrivacyUrl line and authoring note
tools/winget/README.md                       # + one row/sentence naming PrivacyUrl
CLAUDE.md                                    # + update rule (FR-007)
README.md                                    # + link to PRIVACY.md (optional, one line)
```

**Structure Decision**: documentation at the repository root, next to
`LICENSE`, `CHANGELOG.md` and `README.md`, because the manifest already points
`LicenseUrl` and the Changelog document at `github.com/.../blob/main/<file>`
and the same pattern gives a stable, version-independent address (research
R2). No source directories are touched.

## Complexity Tracking

Not applicable — no constitution violations.
