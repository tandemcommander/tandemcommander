#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# The backlog loop from Git Bash: bin/backlog-loop.sh start|pause|resume|stop|status
# (features 247, 342; logic in tools/backlog/loop.py). The backlog itself is
# bin/backlog.sh. Every script in bin/ answers --help.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
loop="$here/../tools/backlog/loop.py"

usage() {
    cat <<'EOF'
Usage: bin/backlog-loop.sh <command> [options]
       bin/backlog-loop.sh <command> --help    the options of one command
       bin/backlog-loop.sh --help              this text

Runs /tandem-backlog-implement item after item, one fresh claude process per
item, and controls that loop from another window (feature 247). Each run
leaves its trace in .agent-traces/ (feature 342). The backlog itself (list,
next, check, new, move, ...) is bin/backlog.sh.

Commands:
  start    run the loop in this window until it is stopped; Ctrl+C here is a
           hard stop (kills the running item, the next start continues it)
  pause    the running item finishes, then the loop waits for resume
  resume   continue after a pause; also cancels a pending stop
  stop     the running item finishes, then the loop ends
  status   what the loop does now: the running item, waiting and why, usage
           limits, an interrupted run, its trace and the size of all traces,
           the run lock, whether Ctrl+C is safe

Options of start:
  --max-items N      end after N finished items (default: no limit)
  --max-blocked N    stop after N blocked runs in a row (default 3)
  --poll SECONDS     how often a waiting loop looks at the backlog (default 60)
  --model M          the model of the runs (default: claude's own default)
  --until-idle       end when nothing is eligible instead of waiting
  --forget-run       drop the record of an interrupted run before starting
  --auto-triage      before each run, place new Inbox items with
                     '/tandem-backlog auto-triage --commit'
Options of status:
  --json             the data as JSON
Every command:
  --root DIR         another repository (default: this one)

Environment: PYTHON - the Python to run (default: python).
Exit: start 0 ended as asked, 1 stopped for a person or refused, 2 usage,
130 Ctrl+C; the other commands 0 (2 usage).
Full documentation: specs/247-backlog-run-loop/contracts/loop-cli.md,
traces: specs/342-backlog-agent-traces/contracts/traces.md

Examples:
  bin/backlog-loop.sh start --auto-triage
  bin/backlog-loop.sh pause
  bin/backlog-loop.sh status
EOF
}

case "${1-}" in
    -h | --help | help)
        usage
        exit 0
        ;;
    start | pause | resume | stop | status)
        exec "${PYTHON:-python}" -u "$loop" "$@"
        ;;
    "")
        usage >&2
        exit 2
        ;;
    *)
        echo "bin/backlog-loop.sh: unknown command '$1' (start, pause, resume, stop, status; --help)" >&2
        exit 2
        ;;
esac
