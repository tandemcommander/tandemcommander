# Contract: skill `/tandem-release`

Files: `.claude/skills/tandem-release/SKILL.md` (procedure) and
`reference.md` (records, formats, traps, maintainer steps).

## Front matter

```yaml
name: "tandem-release"
description: "Prepare the Tandem Commander repository so that version <x.y.z> is released today: … Never builds, signs, tags, pushes or publishes."
argument-hint: "<x.y.z> [--date YYYY-MM-DD] [--dry-run]"
compatibility: "Requires tools/release/release.py, Python, backlog/ (features 242, 243)"
user-invocable: true
disable-model-invocation: true
```

## Arguments

Exactly one version (mandatory); optional `--date`, `--dry-run`. Anything
else → stop with the usage line. The maintainer may write in Czech; the
repository text is English.

## Steps (each may end the run; "stop" = nothing changed)

| # | Step | Ends the run when |
|---|------|-------------------|
| 1 | `release.py status <ver>` | any `refused:` line → report it, stop |
| 2 | Questions, one at a time, only when needed: branch ≠ `main` (FR-004); MINORB skipped; remote tag unknown; open gating steps (FR-004a, with candidates); an open backlog decision about this release's content (FR-018) | a "no" → stop |
| 3 | `--dry-run`: `release.py stamp <ver> --dry-run`, report, end | always ends here |
| 4 | Content review (FR-016, FR-017): `git log v<P>..HEAD`, the changelog section, FEATURE-HISTORY entries of the features, fix-log drafts, privacy triggers | a privacy trigger not reflected in `PRIVACY.md` → ask; "no"/unclear → stop |
| 5 | `release.py stamp <ver>` | exit 1 → report, stop (tree unchanged) |
| 6 | Wording: changelog lead (+ dropped leads merged), build-history summary, privacy sentence, release notes, `CLAUDE.md` *Status*, `RELEASE.md` *Current release* | — |
| 7 | `release.py check <ver>`, `release.py summary <ver>`, `python tools/check_encoding.py --strict` | findings the skill cannot fix by repeating step 6 → report and stop without a commit; the edits stay in the work tree for the maintainer (never a destructive reset) |
| 8 | Backlog: record the confirmed decision (`/tandem-backlog decide`), new findings to *Inbox* | — |
| 9 | One commit `Version <ver>: the tree prepared for the release (<D>)`, body from a file | commit fails → report |
| 10 | Final report (FR-022) | — |

## Never

Build, test, sign, build an installer, tag, push, publish, submit to winget,
change another backlog item than the confirmed decision, rewrite history
(older changelog sections, published release notes, recorded manifests),
`reset --hard`, `checkout -f`, `clean`, put repository text on a command line
inside double quotes.

## Final report

```text
Prepared: Tandem Commander <ver> (build <N>), release date <D>, commit <hash> on <branch>.
Changed: <record list with one line each>
Verified: release.py check 0 findings; check_encoding TOTAL 0; winget summary <n> chars.
Gating person steps: <list or none> (confirmed by the maintainer)
Warnings: <list or none>
Maintainer's steps:
 1. build.cmd full release sign setup  (check OPENSAL_BUILD_DIR / build\)
 2. git tag v<ver> <commit>; push the branch and the tag
 3. switch the "Publish to winget" workflow OFF while microsoft/winget-pkgs#426090 is open (check it in the Actions tab)
 4. GitHub release v<ver>: body = release_notes/release_notes_v<ver>.md, asset tandemcommander-<ver>-x64-setup.exe, not draft, not prerelease
 5. after publishing: RELEASE.md "After publishing"
Released on another day? Run /tandem-release <ver> again that day.
```
