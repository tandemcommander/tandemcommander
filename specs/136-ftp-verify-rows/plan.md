# Implementation Plan: FTP rows that 134 did not run

**Branch**: `136-ftp-verify-rows` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

## Summary

The probe and the server of feature 134 are extended (they stay in
`specs/134-ftp-mixed-templates/probe/` - one probe for the plug-in's texts):

- Server: user `jiri-with-accents` (`jiří`) gets `331` and then `230`; a user whose name starts
  with `refuse-u8` / `refuse-cp` gets `530 <accented text>` to `PASS` in that encoding.
- Rows: **BMK** (Connect to FTP Server through the plug-in's menu command: New with an
  accented name; New again - the check box text; Rename - the label; Remove - the question,
  answered No), **PWD** (address with the accented user and no password - the prompt's
  "Connecting to" line), **LOGINU8 / LOGINCP** (address with user and password - the login
  error dialog's reply field), **SAVELOG** (Logs window: the list's item text, Save log through
  the file dialog, the file read back).
- Runs: 0.1.9 (`-Expect before`) and the current build, Czech and English.
- Fixes by what the rows show (plug-in files of 134).

## Technical Context

- `specs/134-ftp-mixed-templates/probe/ftp134_probe.ps1`, `ftp134_server.py`; dialog ids from
  `src/plugins/ftp/lang/lang.rh` (Connect 560: New 572, Rename 573, Remove 574, Close 575;
  subject 601, check box 611; prompt line 623; login error reply 633; Logs 660: list 661, log
  662; command Save log 1207).
- No source change is planned; `src/plugins/ftp/` only if a row fails.

## Constitution Check

Verification feature: no interface, storage or build change. The registry key is restored
(bookmarks made by the probe live there).

## Structure

1. Spec, plan, tasks. 2. Server + rows. 3. Runs before / after in two languages.
4. Fixes if any, review of the fixes, records, local commit.
