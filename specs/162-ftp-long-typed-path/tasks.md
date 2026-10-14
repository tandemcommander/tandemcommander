# Tasks: 162

- [X] T001 Probe `specs/162-ftp-long-typed-path/probe/ftp_long_path_probe.ps1` (134's server, rows at the boundary, 299, 400; first connect and connection open)
- [X] T002 Run it on the current build - the first run's registry restore failed (the probe lacked the backup block; restored by hand from a verified export, hash identical), fixed in the probe, run again: 16 / 0
- [X] T003 Read every route into the plug-in's `ChangePath` and the F5 target (`fs5.cpp`) for the user part's length
- [X] T004 Find *Look in* (`find.cpp`, `CSalPathBuf`) and the proxy-script line (`ctrlcon1.cpp`, `FTPLOGINCMD_MAX_SIZE`)
- [X] T005 Decision: no reachable cut - no code change; records (fix-log, FEATURE-HISTORY, NEXT-WORK item 13)
