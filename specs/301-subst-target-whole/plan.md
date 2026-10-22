# Implementation Plan: A subst drive's target is read whole or refused, never cut or in the code page

**Branch**: `301-subst-target-whole` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/301-subst-target-whole/spec.md`

## Summary

`MyQueryDosDevice` / `GetSubstInformation` (`src/salamdr2.cpp`) read a drive's device text with
`QueryDosDeviceW` into 260 units, convert it into a 260-byte UTF-8 buffer and, when that fails,
ask again with the code-page `QueryDosDevice` (A) - the `?` target that `ResolveSubsts` then
splices into paths; `GetSubstInformation` also cuts with `lstrcpyn`. The device text becomes a
whole wide read on the heap (the buffer grows on `ERROR_INSUFFICIENT_BUFFER`), the code-page call
goes away, and the parse "device text -> subst path" becomes a pure header
`src/common/salsubst.h` that refuses (never cuts) when the caller's buffer is too small.
`GetSubstInformation` gains an optional `BOOL* tooLong` (core-internal, default `NULL`);
`ResolveSubsts` returns FALSE and leaves the path unchanged on a refused target (the existing
too-long behaviour of the plug-in function); the display callers get buffers that hold every
target `subst.exe` can create.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI `QueryDosDeviceW`; `src/common/salunicode.h` (`SalWToU8`, WTF-8, 066)
**Storage**: N/A
**Testing**: `saltests` (`TestSubstTarget301`: the parse rule, exact fit / one byte short, the
forms); hidden-desktop probe `probe/subst_probe.ps1` (9 rows: SHORT / CJK / LONG x DEL / INFO /
END); `dumpbin /imports` (no `QueryDosDeviceA`); Copy as UNC is a person step (no clipboard on the
hidden desktop)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`) + `saltests`
**Performance Goals**: N/A (one extra allocation per query; the device query is not in a hot loop -
`ResolveSubsts` is called per operation, not per file)
**Constraints**: a path is never cut (097/098/101); UTF-8 / WTF-8 names never through the code page
(066); the plug-in ABI `ResolveSubsts(char*)` with its `MAX_PATH` contract unchanged; no new UI
string (084)
**Scale/Scope**: `src/salamdr2.cpp` (2 functions + `ResolveSubsts`), `src/consts.h` (declaration),
`src/dialogs3.cpp`, `src/drivelst.cpp`, `src/fileswn9.cpp`, `src/bugreprt.cpp` (unchanged call -
the refusal is enough), new `src/common/salsubst.h`, `src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: a new header only (no project file change - header-only, included by
  `salamdr2.cpp` and `saltests.cpp`). PASS
- II Backward compatibility: every target that fitted before is returned byte for byte as before
  (an ASCII or short target); only the `?` / cut answers change into refusals; `ResolveSubsts`
  keeps its signature and its return contract (FALSE = not resolved, path unchanged). PASS
- III Incremental modernization: the existing functions are fixed in place; the pure part moves
  to a tested header. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: no change to `spl_*.h`; the plug-in function behaves as documented. PASS
- VI UI consistency: no new text; Copy as UNC uses feature 101's existing "too long" message. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|------|--------|
| `src/common/salsubst.h` (new) | `SalSubstTargetToPathU8(const WCHAR* device, char* path, int pathMax)` -> `SAL_SUBST_NONE` / `SAL_SUBST_OK` / `SAL_SUBST_TOO_LONG`: `\??\X:...` -> `X:...`, `\??\UNC\rest` -> `\\rest`, anything else -> NONE; the UTF-8 size is measured first (`SalWToU8(.., NULL, 0)`) and a result that does not fit `pathMax` (terminator included) is refused with `path` emptied. |
| `src/salamdr2.cpp` (static) | `QueryDosDeviceWholeW(BYTE driveNum)` -> `WCHAR*` (malloc): `QueryDosDeviceW` into MAX_PATH units, doubling on `ERROR_INSUFFICIENT_BUFFER` up to 64 Ki units; NULL when there is no device or no memory. |
| `MyQueryDosDevice` | whole wide read, `SalWToU8` of the first string after its size is measured; does not fit -> FALSE; **no** code-page fallback. |
| `GetSubstInformation(driveNum, path, pathMax, BOOL* tooLong = NULL)` | whole wide read + `SalSubstTargetToPathU8`; TOO_LONG sets `*tooLong`; same TRUE/FALSE meaning as before. |
| `ResolveSubsts` | a refused target: `TRACE_E`, `ret = FALSE`, break - the path left as it is (as the existing "too long path!" branch). |
| `src/fileswn9.cpp` Copy as UNC | passes the real size of `target` (`2 * MAX_PATH`); a refused target sets `*tooLong` (feature 101's message). |
| `src/dialogs3.cpp` Drive Information | the subst target into its own `char substTarget[SAL_SUBST_TEXT_U8_MAX]` (3 * MAX_PATH + 1: every `subst.exe` target); the "(subst: %s)" text appended only when the whole composed line fits `volumeName[1000]` - else no subst text (and the junction text is not shown instead: `substInfo` is TRUE when the drive is a subst drive, as before). |
| `src/drivelst.cpp` `BuildData` (remote drive) | `GetSubstInformation(.., volumeName, SAL_SUBST_TEXT_U8_MAX)` (the buffer is `DRIVE_MENU_NAME_MAX + 100` = 1662; the `&` doubling bound `DRIVE_MENU_NAME_MAX` = 1562 >= 2 * 780); a refused target -> empty text, as for "no subst". |
| `src/bugreprt.cpp` | unchanged call: a device text over 260 bytes is now omitted instead of `?`. |
| `src/drivelst.cpp` `drvtRemote` `min(l, MAX_PATH - 1)` | unchanged: `netRemotePath` is `char[..][MAX_PATH]`, never cut (measured by reading). |

`SAL_SUBST_TEXT_U8_MAX` = `3 * MAX_PATH + 1`: `subst.exe` refuses a target of MAX_PATH units or
more (measured), so a subst path has < MAX_PATH units, at most 3 bytes each.

## Measurement

- **Before** (HEAD build, `probe/result_before.txt`): 7 PASS / 2 FAIL - CJK DEL ("directory"),
  CJK INFO (empty line).
- **After**: 9 / 0 expected - CJK DEL "junction" (the subst path does not fit `ResolveSubsts`'
  260 bytes: refused, the path `Z:\J` used as is, which Windows resolves), CJK INFO "local drive
  (subst: C:\...\<80 CJK>)" whole; SHORT and LONG unchanged.
- `dumpbin /imports` of `tandemcommander.exe`: `QueryDosDeviceA` before, gone after.
- `saltests`: new checks pass; the total grows.
- Negative control: the saltests "one byte short" check fails when the size test is removed from
  the rule (done once by hand in a scratch edit, recorded in the fix-log).

## Project Structure

### Documentation (this feature)

```text
specs/301-subst-target-whole/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/subst_probe.ps1, result_*.txt
```

No `contracts/`: the only interface other parts rely on (`ResolveSubsts` of the plug-in API) does
not change.

### Source Code (repository root)

```text
src/common/salsubst.h       new, header-only
src/salamdr2.cpp            MyQueryDosDevice, GetSubstInformation, ResolveSubsts
src/consts.h                GetSubstInformation declaration (optional tooLong)
src/dialogs3.cpp            CDriveInfo::Transfer
src/drivelst.cpp            BuildData (remote drive text)
src/fileswn9.cpp            CopyUNCPathToClipboardAux
src/saltests/saltests.cpp   TestSubstTarget301
```

**Structure Decision**: existing core sources plus one header-only rule under `src/common/`.

## Complexity Tracking

None.
