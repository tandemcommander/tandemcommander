#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Starts the backlog web app (feature 344; tools/backlog-app/): installs its
# dependencies when needed, builds the web client when its sources changed, and
# runs the server on 127.0.0.1. Every script in bin/ answers --help.
# Contract: specs/344-backlog-web-app/contracts/launcher.md
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app="$here/../tools/backlog-app"
repo="$(cd "$here/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: bin/start-backlog-app.sh [--dev] [--port N] [--no-open] [--root DIR]
       bin/start-backlog-app.sh --help    this text

Starts the backlog web app (feature 344): view, filter and query the backlog,
watch the item the loop implements right now and control the loop, reorder,
triage and edit items - all through bin/backlog.sh and bin/backlog-loop.sh.
The app listens on 127.0.0.1 only and opens itself in the default browser
with a one-time start code; Ctrl+C stops the app, never a running loop.

Options:
  --dev        development mode: live reload of the web client, no build
  --port N     listen on port N (default 47321)
  --no-open    do not open the browser, only print the address
  --root DIR   another repository (tests); default: this one

The first start installs the dependencies (npm ci) and builds the client;
later starts take a few seconds. Needs Node.js 24.15 or newer and Python.
Exit: 0 ended as asked, 1 a precondition failed, 2 usage.
Documentation: tools/backlog-app/README.md,
specs/344-backlog-web-app/contracts/launcher.md
EOF
}

dev=0
open=1
port=""
root="$repo"
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help | help)
            usage
            exit 0
            ;;
        --dev)
            dev=1
            ;;
        --no-open)
            open=0
            ;;
        --port)
            if [ $# -lt 2 ]; then
                usage >&2
                exit 2
            fi
            port="$2"
            shift
            ;;
        --root)
            if [ $# -lt 2 ]; then
                usage >&2
                exit 2
            fi
            root="$2"
            shift
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ -n "$port" ]; then
    case "$port" in
        '' | *[!0-9]*)
            echo "--port takes a number" >&2
            exit 2
            ;;
    esac
fi

# 1. Node.js 24.15 or newer (26.x allowed): native TypeScript type stripping.
if ! command -v node >/dev/null 2>&1; then
    echo "the backlog app needs Node.js 24.15 or newer (found: none) - install it from https://nodejs.org or with: winget install OpenJS.NodeJS.LTS" >&2
    exit 1
fi
version="$(node -p 'process.versions.node' 2>/dev/null)"
major="${version%%.*}"
rest="${version#*.}"
minor="${rest%%.*}"
if [ -z "$major" ] || [ "$major" -lt 24 ] 2>/dev/null || { [ "$major" -eq 24 ] && [ "$minor" -lt 15 ]; } || [ "$major" -eq 25 ]; then
    echo "the backlog app needs Node.js 24.15 or newer, or 26.x (found: ${version:-unknown}) - install it from https://nodejs.org or with: winget install OpenJS.NodeJS.LTS" >&2
    exit 1
fi

cd "$app" || exit 1

# 2. Dependencies: npm ci when node_modules is missing or the lock file changed.
lock_hash="$(sha256sum package-lock.json | cut -d' ' -f1)"
stamp="node_modules/.backlog-app-lock.sha256"
if [ ! -d node_modules ] || [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$lock_hash" ]; then
    echo "Installing the dependencies (npm ci)..."
    if ! npm ci --no-audit --no-fund; then
        echo "npm ci failed - see the output above" >&2
        exit 1
    fi
    printf '%s\n' "$lock_hash" >"$stamp"
fi

# 3. Build the web client when its sources changed (not in development mode).
if [ "$dev" -eq 0 ]; then
    source_hash="$(find packages/web/src packages/web/public packages/shared/src packages/web/index.html \
        packages/web/vite.config.ts package-lock.json -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
    built="packages/web/dist/.source.sha256"
    if [ ! -f packages/web/dist/index.html ] || [ ! -f "$built" ] || [ "$(cat "$built")" != "$source_hash" ]; then
        echo "Building the web client..."
        if ! npm run build --silent; then
            echo "the build failed - see the output above" >&2
            exit 1
        fi
        printf '%s\n' "$source_hash" >"$built"
    fi
fi

# 4. The server. exec: Ctrl+C reaches Node directly.
args=(packages/server/src/main.ts --root "$root")
[ "$dev" -eq 1 ] && args+=(--dev)
[ "$open" -eq 0 ] && args+=(--no-open)
[ -n "$port" ] && args+=(--port "$port")
if [ "$dev" -eq 1 ]; then
    exec node --watch-path=packages/server/src --watch-path=packages/shared/src "${args[@]}"
fi
exec node "${args[@]}"
