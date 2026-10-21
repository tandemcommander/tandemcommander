# Implementation Plan: Registry Editor Find - a regexp searches the whole code-page text

**Branch**: `278-regedt-find-regexp-cp` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/278-regedt-find-regexp-cp/spec.md`

## Summary

The regexp branch of `CFindThread::Test` (`src/plugins/regedt/finddlg.cpp`) converts a text to
the ANSI code page into a space of "unit count" bytes and searches "unit count" bytes. It gets a
pure rule `SalRegFindTextToCodePage(text, units, codePage, out, outSize)` in the header-only
`src/common/salregfind.h` (feature 257's header): with `out == NULL` it returns the byte count
the code page needs; with a space it converts and returns that count, or -1 when the
conversion fails or the space is too small (never a partial result). The call site counts,
reserves the counted bytes, converts, and searches the converted count; -1 is no match.
saltests check the rule under 65001 / 932 / 1250 with a negative control of the old sizing. See
[research.md](research.md), contract [contracts/text-to-code-page.md](contracts/text-to-code-page.md).

## Technical Context

**Language/Version**: C++20, MSVC v143; the plug-in builds with `/J` (unsigned char)
**Primary Dependencies**: Win32 (`WideCharToMultiByte`), the core's regexp through `CSalamanderREGEXPSearchData`
**Storage**: N/A (nothing stored)
**Testing**: saltests (pure rule, code page as a parameter); feature 257's hidden-desktop probe
`specs/257-regedt-find-words-hex/probe/find_words_hex_probe.ps1` re-run as a regression control
(it drives the regexp branch on code page 1250)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt`
**Performance Goals**: one extra counting call per searched text (the same API, no allocation)
**Constraints**: no UI strings; plug-in ABI untouched; header-only rule (the plug-in cannot
compile a `.cpp` from `src/common`); `WStrToStr` and its other callers unchanged
**Scale/Scope**: `src/plugins/regedt/finddlg.cpp`; `src/common/salregfind.h`;
`src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency or build step. PASS
- II Backward compatibility: single-byte code pages give the same bytes and length as before
  (one byte a unit); no configuration change. PASS
- III Incremental modernization: one call site, one header function. PASS
- IV Windows commitment: Win32 only. PASS
- V Plug-in architecture: no interface change; `salregfind.h` is already included by the
  plug-in's `precomp.h` (257). PASS
- VI UI consistency: no UI change. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

```text
specs/278-regedt-find-regexp-cp/
  spec.md  plan.md  research.md  data-model.md  quickstart.md  contracts/text-to-code-page.md
  tasks.md  fix-log.md  probe/ (results of 257's probe re-run)
src/
  common/salregfind.h              + SalRegFindTextToCodePage
  plugins/regedt/finddlg.cpp       Test, regexp branch: count, reserve, convert, search the count
  saltests/saltests.cpp            checks
```

**Structure Decision**: plug-in fix with its pure rule next to feature 257's in the existing
header-only `salregfind.h`.

## Complexity Tracking

None.
