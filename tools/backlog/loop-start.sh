#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Run the backlog loop in this window: /tandem-backlog-implement item after
# item, one fresh claude process each (feature 247; logic in loop.py).
#   loop-pause.sh / loop-resume.sh / loop-stop.sh / loop-status.sh from another window.
#   Ctrl+C here = hard stop (kills the running item; the next start continues it).
#   --auto-triage: before each run, new Inbox items are placed by '/tandem-backlog auto-triage'.
# Options: --max-items N  --max-blocked N  --poll SECONDS  --model M  --until-idle  --forget-run
#          --auto-triage  --help
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python}" -u "$here/loop.py" start "$@"
