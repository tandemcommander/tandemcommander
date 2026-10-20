# Closing report - 258-sftp-drop-folder-upload
Backlog item: sftp-replace-keeps-links-acls-drop-dirs - SFTP upload replace: links split, ACLs lost, drop folders fail, .tcpart left
Outcome: closed

## What changed

- **Drop folders** (`src/plugins/sftp/operats.cpp` `UploadDropRoute`): when the server refuses the
  target's `lstat` for want of a right (live session), the file is created only by
  WRITE | CREAT | EXCL | TRUNC under its own name - never opened over an existing file on a
  conforming server, no fallback, no temporary file. A size request refused the same way is
  answered by the server's acknowledgments of every byte and of the close
  (`SftpUploadConfirmation`, every route). A failed or stopped drop upload removes its partial
  file once, or the box says one may remain.
- **Limits stated**: the overwrite question (`ConfirmOverwriteRemote`) says other hard links keep
  the old content and the ACL / extended attributes are not carried over (SFTP v3 cannot report
  or set them; 139's atomic replacement is kept).
- **Left temporary files**: a `.tcpart-*` whose removal a lost connection prevented is remembered
  on the session (`CSFTPSession::LeftTemps`, memory only, 16) and offered (Yes / No) at the next
  upload on that session; checked as a regular file of our name form before deletion; only-copy
  temps are never recorded.
- Pure rules in `sftputils.h/.cpp` (`SftpUploadConfirmation`, `SftpTargetStatRefused`,
  `SftpIsUploadTempPath`) with 22 harness checks. No new UI strings (English literals as 139),
  no plug-in interface change.

## Measurements (before / after, commands)

- Before, build of 2807bbc4, `probe/sftp258_probe.ps1` on the hidden desktop with the paramiko
  test server `probe/dropsftp.py`: PASS 7, FAIL 5 - every drop upload "Permission denied", the
  question silent about links / ACL, a `.tcpart-*` left after a cut connection
  (`probe/result_before.txt`). OpenSSH with a 0733 / 1733 folder already worked (replay).
  Hard-link split measured on the OpenSSH container by a replay of temp + posix-rename.
- After: **PASS 20, FAIL 0** (`probe/result_after.txt`: DROPNEW, DROPEXIST, DROPMOVE, DROPDIR,
  DROPFAIL, DROPDIR2, DROPHOLE, DROPNOEXCL, REPL, CUT + END rows); registry restored + identical.
- Negative controls: CUT with the offer disabled -> FAIL (`probe/result_negative_cut.txt`);
  DROPNOEXCL without TRUNC -> FAIL, `NEW-NXOLDOLDOLD` (`probe/result_negative_noexcl.txt`);
  DROPEXIST with the exclusive create mutated away -> FAIL (review 1's run); DROPHOLE on the
  reverted change's build -> FAIL (review 2's run).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL 0 finding(s).
- `build.cmd` (Debug x64): BUILD SUCCEEDED; SFTP sources recompiled with /W3, no warning.
- SFTP harness (`src/plugins/sftp/test/build_and_run.cmd`): 239 passed, 0 failed.
- saltests: not run - nothing in the core or `src/common/` changed.
- 133's SFTP probe on the OpenSSH container (regression): PASS 76, FAIL 0, after every change
  (`probe/regress_133.txt`, last run after the review 3 fixes).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD-1 DROPEXIST tested the server - test server made permissive;
  SHOULD-2 the claim depends on EXCL - CHANGELOG qualified; NOTE-4 folder re-upload - tried.
- Review 2: MUST-1 the folder re-upload change let a Move delete an empty local folder that never
  arrived (also on OpenSSH) - reverted; rows DROPDIR2 / DROPHOLE guard it; Inbox item.
- Review 3: no MUST. SHOULD-1 a server ignoring EXCL got the new bytes over the old tail,
  "confirmed" - TRUNC added, row DROPNOEXCL; NOTE-3 low-memory paths of the offer fixed; NOTE-1
  contract row D2a; NOTE-2 / NOTE-4 recorded.
- Details: `fix-log.md`, section *Review*.

## Owed to a person (with the new person-step items)

- `sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on` - a real upload-only service
  (SFTPGo / hosted drop box) and an ACL on a replaced file.

## New Inbox items (slug - title)

- `sftp-a-copy-posted-right-after-a-failed-upload-and-its` - SFTP: a Copy posted right after a
  failed upload and its reconnect may open nothing
- `sftp-a-folder-uploaded-again-into-an-upload-only-folder` - SFTP: a folder uploaded again into
  an upload-only folder fails with Cannot create directory
- `sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on` - SFTP drop folder on a real
  upload-only service and an ACL on a replaced file (258) (person step)
