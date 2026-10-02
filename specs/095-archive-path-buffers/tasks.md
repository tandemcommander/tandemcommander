# Tasks: archive path buffers (feature 095)

- [X] T001 Spec, plan, tasks; preserve the pre-change Debug build (build\tandemcommander\Debug_x64_pre095); commit
- [X] T002 [US1] Inventory: every fixed buffer in the four functions (src/fileswn2.cpp, fileswn5.cpp, fileswn6.cpp, fileswn9.cpp) that receives the archive path, the inner path or the file name, with its size, its source and its consumers; the cache's own limits (src/cache.*)
- [X] T003 [US1] Fix per spec FR-001..FR-003; saltests for any pure helper
- [X] T004 [US1] Probe specs/095-archive-path-buffers/probe/longarc_probe.ps1 (hidden desktop): deep folders, view / edit / leave; previous build as the negative control
- [X] T005 Independent review; fixes
- [X] T006 Gates: Debug + full Release builds, saltests, strict guard
- [X] T007 Records: CHANGELOG, specs/NEXT-WORK.md, CLAUDE.md, fix-log.md, quickstart.md; commit
