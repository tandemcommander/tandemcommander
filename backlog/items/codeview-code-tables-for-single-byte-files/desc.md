---
title: Code Viewer reads single-byte files only in the system code page (no CP852 etc.)
type: feature
status: open
severity: 4
area: other-plugins
source: review:070
who: agent
created: 2026-08-27
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: L
feature: -
related: []
depends-on: []
reason: -
---

# Code Viewer reads single-byte files only in the system code page (no CP852 etc.)

## Problem

The Code Viewer (codeview plug-in, the default for F3 on source and text files) decodes a file without a BOM that is not UTF-8 with `CP_ACP` only. The product's conversion tables - the `EnumConversionTables` machinery the built-in viewer uses for ISO-8859-2, CP852, Kamenicky, KOI-8 and the others - are not wired in, and the F8 encoding menu is a fixed list of five encodings. A single-byte file in another code page than the system's (e.g. a DOS CP852 or an ISO-8859-2 text on a CP1250 machine) therefore shows wrong letters, and the user cannot choose the right table in the Code Viewer; the workaround is the built-in viewer. The 070 stabilization review called it "the single largest remaining gap against the spec" (FR-024).

## Evidence

specs/070-source-viewer-plugin/stabilization-review.md: finding F16 (table row ~L62: "The ANSI decode path is hardwired to `CP_ACP`; the code-table machinery FR-024 calls for (ISO-8859-2, CP852, ...) is absent"), section 4 ("F16 (code tables). Not fixed") and section 7 *Deferred, with reasons*. Spec: specs/070-source-viewer-plugin/spec.md FR-024 (~L523). Site at 7993914c: src/plugins/codeview/intake.cpp ~624-631 (`// --- encoding (spec FR-024) ---`, `UINT codePage = CP_ACP;`). Recorded in specs/070-source-viewer-plugin/REMAINING-WORK.md, header *Update 2026-08-27 (third round)* ("Two things it did NOT cover remain open: ... the code-table gap (FR-024), now recorded as F16"); not in specs/NEXT-WORK.md at 7993914c.

## Expected

The Code Viewer can decode a single-byte file with any conversion table the built-in viewer offers; its encoding menu lists them, the choice is applied to the open file and remembered as the built-in viewer's is; files that decode correctly today (UTF-8, UTF-16, the system code page) are unchanged.

## Approach

From the stabilization review section 7: a feature-sized piece of work with its own UI question (how the table list is presented and remembered). Feature 069 established that the table names reach plug-ins as code-page bytes (`CCodeTablesData::Name`, handed out by `EnumConversionTables` and accepted back by `GetConversionTable`; dbviewer and filecomp persist them - RW069 section 1, B-5), and the plug-in's UTF-8 pipeline must respect that. Doing it badly would break the encoding menu that works today.

## Notes

Area: the Code Viewer is a plug-in (other-plugins); its core-side viewer machinery is the built-in viewer's. Related to encoding cluster B-5 (frozen plug-in-facing services, including the `CCodeTablesData::Name` invariant): the decision `plugin-ansi-services-interface-decision`.

## Log

- 2026-08-27 — 070 stabilization review: F16 deferred - a feature, not a repair
- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
