# Tasks: 169

- [X] T001 Probe `specs/169-change-case-utf8/probe/change_case_probe.ps1`; control tree `build/tandemcommander/Debug_x64_pre169`
- [X] T002 Before: 7 / 5 - two files renamed to wrong names, three refusals (123)
- [X] T003 `src/common/salaltername.h`; `src/salamdr2.cpp` AlterFileName calls it
- [X] T004 saltests `TestAlterName169` (ASCII equivalence, UTF-8 cases, the length guard, the cost)
- [X] T005 After: 12 / 0; regressions 163, 158
- [X] T006 Independent review; records
