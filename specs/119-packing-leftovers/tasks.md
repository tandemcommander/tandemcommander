# Tasks: feature 119 - the leftovers of the packing fixes

- [x] T001 Research by code reading: the multi-volume clean-up, the final rename, the core's routes
      into a packer, the texts (`research.md` R1-R5)
- [x] T002 Spec with clarifications (decisions), plan
- [x] T003 Copy `Debug_x64` to `Debug_x64_pre119` (without `Intermediate`) before the first build
- [x] T004 `src/common/salpackvol.h`: `CSalPackCreatedFiles`, `SalPackVolCleanupScope`,
      `SalPackCreatedMayDelete`, `SalMultiVolFinalNameTaken`; saltests `TestPackLeftovers119`
      (pure + real NTFS: a recorded volume replaced by another file is never deleted)
- [x] T005 ZIP plug-in: record created volumes (`CreateNextFile`), `DeleteCreatedVolumes`,
      `outputComplete`, scope guard in `PackMultiVol` (FR-001..FR-003)
- [x] T006 ZIP plug-in: `IDS_CANTMULTIVOL` before anything is created; the final rename checked and
      reported (FR-004, FR-005, FR-008)
- [x] T007 Core: `PackArchiveIsSelectedSource` shared; `ShowPackIntoItselfRefusal`; Pack dialog,
      F5 / F6, drag & drop / paste refuse before the question / packer (FR-006, FR-007)
- [x] T008 Debug build, saltests 14,576 -> 14,639 / 0, strict guard `TOTAL: 0`, clang-format on the
      changed regions
- [x] T009 Full Release build
- [x] T010 Hostile re-read of the diff (fix-log "Review")
- [x] T011 Probe `probe/packleft_probe.ps1` (106's rows with 119 expectations + L, K, Czech rows),
      written and parse-checked, NOT run
- [x] T012 Records: fix-log, CHANGELOG, NEXT-WORK; `Debug_x64_119` copied
- [x] T015 Code review (ACCEPT pending GUI, no blocker): SF1 keep a volume when unsure (no ids:
      creation time + written size), identity re-read by name if the handle gives none; SF2
      `NextDisk` clears `TempNameOurs`, removable clean-up under the identity rule; SF3 the hidden
      desktop refusal in the probe and in `fix_probe_lib.ps1`; SF4 copy / cut + paste rows (NOT
      DRIVEN without a clipboard) + by-hand step; SF5 plain-file pre-filter; NITs: ancestors from
      the resolved path, `DetectRemovable` for `\\?\` / UNC. Rebuilt, gates repeated, saltests
      14,655 / 0, `Debug_x64_119` re-copied
- [x] T013 GUI runs on `Debug_x64_119` (PASS 104 / FAIL 0 / NOT DRIVEN 8) and `Debug_x64_pre119`
      (69 / 35 / 8 - the predicted rows); regressions 099 24/0, 110 42/0, 113 37/0; registry
      1AB614304771DBE0 identical before and after every run (fix-log "GUI results")
- [ ] T017 By-hand, OWED TO A PERSON: drag & drop and paste into the selected archive (quickstart
      2b) - the clipboard cannot be opened from an agent session on either desktop (OpenClipboard
      error 5)
- [x] T014 Independent review - done as T015 (code review, ACCEPT pending GUI) and T016 (re-review
      of the fixes, ACCEPT pending GUI); its condition (the UNC rows pass) was met by the GUI runs
      (T013). No separate review of the GUI evidence was made.
