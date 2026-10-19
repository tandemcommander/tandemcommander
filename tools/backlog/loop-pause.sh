#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Pause the backlog loop: the running item finishes, then the loop waits
# for loop-resume.sh (feature 247; logic in loop.py).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python}" -u "$here/loop.py" pause "$@"
