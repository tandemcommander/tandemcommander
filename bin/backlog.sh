#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# The backlog from Git Bash: bin/backlog.sh <command> (features 242, 342; logic in
# tools/backlog/backlog.py). The loop is bin/backlog-loop.sh. Every script in bin/
# answers --help.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$here/../tools/backlog/backlog.py"
export TANDEM_BACKLOG_PROG=bin/backlog.sh

usage() {
    cat <<'EOF'
Usage: bin/backlog.sh [--root DIR] <command> [options]
       bin/backlog.sh <command> --help    the options of one command
       bin/backlog.sh --help              this text

Checks, lists and changes the backlog in backlog/ (feature 242): the
overview BACKLOG.md, the items in backlog/items/<slug>/desc.md and the run
journal RUNS.md. Manage it with /tandem-backlog; the skills run this script.
The loop that implements item after item is bin/backlog-loop.sh.

Environment: PYTHON - the Python to run (default: python).
Exit: 0 done / no findings, 1 findings or refused (refused: nothing written),
2 usage.
Full documentation: specs/242-backlog-system/contracts/cli.md,
specs/342-backlog-agent-traces/contracts/bin-commands.md

Examples:
  bin/backlog.sh next
  bin/backlog.sh list --section next
  bin/backlog.sh list --section inbox --json
  bin/backlog.sh check

The commands of the tool:
EOF
    "${PYTHON:-python}" "$tool" --help
}

case "${1-}" in
    -h | --help | help)
        usage
        exit 0
        ;;
    "")
        usage >&2
        exit 2
        ;;
    *)
        exec "${PYTHON:-python}" "$tool" "$@"
        ;;
esac
