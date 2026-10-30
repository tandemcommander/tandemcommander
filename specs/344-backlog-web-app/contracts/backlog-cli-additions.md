# Contract: additions to `tools/backlog/backlog.py` (feature 344)

Amends `specs/242-backlog-system/contracts/cli.md`. Everything there stays valid: no existing
command, option, output or exit code changes meaning. Standard library only; tests in
`tools/backlog/test_backlog.py`. The amendment note is added to the top of `cli.md` when the
feature closes.

## Global option `--input-json -`

```text
bin/backlog.sh [--root R] --input-json - <command> <slug> [non-text options]
```

The command reads one JSON object from standard input (UTF-8) and takes its **text fields**
from it instead of from the command line. Allowed keys per command:

| Command | Keys |
|---|---|
| `new` | `title`, `problem`, `evidence`, `expected`, `approach`, `notes`, `question`, `options`, `recommendation`, `steps` |
| `set` | `title`, `log` (the other fields stay `key=value` on the command line: they are legend values, dates, slugs) |
| `log` | `text` |
| `verify` | `note` |
| `move`, `block`, `remove` | `reason` |
| `unblock` | `note` |
| `body`, `decide`, `step` | see below |

Rules: a key given both in JSON and on the command line is refused (`refused: <key> given
twice`); an unknown key is refused; a value must be a string; one-line fields keep their
one-line rule (`title`, `reason`, `note`, `log`, `text`). No length limit beyond the tool's own
rules. Nothing is written when the JSON is invalid (exit 2, `usage: invalid JSON on stdin`).

## Global option `--json` for changing commands

With `--json`, every changing command prints exactly one JSON object on stdout and nothing
else:

```json
{"ok": true, "refused": null, "slugs": ["a-slug"], "section": "Next", "position": 11,
 "notices": ["moved to 'Person steps' (type / who changed)"],
 "findings": [{"path": "backlog/items/x/desc.md", "line": 3, "rule": "ref", "message": "..."}],
 "written": ["backlog/items/a-slug/desc.md", "backlog/BACKLOG.md"]}
```

`refused` is the refusal text (then `ok: false`, `written: []`, exit 1); `findings` non-empty
with `ok: true` means *written, check found problems* (exit 1, never retry). `written` lists
every file the command wrote or deleted (relative to the root), so the caller can snapshot and
undo.

## Global option `--ref REF` for read commands

`board`, `list`, `show`, `next` and `legend` accept `--ref REF` (e.g. `main`): they read
`backlog/` from the git objects of REF (`git ls-tree`, `git cat-file --batch`) and open no file
of the working tree. Changing commands and `check` refuse `--ref` (exit 2).

## New read commands

| Command | Output |
|---|---|
| `board --json [--with-body] [--ref R]` | `{"revision", "last_triaged", "sections": [{"name", "ordered", "rows": [{"position", "slug", "title", <header fields>} \| {"note": text}]}], "unreadable": [{"slug", "path", "finding"}]}`. `revision` = SHA-256 of `BACKLOG.md` bytes as read. `--with-body` adds `body` (the raw Markdown after the header) and `issue` (the text of `issue.md`, if any) to each item row. Severity is an integer. |
| `show <slug> --json [--ref R]` | One item: `revision` (SHA-256 of `desc.md`), every header field (severity integer, lists as arrays, `-` as null), `section`, `position`, `body`: `[{"name", "markdown"}]` in file order, `log`: `[{"date", "text"}]`, `steps`: `[{"index", "done", "text"}]`, `options`: `[{"key", "text"}]` (from `### A` / `- **A**` forms of *Options*), `files`: `{"issue": {"number", "head"} \| null, "reply": {"state"} \| null, "evidence": [names]}`, `dependents`: slugs, `findings`: the item's own check findings, `eligibility`: `{"eligible", "reason"}`. Unknown slug: exit 1, `refused: no item '<slug>'`. |
| `check --json` | `{"total": n, "findings": [{"path", "line", "rule", "message"}]}`; exit 1 iff total > 0 (as `check`). |
| `legend --json [--ref R]` | `{"types": [{"value", "meaning"}], "statuses": [...], "areas": [...], "who": [...], "efforts": [...], "sources": [{"form", "meaning"}], "severity": [{"range", "meaning"}]}` from the legend tables of `BACKLOG.md`. |

## New changing commands

All follow the *Writing* rules of `cli.md` (validate first, write each file once atomically,
`BACKLOG.md` last, full check) and accept `--json` and `--input-json -`.

| Command | Behaviour |
|---|---|
| `reorder --section S` (stdin: `{"order": [slug, ...]}`) | S is one of the four ordered sections. The list must contain exactly the item rows of S (same set; note rows keep their place relative to the item before them). Rewrites the order in one write; **no item log line**; sets *Last triaged* to today. Refuses a different set (`refused: the order must name exactly the rows of '<S>'`). |
| `body <slug> --section NAME` (stdin: `{"markdown": text}` or `{"remove": true}`) | Replaces the body section NAME (one of the ten), adds it at its fixed place when absent, or removes it (only optional sections: *Approach*, *Notes*; and for non-decision / non-person-step items *Question*, *Options*, *Recommendation*, *Steps*). *Log* is refused (use `log`). The result must pass the `body` rule before anything is written. Sets `updated`; appends a log line (stdin key `log`, default `edited <section>`). |
| `step <slug> <n> --done \| --undone` (stdin optional: `{"note": text}`) | Ticks or unticks the n-th checklist line (1-based) of *Steps*; appends the log line `step <n> done: <note>` / `step <n> reopened: <note>`. Refused when the item has no step n. |
| `decide <slug> --option KEY --then ACTION` (stdin: `{"decision": text}`) | Decision items only. Appends `maintainer decision YYYY-MM-DD: option KEY - <decision>` to *Log*, then applies ACTION in the same write: `move:<Section>[@N]` (after `--type` change if given), `set-type:<type>[,who:<who>]` (the item becomes work; the row goes to the fitting section at `@N` if given, else its end), `park` (reason = the decision), `close` (removes the item with the decision as reason), `keep` (only the log line). Optional `--type T`. |
| `reply <slug> --state not-sent \| sent` | Sets the `state:` line of `reply.md` (GitHub-imported items); log `reply marked <state>`. Refused without `reply.md`. |

## Changed option

| Command | Addition |
|---|---|
| `set <slug> ... --position N` | When the change of `type` / `who` moves the row to another section, place it at position N there (default: the end, as today). Without a section change `--position` is refused (use `move`). |

## Exit codes and output

Unchanged: `0` success, `1` refused or check findings, `2` usage. Without `--json`, the new
commands print text in the style of the existing ones (`reorder`: `reordered '<S>': n rows`).
