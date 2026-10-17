# Contract: skills `tandem-backlog` and `tandem-backlog-implement`

Both live in `.claude/skills/<name>/` in the format of the Spec Kit skills
(front matter `name`, `description`, `argument-hint`, `user-invocable: true`,
`disable-model-invocation: false`). Both accept Czech or English
instructions and write backlog files in English. Every mechanical change
goes through `tools/backlog/backlog.py` (`contracts/cli.md`); the skills add
judgement (wording, grouping, field choice), never bypass the tool. **The
step-by-step procedures are in the skills themselves** (`SKILL.md`,
`reference.md`, `stop-rules.md`); this contract states what they guarantee.

## `/tandem-backlog <operation> [arguments]`

Files: `SKILL.md` (modes, operations with exact steps and commands, report
formats), `reference.md` (§1 templates, §2 writing rules, §3 decision tables
for type / area / severity / who / effort / source, §4 triage guidance, §5
sections and statuses, §6 findings and refusals → fix).

Operations: `add`, `import-github`, `list`, `show`, `triage`, `move`,
`update`, `verify`, `decide`, `park`, `reject`, `reopen`, `block`,
`unblock`, `close`, `check` — each with exact steps, commands and a fixed
report line. A decision that is answered is closed (`remove --reason`),
not rejected; rejecting an item first resolves its dependents
(`list --needs`).

Guarantees:

1. **Modes** (FR-014). *Maintainer mode* — the maintainer asked for the
   operation in this conversation: everything is allowed. *Agent mode* —
   anything else: only `add`, `import-github`, `list`, `show`, `verify`
   (the `verified` stamp and a log line), `log`, `check`; an agent changes
   no other item's fields or body (a related finding is a new item with
   `--related`), never moves, reorders, parks, rejects, reopens, unblocks,
   closes or decides.
2. Nothing under `specs/` is created or changed (FR-001).
3. Every operation ends with `check` → `TOTAL: 0` and a report in a fixed
   format.
4. Texts with backslashes (UNC paths, `\\?\`) never pass the command line;
   they are written with the editor into the body (measured: the Bash
   tool collapses `\\`).
5. One changing command at a time (the tool has no lock of its own).

## `/tandem-backlog-implement [<slug>] [--dry-run]`

Files: `SKILL.md` (steps 0–11), `stop-rules.md` (§1 which questions a run
answers and how, §2 the project rules of a run, §3 stop conditions).

Guarantees:

1. Exactly one item per run, then the run ends (FR-030).
2. Preconditions change nothing when they fail: current branch `main`,
   clean tree, `check` → 0; the lock state is reported first, so a second
   run sees "another run in progress (holder)" (FR-039).
3. Selection by `next` (FR-031); `--dry-run` reports the selection, the
   skipped rows and what the run would check, then ends without any change
   or lock.
4. Measure first at HEAD on `main` before a feature exists (FR-032); not
   reproduced → the item is `blocked` with "not reproduced at <commit>",
   journal row, one commit on `main`.
5. The branch name is computed first (`create-new-feature.sh --dry-run`);
   `speckit-specify` gets the item as input (written to a file, never on a
   command line — item text holds backticks and `$`), with
   `GIT_BRANCH_NAME` and `SPECIFY_FEATURE_DIRECTORY: specs/<BRANCH_NAME>`,
   so branch and folder agree also when unmerged branches of stopped runs
   exist; the hook gets only `'Backlog item <slug>'` as description; then
   checks, `start` and `lock update --branch`.
6. `clarify` answered by the run itself by `stop-rules.md` §1; a
   maintainer-owned question stops the run with a `decision` item (FR-034).
7. `plan`, `tasks`, `analyze` (CRITICAL / HIGH fixed), `implement` under the
   project rules (FR-035); the Spec Kit commit hooks run as configured;
   out-of-scope findings become *Inbox* items.
8. Independent refute-first review; MUST findings fixed; a second rejection
   stops the run.
9. Success: `remove --feature`, leftovers as *Inbox* items,
   `FEATURE-HISTORY.md` entry naming the item, `CHANGELOG.md` when
   user-visible, `closing-report.md`, journal row `closed`, commit
   `[NNN] …`, `git merge --ff-only` into local `main` (FR-035a, FR-037).
10. Stop: work in progress committed on the branch; on `main` the item
    `blocked` with reason and feature number, the items recorded on the
    branch during the run copied to `main` (*Inbox*), the decision /
    person-step / split items added, journal row, commit (FR-036); a stop
   before a branch exists leaves `main` clean (anything specify wrote is
   removed). A `github#N` item's reply draft is kept in the feature folder
   and the answer is owed to a person.
    A failed fast-forward is a stop whose reason tells the maintainer how
    to merge (keep the branch's removal of the item, both journal rows).
11. Every path releases the lock it acquired and ends on `main` with the
    final message of a fixed format; nothing is pushed, tagged or published.
12. Journal rows (FR-038): every run that acquired the lock writes one;
    runs that end at a failed precondition, a held lock or an ineligible
    `--slug` change nothing and write none (they report in the final
    message).
