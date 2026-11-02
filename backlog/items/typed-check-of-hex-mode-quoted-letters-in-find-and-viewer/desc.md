---
title: Typed check of hex-mode quoted letters in Find and viewer Find (feature 397)
type: person-step
status: new
severity: 3
area: encoding
source: leftover:397
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: [typed-check-of-the-find-containing-and-viewer-find-refusals]
depends-on: []
reason: -
---

# Typed check of hex-mode quoted letters in Find and viewer Find (feature 397)

## Problem

Feature 397 makes the hex-mode tidying of Find's Containing field and the viewer's Find field keep
quoted letters outside the code page (they became `?` at the first typed key). The hidden-desktop
probe types by `WM_CHAR` sent to the field's edit; typing with a real keyboard and with an IME
(Chinese / Japanese composition, while the field is rewritten after every change as before 397)
was not driven.

## Evidence

`specs/397-hex-find-quoted/fix-log.md` (*Review*, NOTE 4); probe
`specs/397-hex-find-quoted/probe/hex397_probe.ps1` (rows grep-type, grep-mid, view-type, grep-group:
8 PASS / 0 FAIL after, 3 FAIL before). Related: the 311 typed check of the same fields
(`typed-check-of-the-find-containing-and-viewer-find-refusals`).

## Expected

Typed text behaves as the probe shows: quoted letters stay as typed, the caret stays where the user
types, the search finds the letters' UTF-8 bytes.

## Steps

- [ ] Prepare a UTF-8 file `hit.txt` holding `x中文字A` and a file `miss.txt` holding `???A`
- [ ] Find (Alt+F7), "Search file content" and "Hex" on, type with a Chinese IME `"中文字"` and then `41` in Containing: the field shows `"中文字" 41` (no `?`), the caret stays at the end while typing; Find finds `hit.txt` only
- [ ] In the same field put the caret between `文` and `字` and type `a`: the field shows `"中文a字" 41`, the caret right after `a`
- [ ] Open `hit.txt` in the internal viewer (Alt+F3), F7 (Find), "Hex" on, type `"中文字" 41` with the IME, Enter: the viewer selects the found text (no "Cannot find")
- [ ] Type plain `41424` in hex mode: the field becomes `41 42 4` as before

## Log

- 2026-11-02 — created (source leftover:397)
