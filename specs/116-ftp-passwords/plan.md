# Implementation Plan: FTP passwords (feature 116)

**Branch**: `116-ftp-passwords` (from `115-undelete-leftovers`, 79113272) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre116` = a copy of `Debug_x64` = HEAD 79113272, without `Intermediate` folders). The subclass primitive measured by a scratch program (`probe/m116_subclass.cpp`, never-shown window); the dialogs, the wire, the stored format, the login buffers by code reading (`research.md`) |
| S1 helper | `src/common/salftpsecret.h` (header-only, includes `splunicode.h`): `SAL_FTP_SECRET_MAX_CHARS` 100, `SAL_FTP_SECRET_BUF` 301, `SalFtpWorstUtf8Bytes`, `SalFtpFieldShowsStored` (the stored-bytes rule) |
| S2 buffers | `ftp.h`: `PASSWORD_MAX_SIZE` / `ACCOUNT_MAX_SIZE` / `USERPASSACCT_MAX_SIZE` = `SAL_FTP_SECRET_BUF`; `FTPLOGINCMD_MAX_SIZE` + static_assert on the longest built-in line; `ftp2.cpp` `ProcessProxyScript` expands into it; `ctrlcon1.cpp` / `operats2.cpp` login buffers; `operats6.cpp` passes the worker's real 1,001-byte buffer (static_assert); `precomp.h` includes the helper |
| S3 dialogs | `dialogs1.cpp`: `CPasswordEditLine` attaches with `AttachToWindowKeepKind`; `FTPSecretEditLine` (EditLine + 100-unit limit) for every secret field; `FTPFieldKeepsStoredValue` / `FTPFieldKeepsEncryptedValue`; `FTPShowPasswordOfEdit` (UTF-16 read, UTF-16 composition, `CopyTextToClipboardW`, wipes). Connect dialog: fill + kill-focus rule; Configuration anonymous password. `dialogs8.cpp`: `CEnterStrDlg` (hidden = secret), `CLoginErrorDlg` (five fields by the rule, the backup copy wiped), `CProxyServerDlg` (fill, rule, wipe), both *Show password* handlers |
| S4 tests | saltests `TestFtpSecret116` (worst cases of 100 units fit 301 bytes - core and plug-in converters agree, round trip, 20,000 random texts; 101 CJK units do not fit; the old 101-byte refusal; the 0.1.8 code-page form re-reads as other bytes; the rule's table) |
| S5 probe | `probe/ftppwd_probe.ps1` + `probe/ftplog_server.py` (rows uni, type, set, show, long, prompt, tab, legacy, compat; `-Expect before`; `-OldExe`; `-Clipboard`); the scramble port checked against the product's `UnscramblePassword` (scratch); written, GUI runs pending |
| S6 gates | Debug + full Release builds, saltests, strict guard, BOM / CRLF, clang-format of the changed lines; records (fix-log with the proposed CLAUDE.md entry, CHANGELOG, NEXT-WORK) |

No plug-in interface change (107), no new string, no registry format or configuration version
change. PRIVACY.md unchanged (reason in fix-log).
