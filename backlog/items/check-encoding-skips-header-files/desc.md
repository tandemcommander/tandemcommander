---
title: The encoding guard does not read header files; plug-in headers convert names leniently
type: tech-debt
status: new
severity: 2
area: tooling
source: review:255
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: [plugin-encoding-scan-strict-in-build]
depends-on: []
reason: -
---

# The encoding guard does not read header files; plug-in headers convert names leniently

## Problem

`tools/check_encoding.py` scans only `*.cpp` files (`sources()`), for the core and for
`--plugins`. Code in headers is never checked, so "every finding has a verdict" (feature 255)
covers `.cpp` files only. The review of 255 found two lenient UTF-16 to UTF-8 converters of names
in plug-in headers that the scan cannot see:

1. Registry Editor `regedt/utils.h` `WStrToU8` / `U8ToWStr` - registry key and value names; an
   unpaired surrogate in a key name becomes U+FFFD, so navigating by the shown name finds a
   different (or no) key. Delete uses the stored UTF-16 name - no data loss was found.
2. Portables `portables/wpdhelpers.h` `WpdGetStringValue` - device file names
   (`WPD_OBJECT_ORIGINAL_FILE_NAME`), looked up by name (`fxfs.cpp`); two names that differ only in
   an unpaired surrogate collapse into one.

Headers of the core (`src/*.h`, `src/common/*.h`) are not scanned either.

## Evidence

Found by the review of feature 255 (`specs/255-plugin-encoding-findings/fix-log.md`, *Review*), by
reading, at e849e68c: `tools/check_encoding.py` `sources()` (`SRC.rglob("*.cpp")`);
`src/plugins/regedt/utils.h`, `src/plugins/portables/wpdhelpers.h`.

## Expected

The guard scans `.h` files too (core and `--plugins`); its new findings get verdicts (fixed,
annotated with a reason, or their own items); the core's strict scan still reports 0 at the end.

## Approach

Add `*.h` to `sources()`, run once with and without `--plugins`, and triage as feature 255 did
(`verdicts.md`); the two converters above are the first candidates for WTF-8 (`SplWToU8` /
`SplU8ToW`). Measure first: the core's strict gate must not start failing in the same change
without verdicts.

## Notes

Probably more than a few findings in the core's headers (inline helpers); effort is an estimate.

## Log

- 2026-10-20 — created (source review:255)
