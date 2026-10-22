# Closing report - 298-mask-group-long-mask
Backlog item: mask-group-prepare-unbounded-mask-copy - A single mask longer than 259 bytes overruns the mask group preparation buffers
Outcome: closed

## What changed

- `src/common/salmaskgroup.h` (new, header-only): `SalMaskGroupCutMask`, `SalMaskGroupTrimMask`,
  `SalPrepareMaskU8` - the cut / trim / normalize steps of a mask group, byte for byte the old code, each
  writing at most its input's length + 1 bytes (contract: `contracts/mask-group-split.md`).
- `src/masks.cpp`: `CMaskGroup::PrepareMasks` uses one heap block of 2 x (`strlen(group text)` + 1) bytes
  instead of two `char[MAX_PATH]` stack buffers (freed on every return; out of memory = FALSE, `errorPos` 0);
  `::PrepareMask` calls `SalPrepareMaskU8` (plug-in contract unchanged).
- `src/saltests/saltests.cpp`: `TestMaskGroupSplit298` - a reference copy of the old code, a table of groups,
  259-3000-byte single masks (ASCII, 3-byte UTF-8, after `|`, with `;;`, `**`, `*?`) with guard bytes,
  3000 random groups.
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` (entry + index *Long paths, buffers*).

## Measurements (before / after, commands)

Probe `probe/mask298_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`, registry exported,
restored, SHA-256 identical), value `HKCU\Software\Tandem Commander\0.1\Plugins\1\ThumbnailMasks`:

| Row | Before (1bc8f164) | After |
|---|---|---|
| SHORT (252-byte mask, control) | PASS | PASS |
| MULTI (140 masks, 1000 bytes, control) | PASS | PASS |
| M300 (one 300-byte mask) | FAIL - crash at start, RTC "Stack memory corruption" in `CPlugins::Load` | PASS |
| M1000 (one 1000-byte mask) | FAIL - "Insufficient memory to allocate 18446744057809751104 bytes" | PASS |

Before: PASS 4, FAIL 4 (`probe/result_before.txt`, `probe/crash_before_M300.txt`); after: PASS 8, FAIL 0
(`probe/result_after.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`
- `.\build.cmd`: `BUILD SUCCEEDED`, no warning in the touched files
- saltests: `26443 checks, 0 failed`; negative control (the rule cutting at 259 bytes): 72 failed
- probe: 8 / 0 (above)

## Reviews (findings and what was done)

One independent refute-first review: no MUST, no SHOULD. Its own negative controls: an undersized heap block
made every probe row fail (heap corruption reported), a one-byte overrun in the rule made 37 saltests checks
fail. NOTEs: the saltests "reproduction" row is arithmetic (the probe proves the sizing) - recorded;
`SetMasksString` cuts above 1000 bytes - the plug-in contract, not filed; the Filter dialog's backup cut at
`MAX_PATH` - filed to the Inbox; details in `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

Nothing.

## New Inbox items (slug - title)

- filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a - Filter dialog cuts a long panel filter to 259 bytes after a refused edit
