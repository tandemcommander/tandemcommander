# Tasks: 206

- [X] T001 Probe `probe/ren_dir83_probe.ps1` (199's driver, relative-path mode); before: the premise
  not reproducible on NTFS, the 230-letter row a stack overrun; the overwrite row (review) data loss
- [X] T002 `src/plugins/renamer/rendlg3.cpp` (`CheckAndCreateDirectory`, `PathBelowRoot`,
  `FolderPartIsShortNameOfOther`), `rendlg2.cpp` (`BuildScript`), `utils.h`
- [X] T003 After 10 / 0; 199's probe 6 / 0, 196's 8 / 0; two reviews; records
- [ ] T004 Feature 207 (from the first review): `MoveFile`'s `dir[MAX_PATH]` overrun on Undo / "Remove source path"
