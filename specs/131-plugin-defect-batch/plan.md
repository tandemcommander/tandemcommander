# Implementation Plan: defect batch of feature 131

**Branch**: `131-plugin-defect-batch` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

About twenty notes of feature 130, seen by reading. Each is measured first, then fixed
minimally or recorded as unreachable / no defect. Work split by directory (four agents in
parallel, no build, no GUI; the core and the translations by the session itself), then one
build, unit checks, probes, three independent reviews.

## Technical Context

- Plug-ins: `pictview`, `diskmap`, `peviewer`, `sftp`, `ftp`, `filecomp`, `regedt`, `zip`, `7zip`,
  `undelete`, `renamer`. Core: `src/salamdr3.cpp` (`CheckAndCreateDirectory` error text),
  `src/plugins3.cpp` (`SetSubjectTruncatedText`). Translations: `translations/spanish/7zip.slt`,
  seven `sftp.slt`, `translations/ui-overrides.json`.
- Rules: `agent-brief.md` (a path is never cut; refuse fails closed; no new strings; measure
  with own test programs outside the repository).
- Tests: the agents' own test programs (`probe/pictview-diskmap-peviewer/`, results quoted in
  `items/*.md`), the SFTP unit harness (`src/plugins/sftp/test/`, 85 checks), `saltests`,
  `probe/batch131_probe.ps1` (FTP `%` host), the probe of 130 in Spanish, regression probes.

## Constitution Check

- Backward compatibility: stored favourite names and hand-written `.set` files still load; no
  registry format change; plug-in ABI untouched.
- Never lose the user's data: every refusal fails closed (checked by the reviews: a move does
  not delete after a refused item).
- No new UI strings (existing "too long" / status texts reused).

## Structure

1. Brief + four parallel work packages, a record per plug-in in `items/`.
2. Core and translation changes.
3. Build, unit checks, probes on the new build and on 0.1.9.
4. Three reviews (SFTP; ZIP / 7-Zip / Undelete / Renamer; viewers / FTP / core / translation),
   fixes, final builds and runs, records.
