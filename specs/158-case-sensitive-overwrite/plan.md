# Plan: 158

`provenOther = SalFileIdMatch(srcId, tgtId) == simDifferent` in the identity blocks of
`CFilesWindow::RenameFileInternal` (`fileswn5.cpp`) and `DoMoveFile` (`worker.cpp`); the case-only
exclusion of the overwrite and of the 8.3-name clean-up yields to it. Constitution I-VI: PASS.
