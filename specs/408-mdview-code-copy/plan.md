# Implementation Plan: Markdown Viewer — copy a code block to the clipboard

**Branch**: `408-mdview-code-copy` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/408-mdview-code-copy/spec.md`

## Summary

Every Markdown code block gets a script-free *Copy* link in its top-right corner. The
link points to `https://mdview.invalid/tc-copy-<token>-<serial>/<n>`; the shared
WebView2 host already cancels every navigation outside `doc.html` and hands a
user-initiated one to the viewer (`Callbacks::OnActivateLink`, feature 085). The
viewer recognises the copy address first, checks token, serial and number, and puts
block *n*'s source (kept by the generator in a table, like `img/<n>`) on the clipboard
as CR LF Unicode text. A successful copy is confirmed by a same-document fragment
navigation to a fixed-position *Copied* notice shown by CSS `:target` (two notices used
alternately). No script, no web message, no change to `src/common/webhost/`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: md4c (vendored), WebView2 through the shared `CTcWebHost`,
Salamander plug-in API (`CopyTextToClipboardW`, `LoadStrW`)
**Storage**: none (nothing new stored)
**Testing**: `tests/mdview_htmlgen_test/build_and_run.cmd` (generator + pure rules);
GUI probe `probe/copy408_probe.ps1` on the hidden desktop with a Debug-only seam
`TC_MDVIEW_PROBE_COPY_LOG` instead of the real clipboard
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`mdview.spl`)
**Performance Goals**: the copy is instant (one in-memory conversion of one block)
**Constraints**: scripts and web messages stay off (021); the shared host is not
changed or copied (081, `architecture/11`); new UI strings get the two-stage `.slt`
refresh (stop-rules §2.13)
**Scale/Scope**: 4 source files of mdview (`htmlgen.{h,cpp}`, `viewer.{h,cpp}`),
`lang/lang.rc2`, `mdview.rh2`, the harness, one probe

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; `salrandom.h` is header-only in the tree |
| II. Backward compatibility | nothing stored; documents without code blocks render byte for byte as before; existing links unchanged |
| III. Incremental modernization | a local addition in one plug-in |
| IV. Windows commitment | Win32 clipboard through the plug-in API |
| V. Plug-in architecture preservation | no ABI change (`CopyTextToClipboardW` exists); shared host untouched |
| VI. UI consistency | the control follows the theme variables of every colour scheme; strings localized |

Gate: PASS (no violation). Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/408-mdview-code-copy/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/copy-address.md      # the address, its parsing, the copied text
├── contracts/probe-seam.md        # TC_MDVIEW_PROBE_COPY_LOG (Debug only)
├── fix-log.md, closing-report.md
└── probe/ feas408_probe.ps1, copy408_probe.ps1, result_*.txt
```

### Source Code

```text
src/plugins/mdview/
├── htmlgen.h / htmlgen.cpp   # copy UI input, code block table, the copy CSS and notices,
│                             # pure rules MdCodeClipboardText / MdParseCopyLink
├── viewer.h / viewer.cpp     # token + serial, ActivateLink copy branch, notice, seam
├── mdview.rh2                # IDS_CODE_COPY / _TIP / IDS_CODE_COPIED (free slots 2197-2199)
└── lang/lang.rc2             # the English texts
tests/mdview_htmlgen_test/test_main.cpp   # new assertions
translations/*/mdview.slt, .origin        # two-stage refresh
```

**Structure Decision**: all changes inside the mdview plug-in and its harness; pure
rules beside `MdPageWidthFromStored` in `htmlgen` (research R4).

## Complexity Tracking

None.
