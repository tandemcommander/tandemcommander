# Tasks: archives at long paths (feature 097)

## Phase 1 - Setup

- [X] T001 Research (research.md): the limiter, the callers, the consumer inventory, the plug-ins, options
- [X] T002 Spec, plan, tasks; preserve the pre-change Debug build (build\tandemcommander\Debug_x64_pre097); commit

## Phase 2 - User Story 1: refuse, never cut (S1)

- [X] T003 [US1] src/fileswn2.cpp ChangePathToArchive: no truncating copies; refusal with IDS_TOOLONGPATH; silent on refresh; callers checked (research 1.4)
- [X] T004 [US1] src/plugins/uniso/isoimage.cpp: bounded error text
- [X] T005 [US1] Probe specs/097-archive-long-path/probe/arcpath_probe.ps1 (hidden desktop): twin-file case, refusal cases, short control; previous build as the negative control
- [ ] T006 [US1] Independent review; fixes; commit `[097] S1 ...`

## Phase 3 - User Story 2: make it work (S2)

- [ ] T007 [US2] src/common/salplugver.h: the rule "which archive name length may this handler receive" (pure, saltests)
- [ ] T008 [US2] Lift the limit for plug-ins built for >= 107; keep the refusal for external archivers and older plug-ins
- [ ] T009 [US2] The core buffers on the plug-in route (research 2.2) -> heap strings or bounded with a clean refusal; the two shared 260-byte fields refuse; spl_arc.h comment
- [ ] T010 [US2] Probe: ZIP / 7z / TAR at 260, 400, 777 bytes and > 259 characters: enter, list, view, unpack, edit + update, add, delete; refusals; previous build
- [ ] T011 [US2] Independent review (with its own inventory); fixes; commit `[097] S2 ...`

## Phase 4 - Polish (S3)

- [ ] T012 Gates: Debug + full Release builds, saltests, strict guard, probes of 095 and 096
- [ ] T013 Records: CHANGELOG, specs/NEXT-WORK.md, CLAUDE.md, quickstart.md, fix-log.md; commit
