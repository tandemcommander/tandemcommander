# Fix log: feature 091 — workflow action versions

Branch `091-workflow-actions-node`, based on `090-ftp-anonymous-default`.
Nothing was pushed and no workflow was run; everything below is static
verification against the upstream tags (2026-10-01).

## What changed

Eight lines, each the version in a `uses:` line:

| Action | Was | Is | Files |
|---|---|---|---|
| `actions/checkout` | v4 (node20) | **v7** (node24) | pr-comments-guard, pr-msbuild, winget-publish |
| `actions/upload-artifact` | v4 (node20) | **v7** (node24) | pr-msbuild, winget-publish |
| `actions/github-script` | v7 (node20) | **v9** (node24) | auto-label-author, pr-squash-guard |
| `microsoft/setup-msbuild` | v2 (node20) | **v3** (node24) | pr-msbuild |
| `ilammy/msvc-dev-cmd` | v1 (node20) | unchanged | pr-msbuild — no Node 24 release exists (`master` is node20, latest tag v1.13.0) |
| `ammaraskar/msvc-problem-matcher` | master (node24) | unchanged | pr-msbuild |

## Verification

- `runs.using` read from `action.yml` at each tag.
- Every input our steps pass exists in the new version with the same
  meaning: checkout `ref`, `fetch-depth`, `persist-credentials`, `path`;
  upload-artifact `name`, `path`, `if-no-files-found`; github-script
  `script`; setup-msbuild none.
- github-script v9 breaks `require('@actions/github')` and scripts that
  declare `getOctokit`: neither script does; `github.rest.issues.getLabel /
  createLabel / addLabels` and `github.rest.pulls.get` are present in v9's
  bundle with the same routes (reviewer).
- upload-artifact v7 only adds `archive` (default `true`).
- All five files parse as YAML; the diff has no other line.

## Independent review — ACCEPT

No blocker. Two SHOULD-FIX in the records: this file was missing (written
now), and the spec's statement about the remaining Node 20 annotation was
too confident — see below.

## Findings to hand over (not changed here)

1. **`pr-comments-guard.yml` has not worked for fork pull requests since
   2026-07-20, on any version of `actions/checkout`.** The action refuses
   to check out fork pull-request code under `pull_request_target` unless
   `allow-unsafe-pr-checkout: true`; the refusal shipped in v7.0.0
   (2026-06-18) and was backported to v2–v6 on 2026-07-20 (v4.4.0 for the
   `v4` tag the workflow used). It triggers when the event is
   `pull_request_target`, the head repository differs from the base, and
   `ref` is the pull request's head SHA — exactly this workflow. So every
   fork pull request carrying the label *comments translation* fails at the
   checkout step, in both matrix legs; same-repository pull requests are
   exempt. **Decision for the maintainer**:
   - *opt in* (`allow-unsafe-pr-checkout: true`): the job has `contents:
     read`, does not persist credentials, exposes `GITHUB_TOKEN` only to the
     first (API) step, and runs only `git` and `clang -E` on the sources; it
     runs only for pull requests carrying a label that needs triage rights.
     Residual risk: the preprocessor can `#include` any file readable on the
     runner into the logged diff; the runner is ephemeral.
   - or *retire the workflow*: it serves the comment-translation
     contributors of the upstream project (`bellus869`, `Lemi257`).
   Recommendation: retire it together with `auto-label-author.yml` and
   `pr-squash-guard.yml` unless those contributors work on this repository.
2. **`ilammy/msvc-dev-cmd@v1` is a Node 20 action with no successor.**
   According to the runner's constants (`actions/runner`
   `src/Runner.Common/Constants.cs`), Node 24 became the default on
   2026-06-16 and Node 20 was to be removed on 2026-09-23, so the runner
   most likely runs this action on Node 24 already; whether an annotation
   remains could not be confirmed without a run. If it ever fails: MSBuild
   is found by `setup-msbuild`, so the step can probably be dropped — to be
   tried on a real run.
3. Pre-existing, noticed by the reviewer: the label added by
   `auto-label-author` with `GITHUB_TOKEN` raises no `labeled` event, so the
   guard can skip silently on `opened`; `git fetch --depth=0` in the guard
   is rejected by git and harmless only because the checkout fetched
   everything; `msvc-problem-matcher@master` is an unpinned branch.

## Owed to the maintainer

A real run of each workflow after the branch is merged (`quickstart.md`).
`PRIVACY.md` and `CHANGELOG.md`: no change (no product file changed).

## Decision of 2026-10-02 - fork pull requests in `pr-comments-guard.yml`

The maintainer chose to **opt in**: the checkout step carries
`allow-unsafe-pr-checkout: true`. Why it is acceptable here, and what keeps
it so (also written as a comment at the step):

- the job runs the checkout only after a maintainer put the label
  `comments translation` on the pull request;
- `permissions: contents: read`, `persist-credentials: false`, no secret is
  passed to the steps that touch the checkout;
- the steps come from the workflow file on the base branch; the checked-out
  code is never built or run - it is preprocessed with `clang -E` and the
  results are diffed.

What remains true: `clang -E` reads whatever the pull request's files
`#include`, so a hostile pull request can make the preprocessor read files of
the runner; the runner is a fresh hosted machine and the job has nothing
worth reading beyond the read-only token of the first step, which is not in
the environment of the later steps. Adding a step that executes anything from
the checkout would change this judgement.

Not run: nothing is pushed from this session. The first labelled fork pull
request after the push is the test.

