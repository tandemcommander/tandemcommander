---
title: A single mask longer than 259 bytes overruns the mask group preparation buffers
type: bug
status: new
severity: 6
area: long-paths
source: review:283
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [masks-cut-recycle-bin-find-viewer-compare]
depends-on: []
reason: -
---

# A single mask longer than 259 bytes overruns the mask group preparation buffers

## Problem

`CMaskGroup::PrepareMasks` copies one mask of the group (the text between two `;`) into a stack
buffer `char maskBuf[MAX_PATH]` without a length bound, then `PrepareMask` copies it again into
`char buf[MAX_PATH]`. The group's string holds up to `MAX_GROUPMASK` (1001) bytes, so a single
mask of 260 bytes or more writes past both buffers (a stack overrun - a crash, or worse). Dialog
fields cap a typed mask at 259 units and features 251 / 270 refuse what does not fit, but masks can
also come from the registry (a hand edit, a settings import), from plug-ins
(`CreateSalamanderMaskGroup`, thumbnail masks) and from 3-byte UTF-8 letters typed into fields
whose read is not bounded in bytes.

## Evidence

Review 1 of feature 283 (NOTE 5, `specs/283-mask-code-page-fold/fix-log.md` *Review*), by reading
at 50d7ba68: `src/masks.cpp` `CMaskGroup::PrepareMasks` - `char buf[MAX_PATH]; char maskBuf[MAX_PATH];`
and the copy loop `*mask++ = *s++;` bounded only by the separators; `PrepareMask(buf, mask)`
unbounded likewise. `CMaskGroup::MasksString[MAX_GROUPMASK]` (`src/masks.h`), `MAX_GROUPMASK`
1001. Possible sources named by the reviewer: the tab filter (`SAL_TAB_FILTER_MAX`), the criteria
`NAMEMASKS` value loaded from the registry, plug-in supplied masks. Not reproduced.

## Expected

A mask longer than the preparation buffers never overruns them: `PrepareMasks` refuses the group
(returns FALSE with the error position, as for a syntax error) or uses a buffer sized to the mask -
never cuts the mask silently (a cut mask matches other files). saltests over the rule; a probe or
unit reproduction of a 300-byte single mask before the fix.

## Notes

Not verified: which of the named sources can really deliver a single mask of 260+ bytes at HEAD
(measure first - registry loading may already cap the string). Severity is the lower end because
the reach is unproven; a reachable stack overrun would be 7-8.

## Log

- 2026-10-21 — created (source review:283)
