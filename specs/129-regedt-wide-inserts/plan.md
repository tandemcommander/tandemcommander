# Implementation Plan: Registry Editor - wide inserts (feature 129)

**Branch**: `129-regedt-wide-inserts` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

The plug-in formats registry names (UTF-16) with `%ls` in narrow printf calls. The C runtime
converts such an insert with the "C" locale: a letter above U+00FF fails the call - an empty
text with the secure functions (`_vsnprintf_s`), a text cut at that letter with `vsprintf`.
The texts are composed without the runtime's locale instead: UTF-8 template, each `%ls`
replaced by the UTF-8 form of its insert, in a buffer as long as the text.

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: none new
**Testing**: `saltests` (`TestWideInserts129`), GUI probe `probe/wide_probe.ps1` (hidden desktop)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt.spl`
**Constraints**: no new strings (translations untouched); plug-in interface unchanged;
a name is never cut; the plug-in cannot compile a `.cpp` from `src/common` (header-only rule)
**Scale/Scope**: 6 call sites in 3 files of the plug-in, one new header, tests

## Constitution Check

- Build reproducibility: no new dependency, no project change (a header). PASS
- Backward compatibility: texts and cache names for ASCII registry names are byte-identical
  (unit check against the old composition). PASS
- Incremental modernization: one rule in `src/common`, used by the plug-in. PASS
- Plugin architecture: no interface change. PASS
- UI consistency: the same sentences, complete. PASS

## Design

| Piece | Where | What |
|---|---|---|
| `SalWideInsertsUsed / Count / ExpandTo / ExpandAlloc` | `src/common/salwideinserts.h` (new, header-only) | `%ls` -> UTF-8 of the next wide insert, `%%` -> `%`, anything else copied; size pass + write pass; malloc'd whole text |
| `FormatWideU8(template or id, insert1, insert2)` | `regedt.cpp` / `regedt.h` | the plug-in's wrapper; a template by id is loaded wide (`LoadStrW`) and converted to UTF-8 |
| `ErrorHelper` | `regedt.cpp` | a template with `%ls` goes to `ErrorHelperWide`: UTF-8 template (by id), wide inserts from the argument list, the system's reason through `FormatMessageW`; every other template takes the old path unchanged |
| the create-target question, the self-copy message | `fs5.cpp` | `FormatWideU8`; no text -> not asked, nothing created / the copy fails |
| the name in the "class name differs" question | `fs5.cpp` | `FormatWideU8("%ls\\%ls")` |
| the unique name for the disk cache | `fs3.cpp` `ViewFile` | `fsName:\` + `FormatWideU8("%ls\\%ls")` + `\` + value name, heap |

Decisions:

- **Not the runtime's UTF-8 locale** (`_create_locale(".UTF8")` + `_vsnprintf_s_l`): it depends
  on the Windows version of the Universal C Runtime and converts character by character (a
  surrogate pair would fail). An explicit expansion is small and testable.
- **Only `%ls` is understood.** The templates concerned have nothing else (checked in English
  and in all translations); other templates keep the old code path, so nothing else changes.
- **Fail closed** where the text is a question before a write.

## Project Structure

```text
src/common/salwideinserts.h          new
src/plugins/regedt/precomp.h         include
src/plugins/regedt/regedt.h/.cpp     FormatWideU8, ErrorHelperWide
src/plugins/regedt/fs3.cpp           ViewFile
src/plugins/regedt/fs5.cpp           three sites
src/saltests/saltests.cpp            TestWideInserts129
specs/129-regedt-wide-inserts/       spec, plan, research, tasks, quickstart, fix-log, probe/
```
