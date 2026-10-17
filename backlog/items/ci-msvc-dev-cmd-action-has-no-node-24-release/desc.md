---
title: CI: ilammy/msvc-dev-cmd@v1 is a Node 20 action with no Node 24 release
type: tech-debt
status: open
severity: 2
area: build-release
source: leftover:091
who: both
created: 2026-10-01
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# CI: ilammy/msvc-dev-cmd@v1 is a Node 20 action with no Node 24 release

## Problem

Feature 091 moved every other GitHub action of the five workflows to a Node 24 version; `ilammy/msvc-dev-cmd@v1` in `pr-msbuild.yml` stayed, because no Node 24 release exists (`master` is node20, latest tag v1.13.0). By the runner's constants Node 24 became the default on 2026-06-16 and Node 20 was to be removed on 2026-09-23, so the runner most likely already runs the action on Node 24 - whether a deprecation annotation remains, or whether the step fails, was never seen: none of the workflows has had a real run since 091.

## Evidence

specs/072-winget-distribution/REMAINING-WORK.md section P4 ("Left: `ilammy/msvc-dev-cmd@v1` (no Node 24 release exists). Not run", L279-284); specs/091-workflow-actions-node/fix-log.md (table row ~L17 and finding 2, ~L63-70). Present at 7993914c: .github/workflows/pr-msbuild.yml:46 `uses: ilammy/msvc-dev-cmd@v1`.

## Expected

A real run of pr-msbuild.yml shows no Node 20 annotation and a working build step; if the action fails or warns, the step is dropped (MSBuild is found by `microsoft/setup-msbuild`) or replaced, and the workflow still builds.

## Approach

091's fix-log: "If it ever fails: MSBuild is found by `setup-msbuild`, so the step can probably be dropped - to be tried on a real run."

## Notes

The real run of the Node 24 workflows (091) is the person step `github-repo-housekeeping-091-083`. 091's fix-log also records pre-existing nits not in this source (`msvc-problem-matcher@master` unpinned, `git fetch --depth=0` in the guard, the auto-label `labeled` event).

## Log

- 2026-10-01 — feature 091: left unchanged - no Node 24 release of the action exists
- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
