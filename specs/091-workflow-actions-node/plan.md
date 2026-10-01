# Implementation Plan: workflow action versions

**Branch**: `091-workflow-actions-node` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Research (measured 2026-10-01)

`runs.using` of each `action.yml`, read from the tag
(`raw.githubusercontent.com/<repo>/<tag>/action.yml`); latest tags from
`git ls-remote --tags`; breaking changes from the release notes.

| Action | Was | `using` | Candidates (`using`) | Chosen | Why |
|---|---|---|---|---|---|
| `actions/checkout` | v4 | node20 | v5 node24, v6 node24, v7 node24 | **v7** | v6: credentials kept in a separate file under `$RUNNER_TEMP`, "no workflow changes required"; v7: ESM, dependency updates, and the refusal to check out fork pull-request code under `pull_request_target` unless `allow-unsafe-pr-checkout: true`. That refusal was **backported to v2–v6 on 2026-07-20** (the `action.yml` at the tags `v4`, `v5`, `v6` all declare the input with default `false`), so it is no reason to prefer an older major: `pr-comments-guard.yml` is affected on every one of them, including the `v4` it used |
| `actions/upload-artifact` | v4 | node20 | v5 node20, v6 node24, v7 node24 | **v7** | v7 adds an optional `archive: false` and moves to ESM; default behaviour (zip, `name`, multi-line `path`, `if-no-files-found`) unchanged |
| `actions/github-script` | v7 | node20 | v8 node24, v9 node24 | **v9** | v9 breaks only `require('@actions/github')` and scripts that declare `getOctokit`; both scripts use `context`, `core` and `github.rest` only |
| `microsoft/setup-msbuild` | v2 | node20 | v3 node24 | **v3** | "Update to Node24", no other change |
| `ilammy/msvc-dev-cmd` | v1 | node20 | none (`master` is node20; latest v1.13.0) | **v1 (kept)** | no Node 24 release exists |
| `ammaraskar/msvc-problem-matcher` | master | node24 | — | unchanged | already Node 24 |

## Constitution Check

Build reproducibility: the local build is untouched; CI keeps building the
same solution with the same arguments ✅. No product change ✅.

## Verification

Static only (nothing can be pushed or run from this session): the diff is
8 lines, each a version in a `uses:` line; all five files parse with a YAML
parser; `grep` shows no `require(` / `getOctokit` in the scripts; every
input passed to a changed action is listed in that version's `action.yml`.
