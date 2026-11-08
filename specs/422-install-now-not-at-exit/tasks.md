# Tasks: Updates install right away, never at exit

- [X] T001 fix-log with the measurement at 95dc740e in `specs/422-install-now-not-at-exit/fix-log.md`
- [X] T002 [US1] `SalUpdSilentInstallDecision` without idle; remove `SALUPD_SILENT_IDLE_MS` in `src/common/salupdinstall.h`; saltests in `src/saltests/saltests.cpp`
- [X] T003 [US1] `TrySilentUpdateInstall` / `ShowDownloadedUpdate` without idle and "user asked"; the notification blocks only with its level list open (`UpdateNotice_IsChoosing`) in `src/mainwnd3.cpp`, `src/upddlg.cpp`, `src/upddlg.h`, `src/mainwnd.h`; remove `UpdInstall_SilentIdleNeededMs` in `src/updinstall.cpp/.h`
- [X] T004 [US2] remove the exit install (`UpdInstall_PrepareExit`, `UpdInstall_RunAtExit`, `SalUpdExitDecision`, `sulkExit`) in `src/updinstall.cpp/.h`, `src/salamdr1.cpp`, `src/common/salupdinstall.h`, saltests
- [X] T005 [US2] remove *Install When I Close* (`IDC_UPDN_INSTALLEXIT`, `IDS_UPDATE_BTN_INSTALLEXIT`, `UpdInstall_ArmByClick`, `UpdInstall_CheckReady`, `UpdInstall_ExitArmAvailable`, `SalUpdExitArmAvailable`) in `src/upddlg.cpp`, `src/lang/lang.rc`, `src/lang/lang.rh`, `src/lang/texts.rc2`, `src/texts.rh2`, `src/updinstall.*`, `src/common/salupdinstall.h`, saltests
- [X] T006 [US2] `UpdInstall_OnInstallerEnded`: OK-only report, automatic plan kept OFFERED, `IDS_UPDATE_INSTALL_LATER` removed in `src/updinstall.cpp`, `src/lang/texts.rc2`, `src/texts.rh2`
- [X] T007 [US3][US4] start-up completion and launch-count protection kept; verify the lock-out trap rows in the probe
- [X] T008 probe `specs/422-install-now-not-at-exit/probe/install422_probe.ps1` (from 421's): immediate install with input, waits, never at exit, offer form without the button, failed Install Now, start-up completion, the lock-out trap (kill after the silent launch / after the completion, restart x3 with and without a check)
- [X] T009 build, saltests, encoding guard; translations (stop-rules 2.13); `build.cmd full`
- [X] T010 manual, `PRIVACY.md`, contract notes (420 / 421)
