# Tasks: 217

- [X] T001 Probe `probe/sftp217_probe.ps1` + `probe/fakessh.py`; 8 failure kinds and 15 connections clean
- [X] T002 Audit (plug-in + libssh2); FLIPSIG reproduces the leak and the exit that does not end
- [X] T003 `libssh2/src/session.c`, `wincng.c`: host key freed, secret / e trimmed, CNG handles freed
- [X] T004 After 18 / 0; 20 connections 40 / 0; 205 14 / 0; review; records
- [ ] T005 Owed: ~1,500 connections to show the 1-in-256 failure gone (not driven)
