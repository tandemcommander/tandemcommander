---
title: release.py plans a feature range from 125 for the release after 0.1.10
type: bug
status: new
severity: 2
area: build-release
source: measure:343
who: agent
created: 2026-10-25
updated: 2026-10-25
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# release.py plans a feature range from 125 for the release after 0.1.10

## Problem

python tools/release/release.py status 0.2.0 on the 343 branch plans the product line of CLAUDE.md and architecture/12-project-reference.md as 'range 124-241 -> 125-343'. 0.1.10 (tag v0.1.10) carried features 124-241, so the next release carries 242-343; the lower bound seems to come from the oldest feature number found since the previous tag (commits of older features merged after it), not from the previous release's upper bound.

## Evidence

fix-log of 343 (Release tooling and records); release.py plan output 'planned: CLAUDE.md:29: product line: ... range 124-241 -> 125-343'.

## Expected

The planned range starts after the previous release's last feature (242), or the tool states how it derived the range so the skill can correct it.

## Log

- 2026-10-25 — created (source measure:343)
