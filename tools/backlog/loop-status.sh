#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# What the backlog loop does now: running item / waiting and why / paused,
# usage limits, an interrupted run, the run lock, whether Ctrl+C is safe
# (feature 247; logic in loop.py). --json for the data.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python}" -u "$here/loop.py" status "$@"
