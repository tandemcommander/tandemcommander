# Tasks: Hard-linked names of a tar are listed and copied

**Input**: Design documents from `specs/325-tar-listed-hard-links/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the project requires `saltests` checks for pure rules (FR-009) and a GUI probe per feature.

## Phase 1: Setup

- [ ] T001 Keep the measurement probe and its result in specs/325-tar-listed-hard-links/probe/ (link325_probe.ps1, mklink325.py, result_before.txt) and the running record in specs/325-tar-listed-hard-links/fix-log.md

## Phase 2: Foundational (blocking)

- [ ] T002 Add SAL_TAR_LINK_DEFER, SalTarLinkDecideAsked, SalTarResolveHardLink and SalTarListedLinkSize to src/common/saltarlink.h (header-only, std::string / std::unordered_map)
- [ ] T003 Add TestTarLink325 to src/saltests/saltests.cpp: the decision table of data-model.md, chain resolution (direct, two steps, cycle, missing, self-link), listed size (data, chain, missing -> 0); call it from main
- [ ] T004 Keep the archive file name, offset and size in CArchive and add ReopenStream() (new CDecompressFile over the same file / offset / size, error shown, Offset reset) in src/plugins/tar/tar.h and src/plugins/tar/untar.cpp; the first stream is created from the kept name

## Phase 3: User Story 1 - Copying the files shown in an archive folder brings every hard-linked name (P1)

**Goal**: listed hard links; a Copy of them writes the target's content even when the target is not selected.
**Independent Test**: probe rows COPY-INSIDE, COPY-INSIDE-GZ, COPY-CHAIN, COPY-ROOT.

- [ ] T005 [US1] ListArchive in src/plugins/tar/untar.cpp: record hard links (name -> link name) and data member sizes; list a hard link (not NameRefused, not a folder) as a file with SalTarListedLinkSize, the header's own size kept 0 for the data skip
- [ ] T006 [US1] DoUnpackArchive in src/plugins/tar/untar.cpp: record every hard link of the pass; decide asked links with SalTarLinkDecideAsked (asked = names.IsNamePresent of the link name, deferred = an earlier deferred link); DEFER stores an SDeferredLink (tar.h) instead of reporting
- [ ] T007 [US1] ExtractDeferredLinks in src/plugins/tar/untar.cpp: resolve, group by data name, ReopenStream, second pass with progress (reset bar, Cancel), the first data member of each wanted name written under the first link's name (header name swapped for the overwrite question), the others via WriteOutLinkCopy, stop when nothing is wanted; unresolved / not written -> ReportLinkMember + refused; called at both ends of DoUnpackArchive before the progress dialog closes

## Phase 4: User Story 2 - One hard-linked name can be copied or viewed on its own (P2)

**Goal**: Copy of one focused link, overwrite question, F3.
**Independent Test**: probe rows COPY-FOCUSED, COPY-EXIST, VIEW-LINK.

- [ ] T008 [US2] UnpackOneFile in src/plugins/tar/untar.cpp: split into UnpackOneFilePass; a found hard link resolved through the links / data names seen earlier -> ReopenStream and a second pass extracting the data member as newFileName or the link's file name; unresolved -> feature 309's report
- [ ] T009 [US2] VIEW-LINK row of specs/325-tar-listed-hard-links/probe/link325_probe.ps1: read the disk-cache file named by the viewer title and require the target's content

## Phase 5: User Story 3 - A hard link that cannot be reproduced is reported (P3)

**Independent Test**: probe row COPY-MISSING.

- [ ] T010 [US3] Verify the COPY-MISSING path: a listed link to a missing member is deferred, unresolved after the second pass, reported once with `name -> link name`, the operation fails (src/plugins/tar/untar.cpp ExtractDeferredLinks)

## Phase 6: Polish & cross-cutting

- [ ] T011 Build (`.\build.cmd`), saltests, encoding guard (`python tools/check_encoding.py --strict`)
- [ ] T012 Run link325_probe.ps1 after the change -> specs/325-tar-listed-hard-links/probe/result_after.txt (all PASS); negative control (DEFER disabled) recorded
- [ ] T013 Regression probes 309, 308, 306, 321 -> specs/325-tar-listed-hard-links/probe/regress_*.txt; update rows that encoded unlisted links, if any
- [ ] T014 Record before / after, commands and decisions in specs/325-tar-listed-hard-links/fix-log.md

## Dependencies

T002 -> T003; T002, T004 -> T005..T008; T005..T008 -> T011 -> T012, T013 -> T014. US1 before US2 (shared helpers); US3 rides on US1's second pass.

## Parallel opportunities

T003 and T004 (different files) after T002; T009 (probe) alongside T008.

## Implementation strategy

MVP = US1 (listing + deferred second pass); then US2 (one file), US3 is verified by the probe.
