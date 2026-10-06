# Tasks: feature 116

- [X] T001 Research (research.md): the code-page subclass (scratch measurement `probe/m116_subclass.cpp`), *Show password*, the wire (USER/PASS/ACCT bytes, no UTF8 negotiation), the stored format (scramble length field, AES, registry), older versions and longer values, the login command buffers, *Retry*; preserve `Debug_x64_pre116`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 S1 `src/common/salftpsecret.h`; listed in `saltests.vcxproj`
- [X] T004 [US3] S2 buffers (`ftp.h`, `ftp2.cpp`, `ctrlcon1.cpp`, `operats2.cpp`, `operats6.cpp`, `precomp.h`)
- [X] T005 [US1] S3 `CPasswordEditLine` kind-keeping; `FTPSecretEditLine` at every secret field
- [X] T006 [US2] S3 `FTPShowPasswordOfEdit` (both dialogs)
- [X] T007 [US4] S3 the stored-bytes rule: Connect dialog kill focus, login-error dialog, proxy server dialog (first by `EM_GETMODIFY`, replaced by the text comparison - research 4)
- [X] T008 S4 saltests `TestFtpSecret116` (14,401 -> 14,440 / 0; 14,441 after T015)
- [X] T009 S5 probe written: `probe/ftppwd_probe.ps1` (parses), `probe/ftplog_server.py`; the probe's scramble port checked against the product's `UnscramblePassword`
- [X] T010 Gates: Debug + full Release builds, saltests 14,440 / 0, strict guard 0, BOM / CRLF, clang-format of the changed lines
- [X] T011 Hostile re-read of the diff (fix-log)
- [X] T012 Records: fix-log (with the proposed CLAUDE.md entry), CHANGELOG `[Unreleased]`, NEXT-WORK (item fixed by 116 - GUI runs pending); PRIVACY.md decision; no commit
- [X] T015 Code-only review (ACCEPT pending GUI): S1 SOCKS 5 255-byte limit (dialog refusal, no cut at send), N2 login-error dialog restores on a refusal, 104 B1 leftover (proxy dialog stored after a refusal), N1 wipes (worker buf, EditLine UTF-16 copy, SplWToU8 failure) + corrected record, N3/N6 recorded, N4 CHANGELOG, N5 probe (clipboard history / Master Password refused, clipboard restored in finally); Debug + full Release rebuilt, saltests 14,441 / 0, guard 0
- [X] T013 [US1]-[US4] Probe on `Debug_x64_116` (51 PASS / 0 FAIL / 4 NOT DRIVEN) and `Debug_x64_pre116` (every defect shown; the `long` rows re-run after a probe-only expectation fix: 10 / 0) - hidden desktop, 2026-10-06, registry 1AB614304771DBE0 before and after every run (fix-log "GUI results")
- [X] T014 Regression scope: no shared code changed (winliblt, splunicode, the core untouched - only the FTP plug-in, a new header and saltests), so no other feature's probe is affected; 104's `ftp-b1` rows are superseded by this probe (its LONGPWD / CONNECT rows now accept the 60-letter password by design; LONGUSER, OVER and LEGACY are repeated here as `long USER`, `long OVER`, `legacy *`)
