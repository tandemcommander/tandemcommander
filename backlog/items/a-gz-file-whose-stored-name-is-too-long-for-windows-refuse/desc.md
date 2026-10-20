---
title: A .gz file whose stored name is too long for Windows: refuse it or use the archive name
type: decision
status: new
severity: 3
area: archives
source: review:260
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# A .gz file whose stored name is too long for Windows: refuse it or use the archive name

## Problem

Since feature 260 the tar plug-in reads a .gz file's stored original name whole. When that name has more than 255 UTF-16 units (no Windows file system takes it), the .gz file cannot be opened at all: "GZip Error" with the system's "(206) The filename or extension is too long." The backlog item that 260 implemented asked for exactly that ("refused, never extracted under a cut name"). But the user then cannot get the data out with the program, while `gzip -d` itself ignores the stored name by default and uses the archive's own name.

## Evidence

At aec864cf: `src/plugins/tar/untar.cpp` `CArchive::GetStreamHeader` (the feature-260 refusal); `src/plugins/tar/fileio.cpp` `CDecompressFile::GetOldName` already builds the fallback name (the archive's name without its extension) when no name is stored. Probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` row GZOVER. Review 1 of feature 260, N2 (`specs/260-archive-cache-long-names/fix-log.md`, *Review*).

## Expected

The maintainer chooses A or B; B becomes a small work item.

## Question

Should a .gz file whose stored name is too long for Windows stay refused, or be listed under the archive's own name?

## Options

- **A - keep the refusal (now).** Nothing is ever extracted under a name the packer did not give; the user must extract it with another tool - in this program the data stays unreachable.
- **B - fall back to the archive's name** (`x.txt.gz` -> `x.txt`, what `gunzip` does without `-N`), perhaps with a one-time note that the stored name was too long. The data is reachable; the member's name in the panel differs from the stored one (not a cut of it - the archive's own name).

## Recommendation

B: the fallback is a defined name, not a cut one, and gzip's own default; the refusal protects nothing in a single-file stream.

## Log

- 2026-10-20 — created (source review:260)
- 2026-10-20 — related cleared (not related to the 520-byte item)
