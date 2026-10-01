# Feature Specification: Workflows off the deprecated Node 20 actions

**Feature Branch**: `091-workflow-actions-node`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 6, P4 (`specs/072-winget-distribution/REMAINING-WORK.md` P4): the GitHub workflows use action versions that run on the deprecated Node 20; bump all workflows together so the repository keeps one convention.

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision.

- Q: Which version of each action? → A: **The newest major whose documented breaking changes do not touch what the workflow uses.** A workflow cannot be run from this session (nothing is pushed), so a version whose behaviour change reaches a workflow is not taken.
- Q: `actions/checkout` refuses to check out a fork's pull request under `pull_request_target` unless `allow-unsafe-pr-checkout: true` is set, and `pr-comments-guard.yml` does exactly that. Is that a reason to stay on an older major? → A: **No.** Measured: the refusal was introduced in v7.0.0 (2026-06-18) and **backported to every major on 2026-07-20** (v6.1.0, v5.1.0, v4.4.0, v3.7.0, v2.8.0) — the `v4` tag the workflow used already carries it. So the guard workflow has not worked for fork pull requests since that day, on any version. The version is therefore the newest, v7.
- Q: Set `allow-unsafe-pr-checkout: true` to bring the guard back? → A: **Not in this feature.** Turning on an input named "unsafe" in a workflow that runs with the base repository's token is a security decision for the maintainer; the risk analysis and a recommendation are in `fix-log.md`.
- Q: `ilammy/msvc-dev-cmd` has no Node 24 release. Replace it? → A: **No.** Replacing it changes the build workflow in a way that cannot be tested here; it stays on `v1` and is recorded.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Workflow runs without the Node 20 deprecation (Priority: P1)

A maintainer opens a workflow run. The first-party actions and `setup-msbuild` run on Node 24. One third-party action has no Node 24 release and stays; whether the runner still annotates it could not be confirmed without a run (the runner was due to drop Node 20 on 2026-09-23 and then runs such actions on Node 24 itself).

**Independent Test**: every `uses:` line names a version whose `action.yml` declares `node24` (or a composite / already-Node-24 action), except the recorded exception; the workflow files parse; the inputs each step passes exist in the chosen version.

**Acceptance Scenarios**:

1. **Given** the five workflow files, **When** their `uses:` lines are listed, **Then** each action appears in exactly one version across the repository.
2. **Given** the scripts of the two `github-script` steps, **Then** they use nothing the chosen version removed.
3. **Given** `pr-comments-guard.yml`, **Then** its behaviour with the chosen version is the same as with the version it had (for a pull request from a fork: refused by the checkout step on both — recorded, not changed here).

### Edge Cases

- A self-hosted runner older than 2.327.1 cannot run Node 24 actions: the workflows use GitHub-hosted runners only.

## Requirements *(mandatory)*

- **FR-001**: Every workflow MUST use, for each action, one version across the repository.
- **FR-002**: Each first-party action and `microsoft/setup-msbuild` MUST be at a version that runs on Node 24.
- **FR-003**: No step's behaviour may change: inputs, triggers, permissions and scripts stay as they are.
- **FR-004**: What could not be moved, and what was deliberately not taken, MUST be recorded with the reason.
- **FR-005**: No product file changes; no changelog entry (nothing a user of the program sees).

## Success Criteria *(mandatory)*

- **SC-001**: **4 of 5** distinct Node-based actions run on Node 24; the fifth is recorded with the reason.
- **SC-002**: **0** changed lines other than the version in a `uses:` line.
- **SC-003**: All five workflow files parse as YAML.

## Assumptions

- The first real run happens when the branch is merged and a pull request or release triggers the workflows; that confirmation is the maintainer's.
