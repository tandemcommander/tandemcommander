#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Resume the backlog loop after loop-pause.sh; also cancels a pending
# loop-stop.sh (feature 247; logic in loop.py).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python}" -u "$here/loop.py" resume "$@"
