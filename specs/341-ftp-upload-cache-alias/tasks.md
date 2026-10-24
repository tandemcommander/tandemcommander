# Tasks: FTP upload listing cache recognises a server reached under another name

**Input**: `specs/341-ftp-upload-cache-alias/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: saltests checks of the pure rule and the hidden-desktop probe (required by the project's
working method and by SC-001..SC-003).

## Phase 1: Setup

- [X] T001 Start `specs/341-ftp-upload-cache-alias/fix-log.md` with the measurement at 3034d82f (probe `probe/result_main.txt`: ALIAS-REN FAIL, ALIAS-UP FAIL, SAME-REN PASS) and the enumerated callers of research.md R7

## Phase 2: Foundational (blocking)

- [X] T002 Create the pure header `src/common/salftpserverident.h`: `SalFtpServerNameRelation` (`sfsnSame`, `sfsnMaybeSame`, `sfsnDifferent`), `SalFtpCompareServerNames(sameHostText, a, na, b, nb)`, `SalFtpHostNameEqualAsciiCI`, and `CSalFtpHostAddrTable` (64 slots x 8 IPv4 addresses, host up to 255 bytes, record / lookup, round-robin eviction) per data-model.md
- [X] T003 Add `TestFtpServerIdent341` to `src/saltests/saltests.cpp` (include the header; relation table of data-model.md; table: record, replace, case-insensitive lookup, too-long host refused, zero addresses refused, more than 8 addresses capped, eviction of the oldest, lookup of an evicted name = 0) and call it from `main`
- [X] T004 Add `FTPRecordHostAddrs(host, addrs, n)` and `FTPGetHostAddrs(host, out, max)` (typed IPv4 via `inet_addr`, else the table; SRW lock, leaf) to `src/plugins/ftp/ftputils.h` / `src/plugins/ftp/ftputils.cpp`

## Phase 3: User Story 1 - a panel change reaches an upload made under another name (P1)

**Goal**: ALIAS-REN PASS. **Independent test**: probe row ALIAS-REN.

- [X] T005 [US1] Record the addresses of a successful lookup in `CGetHostByNameThread::Body` (`src/plugins/ftp/sockets.cpp`): the name and up to 8 entries of `h_addr_list`, copied before the thread posts the result
- [X] T006 [US1] Declare `CUploadListingCache::InvalidateOtherNamesOfServer(user, host, port, exact)` in `src/plugins/ftp/operats.h` and implement it in `src/plugins/ftp/operats9.cpp` (same user - anonymous normalised - and port, not the exact entry, `SalFtpCompareServerNames` == `sfsnMaybeSame` -> `InvalidateAllListings()`)
- [X] T007 [US1] Call it from `ReportCreateDirs`, `ReportRename`, `ReportDelete`, `ReportUnknownChange` in `src/plugins/ftp/operats9.cpp` (also when no exact entry exists)

## Phase 4: User Story 2 - an upload's own store reaches an upload under another name (P2)

**Goal**: ALIAS-UP PASS. **Independent test**: probe row ALIAS-UP.

- [X] T008 [US2] Call `InvalidateOtherNamesOfServer` from `ReportStoreFile` and `ReportFileUploaded` in `src/plugins/ftp/operats9.cpp`

## Phase 5: User Story 3 - different servers keep their caches (P3)

**Goal**: entries whose known addresses differ are untouched. **Independent test**: saltests.

- [X] T009 [US3] Confirm by the saltests rows (T003) and the probe row DIFF-KEEP (T012) that known, disjoint address lists give `sfsnDifferent`, and that `InvalidateOtherNamesOfServer` skips other users and ports (code reading recorded in fix-log.md)

## Phase 6: Polish & verification

- [X] T010 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T011 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> 0 failed
- [X] T012 Probe `specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1` on the hidden desktop -> `probe/result_after.txt` 8 / 0 (the DIFF-KEEP row for US3 added during implementation: a second server on 127.0.0.2, `probe/ftpmini_at.py`)
- [X] T013 Regression: `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` -> `specs/341-ftp-upload-cache-alias/probe/regress_302.txt` 16 / 0
- [X] T014 Negative control: with the fan-out calls disabled (temporary local edit, rebuilt, then restored and rebuilt) ALIAS-REN fails again - recorded in fix-log.md
- [X] T015 fix-log.md: before / after, commands, results, limits (proxy cost, two aliases uploading at once); SC-004 evidence: `git diff main...HEAD -- src/plugins/ftp` adds no `gethostbyname` / `GetHostByAddress` / `getaddrinfo` call (C1: short IPv4 forms are `inet_addr`'s, by reading)

## Dependencies

T001 -> T002 -> T003, T004 -> T005, T006 -> T007 -> T008 -> T009 -> T010..T015.
US1 needs the foundational phase; US2 reuses US1's helper; US3 is verified by T003.

## Parallel opportunities

T003 and T004 (different files) after T002.

## Implementation strategy

MVP = US1 (the item's probe row). US2 is two calls on the same helper; US3 is a property of the rule.
