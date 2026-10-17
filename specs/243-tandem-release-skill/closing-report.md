# Closing report — 243 tandem-release skill

**Branch**: `243-tandem-release-skill` (from `main` at `c3319ffa`) ·
**Date**: 2026-10-17 · **State**: implemented and committed on the feature
branch; not merged, nothing pushed.

## What changed

- **`tools/release/release.py`** — standard-library CLI (`status`, `stamp`,
  `check`, `summary`; contracts/cli.md). The release state is derived from
  local and remote tags, `spl_vers.h` and `CHANGELOG.md`; the build is the
  previous tag's build + 1; `stamp` sets the eight release records and is
  idempotent; `check` has 24 rules; `summary` reproduces `publish.ps1`'s
  winget summary exactly. Tests `test_release.py` (44) on a miniature
  repository in `fixtures/repo`.
- **Skill `/tandem-release <x.y.z>`** (`.claude/skills/tandem-release/`:
  `SKILL.md` steps 1–10, `reference.md` records, wording rules, release
  notes format, privacy triggers, traps, the maintainer's steps).
  `disable-model-invocation: true`: only the maintainer starts it.
- **Records of the procedure** — `backlog/RELEASE.md`: *Release records*
  (the one list), *Preparing the tree* (closing pass, then the skill),
  "another day = run the skill again", SHA-256/VirusTotal step removed,
  closing-pass commit `8e5d6c8a`, `Gating person steps:` list in *Current
  release*. Constitution 3.1.0 → 3.2.0 (*Release Documentation*: groups
  optional, lead `**Build N.** <Kind> release.` required for released
  sections, the record list moved to `RELEASE.md`). `CLAUDE.md`: a *Where
  things are* row, the *Product identity* bullet points to the record list,
  constitution v3.2.0 (was stated v3.0.0), one standing-rule sentence (243).
- **Backlog** — two *Inbox* items (source `review:243`):
  `unshipped-resources-still-carry-2023-open-salamander-only`,
  `winget-readme-names-a-publish-ps1-check-that-does-not-exist`.
- `specs/FEATURE-HISTORY.md` entry 243 and index rows.

## Verification

| Check | Result |
|-------|--------|
| `python -m unittest tools/release/test_release.py` | 44 tests OK |
| winget replica vs `tools/winget/manifests/0.1.9/…locale.en-US.yaml` | identical; negative control (wrap 75) fails |
| Quickstart V2/V3 on the real tree | refusals as specified; dry run lists the fold and 6 date moves in 5 files; tree unchanged |
| Quickstart V4/V5 on a throw-away worktree | dirty tree refused; stamp → check 1 (lead) → lead written → check 0, `check_encoding` 0, commit, second stamp `unchanged`, next-day dry run = only the date moves |
| `python tools/backlog/backlog.py check` | TOTAL 0 |
| `python tools/check_encoding.py --strict` | TOTAL 0 |
| Refute-first review (independent agent) | 9 findings (4 medium, 5 low), all fixed (fix-log *Review*) |

## Not done / owed

- The real preparation of 0.1.10 is the maintainer's run of
  `/tandem-release 0.1.10` on `main`. Releasing from `main` means features
  124–241 (option C of `post-142-fixes-joining-0-1-10-decision`); the run
  asks to record that decision. The skill will then have to extend the
  0.1.10 release notes, the build-194 history entry, *Status* and *Current
  release* to 143–241 (today they describe 124–142) — `check 0.1.10` on the
  current tree lists the mechanical part (10 findings).
- The full skill dialogue (questions, wording of a large release) has not
  been run end to end by a person; the first real run is its validation.
- Known limitation: the winget summary length is counted in code points,
  `publish.ps1` counts UTF-16 units (differs only for characters outside
  the BMP).
