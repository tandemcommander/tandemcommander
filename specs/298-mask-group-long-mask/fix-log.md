# Fix log - 298-mask-group-long-mask

Backlog item `mask-group-prepare-unbounded-mask-copy` - a single mask longer than 259 bytes overruns the
mask group preparation buffers. Autonomous run (`/tandem-backlog-implement`), started from `main` at
1bc8f164.

## Measurement before (main at 1bc8f164)

Site: `src/masks.cpp` `CMaskGroup::PrepareMasks` - `char buf[MAX_PATH]; char maskBuf[MAX_PATH];`; the
split loop `*mask++ = *s++` is bounded only by the separators; `PrepareMask(buf, mask)` likewise.

Reach (callers enumerated with Grep `PrepareMasks|PrepareMask\(`, 70 sites):

- `CPlugins::Load` (`src/plugins2.cpp`): each plug-in's `ThumbnailMasks` registry value is read with a
  `MAX_GROUPMASK` (1001) cap and prepared while the configuration loads - at every start.
- the tab filter (`src/mainwnd2.cpp` reads `SAL_TAB_FILTER_MAX` = 1001 bytes; prepared on tab activation,
  `src/paneltabs.cpp`), criteria `NAMEMASKS` (`src/fileswna.cpp`, `MAX_GROUPMASK`), the FTP plug-in's ASCII
  masks (registry, `MAX_GROUPMASK`), `CreateSalamanderMaskGroup` (plug-ins).
- `PrepareMasks(errorPos, masksString)` with an external string, not bounded by `MAX_GROUPMASK` at all
  (viewer masks, `src/fileswnb.cpp`, `src/finddlg1.cpp`).
- Dialog fields (panel filter etc.) are read with a `MAX_PATH` bound - not a source of the overrun.

Probe `probe/mask298_probe.ps1` (hidden desktop; registry exported, restored, SHA-256 identical) writes
`HKCU\Software\Tandem Commander\0.1\Plugins\1\ThumbnailMasks` and starts the Debug build:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\298-mask-group-long-mask\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\298-mask-group-long-mask\probe\mask298_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

| Row | Value | Result |
|---|---|---|
| SHORT (control) | one 252-byte mask | PASS (start, exit 0) |
| MULTI (control) | 140 short masks, 1000 bytes | PASS |
| M300 | one 300-byte mask | FAIL - "A problem has occurred", RTC Error 2 "Stack memory corruption" in `CPlugins::Load` (`probe/crash_before_M300.txt`) |
| M1000 | one 1000-byte mask | FAIL - corrupted state: "Insufficient memory to allocate 18446744057809751104 bytes" |

Rows: PASS 4, FAIL 4 (`probe/result_before.txt`). Probe trap met on the way: a local `$started` in the
probe hid the library's `$Started` list (PowerShell names are case-insensitive) - renamed `$shown`.

`BL verify` recorded at 1bc8f164.

## Decisions

- Of the two options the item allows (refuse / a buffer sized to the mask) the sized buffer is taken: the
  mask stays whole, a configuration that worked keeps working, no new UI string (spec Assumptions).
- `PrepareMask` output is never longer than its input, so the work storage is the group text's length + 1.

## Analyze (speckit-analyze)

No CRITICAL / HIGH. MEDIUM U1 (US2 scenario named matching, which saltests cannot link) - restated as "the
prepared mask is the whole mask"; MEDIUM C1 (long mask after `|`) - added to T007. LOW C2 (out-of-memory path
not tested - cannot be forced) and C3 (the directly passed string > 1000 bytes checked through the rule, the
sizing by review) - accepted.

## Implementation

- `src/common/salmaskgroup.h` (new, header-only): `SalMaskGroupCutMask` (one mask, `;;` -> `;`, stops at a
  separator or a forbidden byte), `SalMaskGroupTrimMask` (bytes <= ' ' at both ends), `SalPrepareMaskU8` (the
  `PrepareMask` normalization). Neither writes more than its input's length + 1 bytes. Bytes compared as
  `unsigned char` - the same as the core's `/J` (also saltests is `/J`).
- `src/masks.cpp` `CMaskGroup::PrepareMasks`: the two `char [MAX_PATH]` stack buffers are one heap block of
  2 x (`strlen(group text)` + 1) bytes, allocated after the old prepared masks are released, freed by a local
  guard (`CWorkFree`, the idiom of `fileswn1.cpp`) on every return; allocation failure = `TRACE_E(LOW_MEMORY)`,
  `errorPos = 0`, FALSE (as the other out-of-memory exits). The cut / trim / normalize steps call the header.
  `masksLen` became `size_t` (the `SetDelta` argument cast back to `int`).
- `::PrepareMask` (exported as `CSalamanderGeneral::PrepareMask`) calls `SalPrepareMaskU8`; signature and
  contract unchanged.

## Measurements after

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | `BUILD SUCCEEDED`, exit 0, no warning in `masks.cpp` / `saltests.cpp` |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 26443 checks, 0 failed` |
| negative control | the rule cut a mask at 259 bytes (temporary), rebuilt | `26443 checks, 72 failed` (every long-mask row, the UTF-8 rows); restored -> 0 failed |
| probe after | (as before, `-Label after`) | SHORT, MULTI, M300, M1000: PASS 8, FAIL 0 (`probe/result_after.txt`); registry restored identical |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |

The random rows of `TestMaskGroupSplit298` (3000 groups over the bytes that matter) did not fail under the
negative control - their masks rarely exceed 259 bytes; they guard the equivalence of short groups, the fixed
long rows guard the length.
