# Tasks: A cpio or rpm member whose name the panel cannot hold is refused alone

**Input**: `specs/393-cpio-long-name/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the hidden-desktop probe is the feature's test (CLAUDE.md *Working method*); no new saltests
rule (the shared decision `SalPaxNameUsableU8` is already tested).

## Phase 1: Setup

- [ ] T001 Start `specs/393-cpio-long-name/fix-log.md` with the measurement of step 3 (tar321 probe row CPIO-TOOLONG at af18dc21)
- [ ] T002 [P] Write the fixture writer `specs/393-cpio-long-name/probe/mkcpio393.py` (newc / odc writers and rpm wrapper as in `specs/310-cpio-link-members/probe/mkcpio310.py`, the deep tree of `specs/321-tar-long-component/probe/mkunp321.py`; one archive per row)
- [ ] T003 Write the probe `specs/393-cpio-long-name/probe/cpio393_probe.ps1` (from `specs/321-tar-long-component/probe/unp321_probe.ps1`: Unpack rows and Copy rows, with a "(206) at opening" check and the archive extension per row); rows COPY-TOOLONG, COPY-ODC-TOOLONG, COPY-RPM-TOOLONG, COPY-DEEP, UNP-DEEP-DEL, UNP-TOOLONG-DEL, COPY-255, COPY-DIR100, COPY-NESTDIR, COPY-HARD-REFUSED, UNP-HARD-REFUSED-DEL

## Phase 2: Foundational

- [ ] T004 Run the probe on the unchanged build (label `before`) into `specs/393-cpio-long-name/probe/result_before.txt` and record the rows in `fix-log.md`

## Phase 3: User Story 1 - a cpio with an over-long member name opens (P1)

**Independent test**: rows COPY-TOOLONG, COPY-ODC-TOOLONG, COPY-RPM-TOOLONG, UNP-TOOLONG-DEL.

- [ ] T005 [US1] In `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`) apply the 306 / 308 / 321 refusal (`SalPaxNameUsableU8`) also to names read by a cpio reader (newc, crc, odc, binary, byte-swapped binary)
- [ ] T006 [US1] Give the check `isDir` from the cpio mode (`CP_IFDIR`) as well as from a trailing slash, in `src/plugins/tar/untar.cpp` (research R2; row COPY-NESTDIR)
- [ ] T007 [US1] Keep a refused name in its cpio hard-link group as not asked: `IsCpioGroupMember` accepts `NameRefused`, `DoUnpackArchive` passes `found && !header.NameRefused` to `WriteOutCpioGroupMember`, in `src/plugins/tar/untar.cpp` (research R3, FR-006; rows COPY-HARD-REFUSED, UNP-HARD-REFUSED-DEL)

## Phase 4: User Story 2 - deep members list without failing and unpack whole (P1)

**Independent test**: rows COPY-DEEP, UNP-DEEP-DEL (the depth bound only while listing - nothing to add beyond T005, which passes `Listing`); verified by T009.

## Phase 5: User Story 3 - names that fit keep working (P2)

**Independent test**: rows COPY-255, COPY-DIR100; regression probes.

- [ ] T008 [US3] Run the regression probes: `specs/310-cpio-link-members/probe/cpio310_probe.ps1`, `specs/321-tar-long-component/probe/tar321_probe.ps1` and `unp321_probe.ps1`, `specs/306-tar-pax-headers/probe/pax306_probe.ps1`, `specs/308-pax-deep-unpack/probe/unp308_probe.ps1`, `specs/309-tar-link-members/probe/link309_probe.ps1`; results into `specs/393-cpio-long-name/probe/regress_*.txt`

## Phase 6: Polish

- [ ] T009 Build (`build.cmd`), `saltests`, `python tools/check_encoding.py --strict`; run the probe (label `after`) into `specs/393-cpio-long-name/probe/result_after.txt`
- [ ] T010 Negative control: the cpio refusal switched off (and separately the group change off) in a scratch copy - the probe's rows must fail; record in `fix-log.md`
- [ ] T011 Record before / after, commands and results in `specs/393-cpio-long-name/fix-log.md`

## Dependencies

T001-T003 -> T004 -> T005 -> T006 -> T007 -> T008 / T009 -> T010 -> T011. All code tasks touch one
file (`untar.cpp`), so they are sequential; T002 can run beside T001.

## Implementation strategy

MVP = US1 (T005-T007): the archive opens and linked names keep their data. US2 needs no own code; US3
is regression only.
