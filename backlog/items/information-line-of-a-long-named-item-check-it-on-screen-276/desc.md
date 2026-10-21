---
title: Information line of a long-named item: check it on screen (276)
type: person-step
status: new
severity: 2
area: panels-ui
source: leftover:276
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [editing-long-named-archive-members-the-rows-the-feature-260]
depends-on: []
reason: -
---

# Information line of a long-named item: check it on screen (276)

## Problem

Feature 276 lets the panel's information line show items with very long names (it said
"Expanded string is too large." before). The probe proves that no box appears and that the line's
pixels change, but the information line exposes no text, so nobody has read what it shows; and a
disk volume without 8.3 short names (the disk case of the same defect) could not be made without
administrator rights.

## Evidence

`specs/276-infoline-long-name/fix-log.md` (*Checks (after)*, *US2*), `quickstart.md` step 5; probe
`specs/276-infoline-long-name/probe/infoline276_probe.ps1` rows ARCCAP / ARCMAX / ARCDEEP LINE
(pixel hash of the line changed) and DISK (the probe volume C: gave the file the 8.3 name
0771~1.TXT, so the disk overflow was not reached).

## Expected

The information line reads correctly for a long-named item; any wrong, garbled or missing part
becomes a new item.

## Steps

- [ ] Make a ZIP with one member named 200 CJK letters + ".txt" (e.g. with the probe's `Zip-Make`, or 7-Zip), open it in Tandem Commander, move the cursor onto the member: no message box; the information line shows the name (as far as the width allows), the size, date, time, attributes and the name again where the short name stands
- [ ] Click the size in the information line (a hot text) and use its context menu copy: the copied text is the size; the same for the name - the whole name is copied
- [ ] On a volume without 8.3 names (`fsutil 8dot3name query X:` says disabled; or `fsutil 8dot3name set X: 1` as an administrator on a test volume), create a file of 250 CJK letters + ".txt" and focus it: no box, the line shows the name twice

## Log

- 2026-10-21 — created (source leftover:276)
