# Implementation Plan: archives at long paths

**Branch**: `097-archive-long-path` (from `096-archive-edit-accented`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary

`CFilesWindow::ChangePathToArchive` cuts the archive path (and the inner
path, and the focus name) to 259 bytes with `lstrcpyn(..., MAX_PATH)`.
Stage 1 replaces the cut by a refusal. Stage 2 removes the limit for
archives handled by current plug-ins and replaces the fixed buffers the
longer path then reaches (research 2.2: 12 on the plug-in route, the
external-archiver route is refused instead).

## Technical Context

C++ (MSVC v143), core + one plug-in line (`uniso`). Heap strings:
`CSalHeapString` (`src/common/salheapstr.h`, feature 095) or the core's
existing heap path buffers. The rule for old plug-ins lives next to
`SalViewerNameFitsPlugin` in `src/common/salplugver.h` (feature 088), pure
and tested by saltests. No new strings (`IDS_TOOLONGPATH` exists), no
interface change (107), no configuration change.

## Constitution Check

Backward compatibility: paths that fit today behave as before; third-party
plug-ins built for older interfaces never receive a longer name than before.
Incremental: two stages, each reviewed and committed. Plug-in architecture:
no ABI change; `spl_arc.h` gains a documented statement about the length of
the archive name (comment only). Gate passes.

## Stages

| Stage | Content | Evidence |
|---|---|---|
| **S1** refuse, never cut | `ChangePathToArchive`: no truncating copy; too-long archive path / inner path / focus name -> `IDS_TOOLONGPATH` (title `IDS_ERRORCHANGINGDIR`), `CHPPFR_INVALIDPATH`, FALSE; silent on refresh; every caller checked for an upstream cut; `uniso` bounded error text | probe: twin-file case (old build opens the twin), refusal cases via Enter, Change Directory, history; short-path control |
| **S2** make it work | the limit moves from "259 bytes" to "what the handler takes": plug-in built for >= 107 -> any length the file layer opens; external archiver or older plug-in -> 259 bytes (refusal of S1); the core buffers of research 2.2 on the plug-in route become heap strings or bounded with a clean refusal; the two 260-byte shared fields refuse an archive name that does not fit; `spl_arc.h` documents the length | probe: ZIP / 7z / TAR at 260, 400, 777 bytes and > 259 characters: enter, list, view, unpack, edit + update, add, delete; refusal cases; previous build as control |
| **S3** gates & records | builds, saltests, guard, probes of 095 / 096, CHANGELOG, NEXT-WORK, CLAUDE.md, quickstart | - |

## Risks

1. A buffer the inventory missed: an overrun the moment the limit is lifted.
   Mitigation: the Debug build's stack checks under the probe at several
   lengths; the reviewer repeats the inventory independently (grep every
   consumer of `GetZIPArchive()`); S1's refusal stays as the fallback for any
   route that cannot be made safe.
2. Plug-ins: `zip` and `tar` take any length; `7zip` cuts only display text;
   `uncab` refuses itself; `uniso` fixed in S1. Third-party plug-ins: covered
   by the built-for-version rule.
3. External archivers: not widened.
4. The shared 260-byte fields: refused, not widened.
