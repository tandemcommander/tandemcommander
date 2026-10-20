# Implementation Plan: Registry Editor Find - whole-word regexp, empty regexp, letters in quoted hex

**Branch**: `257-regedt-find-words-hex` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/257-regedt-find-words-hex/spec.md`

## Summary

(a) `CFindThread::Test` judges a whole-word regexp match with `SalRegFindWholeWordInLine(start,
end - start, pos, matchLen)` - the matched line, not the value's start. (b) `StartSearch` gives
an empty regular expression the length 0, so the search treats it as the empty plain pattern
(everything). (c) `ConvertHexToString` / `ValidateHexString` become wrappers of
`SalHexPatternToBytes(text, CP_ACP, strict, ...)`, which converts each `'...'` run as one text
into all its code-page bytes and counts the same bytes. Pure rules in the header-only
`src/common/salregfind.h`, checked by saltests with code pages 65001 / 932 / 1250. See
[research.md](research.md), contract [contracts/hex-pattern.md](contracts/hex-pattern.md).

## Technical Context

**Language/Version**: C++20, MSVC v143; the plug-in builds with `/J` (unsigned char)
**Primary Dependencies**: Win32 (`WideCharToMultiByte`), the core's regexp through `CSalamanderREGEXPSearchData`
**Storage**: N/A (nothing stored)
**Testing**: saltests (pure rules); hidden-desktop probe `probe/find_words_hex_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt`
**Performance Goals**: N/A (one conversion per search start)
**Constraints**: no UI strings (existing messages only); plug-in ABI untouched; header-only rule
(the plug-in cannot compile a `.cpp` from `src/common`)
**Scale/Scope**: `src/plugins/regedt/finddlg.cpp`, `finddlg2.cpp`, `utils.cpp`, `precomp.h`;
`src/common/salregfind.h`; `src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no new dependency or build step. PASS
- II Backward compatibility: plain-text, number, `"..."` and hex-digit searches unchanged; ASCII
  quoted text gives the same bytes; single-byte code pages give the same bytes; no configuration
  change. PASS
- III Incremental modernization: two small call-site changes and one header. PASS
- IV Windows commitment: Win32 only. PASS
- V Plug-in architecture: no interface change. PASS
- VI UI consistency: no new UI; existing messages. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

```text
specs/257-regedt-find-words-hex/
  spec.md  plan.md  research.md  quickstart.md  contracts/hex-pattern.md  tasks.md  fix-log.md
  probe/   find_words_hex_probe.ps1  result_before.txt  result_after.txt
src/
  common/salregfind.h              SalRegFindWholeWordInLine, SalHexPatternToBytes
  plugins/regedt/precomp.h         includes salregfind.h
  plugins/regedt/finddlg.cpp       Test: whole-word rule on the line
  plugins/regedt/finddlg2.cpp      StartSearch: empty regexp = length 0
  plugins/regedt/utils.cpp         ConvertHexToString / ValidateHexString -> SalHexPatternToBytes
  saltests/saltests.cpp            checks
```

**Structure Decision**: plug-in fix with its pure rules in a header under `src/common/`, as
189's `salmultisz.h`.

## Complexity Tracking

None.
