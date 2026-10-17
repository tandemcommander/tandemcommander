---
title: PE Viewer: write the dump as UTF-8 with a BOM?
type: decision
status: open
severity: 2
area: other-plugins
source: leftover:131
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: -
feature: -
related: [peviewer-version-names-narrow-ls]
depends-on: []
reason: -
---

# PE Viewer: write the dump as UTF-8 with a BOM?

## Problem

Letters outside the system code page are `?` in the PE Viewer dump (e.g. a Japanese `FileDescription` on a Czech system, such keys and assembly names). Showing them needs the whole dump in UTF-8 with a BOM - about 50 lines, but it changes the format of the dump (what Save As from the viewer writes, the coding the viewer shows in its title).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L772-773. The complete solution is described in `specs/131-plugin-defect-batch/items/peviewer.md`, *The complete solution (not done - a decision for the maintainer)*: write `EF BB BF` first in `DumpFileInfo`, convert in `CFileStream::fprintf` (all 153 output calls go through it), a direct wide -> UTF-8 route for `W2A` users, `dump_res.cpp` `GetName` and the three inserts.

## Expected

(not stated in the source)

## Question

Should the PE Viewer dump become UTF-8 with a BOM (exact letters, a changed dump format) or stay code page (`?` for letters outside it)?

## Options

- A - keep the code-page dump; letters outside the code page stay `?`.
- B - UTF-8 with a BOM, about 50 lines in `DumpFileInfo` / `CFileStream::fprintf`; raw bytes from the viewed file are still read as code-page text; the saved dump's format changes.

## Recommendation

B - small, contained to one plug-in's output; the format change affects only a viewer dump. The source states no preference.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
