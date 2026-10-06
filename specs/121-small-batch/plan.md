# Implementation Plan: the small batch (feature 121)

**Branch**: `121-small-batch` (from `120-pictview-leftovers`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre121`, without `Intermediate`). Code reading per item (R1-R11); the R4 code-page measurement over `translations/*/salamand.slt` |
| S1 core texts | R4 `LoadStrU8` (`worker.cpp`, `safefile.cpp`); R3 clipboard: last error kept, echo not skipped, `CopyTextToClipboardU8Report` / `WReport` / `ShowClipboardCopyError` (`salamdr4.cpp`, `consts.h`), every user copy command converted, UNC refusal remembered (`fileswn9.cpp`) |
| S2 message box | R2 `src/common/salmsgwrap.h` (`SalMsgWrapBreaks`, `SalMenuLabelToTitle`), `msgbox.cpp` `InsertEOLsAux` |
| S3 Find | R1 `src/common/salfindtext.h`; `find.h` (`LOOKIN_TEXT_LEN` / `LOOKIN_TEXT_CHARS`, `CSearchForData::Dir` heap), `find.cpp`, `finddlg1.cpp` (constructor, Validate, Transfer limit, BuildSerchForData, Browse) |
| S4 plug-ins | R5 Disk Map (`GUI.LogWindow.h`, `splunicode.h` `SplDisplayTextToWAlloc` / `SplU8CopyTrunc` / `SplU8TrimTornTail`); R6 `splfiledlg.h`; R7 `filecomp.cpp` `Release`; R9 `checksum/dialogs.cpp`; R10 `salftpsecret.h` `SalFtpTypedLoginTooLong`, `ftp/fs2.cpp`, `fs5.cpp`, `ctrlcon1.cpp`, `operats2.cpp`; R11 `regedt/finddlg2.cpp`, `ftp/dialogs2.cpp` |
| S5 translation | R8 `translations/romanian/zip.slt` row 1060 + pin `ui-overrides.json` `zip/romanian` |
| S6 tests and gates | saltests `TestSmallBatch121`; strict guard; Debug and full Release builds; probe `probe/batch121_probe.ps1` written (GUI runs owed); records |

No plug-in interface change (107), no registry format change, no new string.
