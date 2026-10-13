# Fix log: feature 139 - SFTP, nothing replaced without a question

## 2026-10-13

- Source of the work: the final independent review of the SFTP operations (findings C1, C2, M2,
  M3, M5, M6 and the identity note on 138). All of them older than this cycle (present in 0.1.9).
- Spec, plan, tasks written before any code. The plan was widened once (User Stories 4-5): the
  upload direction is restructured like the download of 138, because asking before a replace in
  a loop that still deletes local sources by re-listing would leave the larger loss in place.
- Probe rows written before the code (`specs/133-sftp-server-verify/probe/sftp133_probe.ps1`,
  `fixture133.sh`): UPASKNO, UPASKYES, UPFAIL, UPNEWFAIL, DLFAIL, RENEXIST, UPMV, UPMOVE,
  UPLINK. New helper `Row-Up` (the local panel is the source); the transfer seam is the
  environment variable `TC_SFTP_PROBE_XFER_FAIL`.
- The source changes are written while the final probe chain of the earlier features still uses
  the Debug binaries - no build until it ends. "Before" is measured on the 0.1.9 control build
  for the rows that need no seam (UPASKNO, UPASKYES, RENEXIST, UPMV, UPMOVE, UPLINK); the rows
  that cut a transfer (UPFAIL, UPNEWFAIL, DLFAIL) have no "before" on a build without the seam -
  their old behaviour is read from the code (`OpenWrite(..., TRUNC)`; the CF-17 delete of the
  local file) and recorded as such.

## Measured (2026-10-13 / 14)

- **Before** (0.1.9 control build, `probe/before.txt`): an upload over an existing file
  replaced it without a question (UPASKNO: the server held the new content although nothing
  was asked); Quick Rename of `a.txt` to the existing `b.txt` replaced `b.txt` (it held `AAA`
  afterwards, `a.txt` gone), no message; a move of a local tree whose folder `blocked` the
  server could not create (a file of that name is there) deleted the whole local tree, no
  error; a junction inside an uploaded tree was skipped without a word. The three rows that
  cut a transfer have no "before": 0.1.9 has no seam.
- First draft of the probe sent the keys of the upload rows to the server panel (the library's
  `Key` always reaches the left list): the rows did nothing and "passed" in the before mode.
  Found by reading the dialogs column ("none"); the local source is on the left now.
- The core shows its Copy / Move dialog again after an operation that failed; the probe
  answered OK again and looped (140 dialogs). `Answer` cancels the second appearance.

## Reviews

- First refute-first review (code only, before the build): no critical finding; medium: the
  non-replacing rename relied on OpenSSH's behaviour; the fallback to writing in place was
  taken on any failure to create the temporary file (quota, timeout); accounts that may write
  but not rename could no longer upload; a replaced file became a new inode with mode 0644 and
  the uploader as owner. All fixed.
- Second review (of the rework): a cancel between the two passes truncated the target to zero
  silently; the complete temporary file was deleted before the in-place write was confirmed;
  the case-only rename could still replace another file on a server that folds ASCII only;
  the read-only check ran before the skip decision; a refused replace could not fall back; a
  failed `Stat` did not mark the session dead; a file was sent twice whenever the owner could
  not be set. Fixed: the route is decided on the empty temporary file, before any data.
  The path table of `UploadOneFile` is in `impl-notes.md`, section 8.

## After

- Unit harness 179 / 0; `check_encoding.py` TOTAL 0; Debug build clean.
- SFTP probe, whole (`probe/after.txt`): **PASS 66, FAIL 0, NOT DRIVEN 0** - the rows of 133,
  137, 138 and the eleven rows of 139 (UPASKNO, UPASKYES, UPFAIL, UPNEWFAIL, DLFAIL, RENEXIST,
  RENCASE, UPSYM, UPMV, UPMOVE, UPLINK).
- Not driven against a server (read from the code only): a target owned by another account;
  an account without the right to rename; a server without the posix-rename extension; a lost
  connection at each step; a cloud (OneDrive) folder as the source. Owed to a person: an
  upload of a OneDrive folder; an upload to a server other than OpenSSH.
