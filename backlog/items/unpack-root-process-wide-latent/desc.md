---
title: Unpack short-name walk: process-wide root; external archiver's unpack not driven
type: tech-debt
status: open
severity: 2
area: archives
source: review:204
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Unpack short-name walk: process-wide root; external archiver's unpack not driven

## Problem

Feature 204 keeps an archive's folder that is only another folder's 8.3 short name from being unpacked into that other folder, by a walk under the unpack root. Left by its review, latent: (1) the root is process-wide, so a create under it from elsewhere during an unpack is walked too (with a target `C:\` or `C:\Users` and a `%TEMP%` in short form a plug-in's temporary file would have made the walk try to move the real profile folder aside - mitigated: the walk starts below the temporary folder when the path lies in it; other creates under the root during an unpack: none found in the tree); (2) an external archiver's unpack (`PackUniversalUncompress` -> `MoveFiles`) relies on 201 / 203 and was not driven.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 11 (L301) (at 7993914c). specs/204-unpack-short-name-folder/fix-log.md, *Review* (point 3 and the NITs: "the root is process-wide", "an external archiver's unpack ... not driven"; also recorded: the walk splits on `\` only, fail-open on low memory).

## Expected

The walk applies only to creates of the unpack that set it (e.g. a per-thread or per-operation root), and an external archiver's unpack next to a short-name twin is measured.

## Approach

Measure (2) with the external archivers 084 kept (7-Zip, RAR) if one is installed on the agent's machine; otherwise a person step.

## Notes

Latent - no reachable loss known after the mitigation.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
