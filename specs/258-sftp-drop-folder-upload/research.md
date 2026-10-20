# Research - feature 258

## R1 Where does a drop folder fail?

- Decision: only on servers that refuse `stat` / `lstat` in the folder. Handled on a permission
  status of the target's `lstat` (live session).
- Rationale: measured - OpenSSH with a Unix write-only folder (0733 / 1733, owned by root)
  answers "no such file", lets the account create, `stat` and rename its own file: 139's route
  works there. The paramiko model of an upload-only folder (refuses stat, lstat, fstat, opendir,
  rename, remove, setstat) failed every upload at the first `lstat` ("Permission denied"),
  before any data - not at the size confirmation as the review supposed.
- Alternatives: treat "no such file" after the upload as drop too (a server that hides files)
  - rejected: indistinguishable from a file that vanished; kept as "not confirmed".

## R2 How to create without knowing whether the target exists?

- Decision: `OpenWriteNew` (WRITE | CREAT | EXCL) under the target's name; refused = the item
  fails; no fallback to `OpenWrite` (it would truncate an unknown file) even on OP_UNSUPPORTED.
- Rationale: SSH_FXF_EXCL is in SFTP version 3 ("the request fails if the file already
  exists"); it is the only way to keep 139's "nothing replaced without a question" when the
  question cannot be asked.
- Alternatives: temporary file + non-replacing rename - the server refuses rename in such
  folders (SFTPGo without "rename"), and "a plain rename never replaces" is OpenSSH's behaviour,
  not the protocol's (139).

## R3 Confirming an upload whose size the server will not report

- Decision: confirmed when the size request is refused with a permission status (live session),
  the bytes acknowledged equal the local size and the close was confirmed.
- Rationale: `libssh2_sftp_write` returns the bytes the server ACKED (sftp.c: "Return TOTAL
  bytes acked so far"); each write request got SSH_FX_OK; `CloseHandleChecked` reports the
  close's status. That is the protocol's own confirmation; the `stat` is a second check where
  available.
- Alternatives: refuse (the item would keep failing - the item says "succeeds (or says why)").

## R4 Hard links and ACLs

- Decision: stated in the overwrite question, not handled.
- Rationale: SFTP version 3 attributes have no link count and no ACL; the listing's long name
  carries a link count only by OpenSSH's convention, and the draft says clients SHOULD NOT parse
  it. Writing in place to keep links would break 139's rule (a failed write leaves a torso).
- Measured: OpenSSH container, `a.txt` + hard link `b.txt`, replaced by temp + posix-rename ->
  `a.txt` new, `b.txt` old.

## R5 Finding left temporary files

- Decision: memory record on `CSFTPSession` (which survives the FS's reconnect: `EnsureConnected`
  reuses the object) of temporary files whose removal failed because the session was dead;
  offered at the start of the next `SFTPUploadToFS`. At most 16 kept (more are rare; each was
  named in its box).
- Rationale: nothing stored (registry = maintainer-owned), never offers a file another upload
  may be writing, never offers the only copy of new content (139 keeps those on purpose and
  names them) nor a file the server refused to delete on a live session (asking again would not
  help).
- Alternatives: a search of listings for `.tcpart-*` (finds files of earlier runs, but may
  break another upload in progress and asks during navigation) - left as a limit.

## R6 Test server

- Decision: `probe/dropsftp.py`, paramiko 5 `SFTPServerInterface` on 127.0.0.1, ECDSA host key
  made at start, password login, root under `%TEMP%`; `/drop` model, `/cut` (drops the
  transport at the close of a written file while `cut\.armed` exists), `/pub` plain.
- Rationale: OpenSSH's `sftp-server -P` denies requests for the whole session (the panel could
  not even open: `ChangePath` needs `stat`); a per-folder model needs an own server. libssh2
  (WinCNG) negotiates ecdh-sha2-nistp256 / ecdsa-sha2-nistp256 with it (measured).
