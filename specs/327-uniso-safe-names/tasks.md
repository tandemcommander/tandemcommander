# Tasks: Every name the ISO plug-in lists is made safe before extraction

**Input**: Design documents from `specs/327-uniso-safe-names/` (plan.md, spec.md, research.md,
data-model.md, contracts/item-name.md, quickstart.md)

**Tests**: required by the spec (FR-005 unit checks, SC-001 / SC-002 probes, SC-003 negative control).

## Phase 1: Setup

- [ ] T001 Confirm the "before" record: `specs/327-uniso-safe-names/probe/result_before.txt` (PASS 19, FAIL 39 on e50d62ad) is committed and summarised in `specs/327-uniso-safe-names/fix-log.md`

## Phase 2: Foundational (the rule)

- [ ] T002 Add `SalArcNameDetail::CleanOneName(char* name, size_t size, bool overwriteWhenFull)` and `SalArcCleanItemName(char* name, size_t size)` (N3, contract `contracts/item-name.md`) to `src/common/salarcname.h`
- [ ] T003 Make `SalSuspCleanRockRidgeName` in `src/common/salsusp.h` call `SalArcNameDetail::CleanOneName(name, size, false)` - feature 326's behaviour unchanged (its saltests cases must still pass)
- [ ] T004 Add `TestArcItemName327` to `src/saltests/saltests.cpp` (the cases of the contract: separators, colon, `<>"|?*`, control bytes, trailing dots / spaces, `.` / `..`, empty, device names with and without extension, `console.txt` kept, UTF-8 kept whole, the prefix that does not fit -> first letter `_`, unterminated buffer refused, idempotent, safe names byte-identical) and call it from `main`
- [ ] T005 Add `MakeSafeName(char* name, int bufSize)` and `AppendSafeName(char* target, const char* name, int targetSize)` to `src/plugins/uniso/uniso.h` / `src/plugins/uniso/uniso.cpp` (include `../../common/salarcname.h`)

## Phase 3: User Story 1 - extracting a crafted image never writes outside the target or into a stream (P1)

**Goal**: every name read from ISO 9660, Joliet, UDF, HFS+ and Xbox directories is listed safe and
joined safe. **Independent test**: probe sets JOLIET, PLAIN, UDF, XBOX, HFS.

- [ ] T006 [US1] `src/plugins/uniso/iso9660.cpp`: `MakeListedName` cleans every name (non-Rock Ridge by `SalArcCleanItemName`; the Rock Ridge fallback name too); Joliet folders in `ListDirectoryRe` cleaned after `ConvJolietName`, before `AddFileDir` and the descent path
- [ ] T007 [P] [US1] `src/plugins/uniso/udf.cpp`: `ScanDir` cleans `fileName` after `ReadFileIdentifier`, before `AddFileDir` and `newPath`
- [ ] T008 [P] [US1] `src/plugins/uniso/hfs.cpp`: `ListDirectory` cleans `fileName` after `FixIllegalFSChars`, before the hidden test, `DupStr` and `fi->name`
- [ ] T009 [P] [US1] `src/plugins/uniso/xdvdfs.cpp`: `ScanDir` cleans `fileName` after `EnsureU8Name`, before `AddFileDir` and the descent path
- [ ] T010 [US1] `UnpackFile` of `iso9660.cpp`, `udf.cpp`, `hfs.cpp`, `xdvdfs.cpp`, `rawfs.cpp` in `src/plugins/uniso/`: join with `AppendSafeName` instead of `SalPathAppend(name, fileData->Name, ...)` (FR-006)

## Phase 4: User Story 2 - a hybrid image's volume label cannot steer files elsewhere (P1)

**Goal**: the volume label folders are safe. **Independent test**: probe set VOL.

- [ ] T011 [US2] `src/plugins/uniso/udfiso.cpp` `ListDirectory`: the components `ISO (<label>)`, `UDF (<label>)` cleaned as one name each (`partPath + 1`) before they are appended to the path; `HFS (<label>)` keeps its existing `sprintf(path, ...)` and the component after its leading `\` is cleaned in place

## Phase 5: Polish & verification

- [ ] T012 clang-format only the changed lines of the touched sources
- [ ] T013 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `.\build.cmd` -> BUILD SUCCEEDED; `saltests.exe` -> 0 failed
- [ ] T014 Negative control of the rule (scratch mutants of `salarcname.h`: no separator, no colon, no trailing dot, no device prefix, no overwrite fallback) -> each fails saltests; restored byte-identical (SC-003)
- [ ] T015 Probe after: `iso327_probe.ps1 -Label after` -> `probe/result_after.txt`, 0 FAIL (SC-001); `iso326_probe.ps1` and `iso322_probe.ps1` -> `probe/result_326_after.txt`, `probe/result_322_after.txt` (SC-002)
- [ ] T016 Side observations re-checked on the fixed build ("Cannot read sector #00000020" at the open of the HFS+ hybrid, memory-leak boxes after the HFS set); those that persist -> Inbox items (`measure:327`)
- [ ] T017 `specs/327-uniso-safe-names/fix-log.md` complete (implementation, checks, probe numbers); CHANGELOG entry under the `— unreleased` heading in `CHANGELOG.md`

## Dependencies

T002 -> T003, T004, T005 -> T006..T011 -> T012..T017. US1 and US2 are independent of each other
after Phase 2. T007, T008, T009 touch different files (parallel).

## Implementation Strategy

Phase 2 first (the rule with its checks), then US1 (the readers) and US2 (labels), then one build and
one probe run covering both stories.
