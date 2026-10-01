# Quickstart: verifying feature 085

Automated evidence (run by the implementation session, see `fix-log.md`):

| What | How | Expected |
|---|---|---|
| F1 rule | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `0 failed` (group `TestUrlPasswordStrip085`) |
| F2 fetch | `specs\085-privacy-defect-fixes\probe\fetch_probe.cmd` | `RESULT: PASS` |
| F2 negative control | `fetch_probe.cmd pre085` | `RESULT: FAIL`, 9 failed (UA, cookie on redirect, Authorization on 401, 404/500/401 accepted) |
| F4 single definition | `rg -c "put_IsCustomCrashReportingEnabled" src --glob "!src/common/dep/**"` | one file, one hit |
| F6 import | `python -c "import sys; sys.path.insert(0,'tools'); import check_runtime_deps as c; print('bcrypt.dll' in c.pe_imports(r'build\tandemcommander\Debug_x64\tandemcommander.exe'))"` | `True` |

## Owed to a person (GUI)

These need the application on screen. Use a **test profile**: back up
`HKCU\Software\Tandem Commander` first (`reg export "HKCU\Software\Tandem Commander" tc-backup.reg`),
and restore it afterwards (`reg delete … /f` then `reg import tc-backup.reg`).
Close your own Tandem Commander before starting the Debug build.

### G1 — F1, five entry points (SC-001)

Use a password you will search for, e.g. `Zz085secret`, and any FTP server
(a non-existent host is enough for the history checks — the entries are
stored when the dialog is confirmed).

1. FTP Quick Connect (Ctrl+F7 → Quick Connect): Address
   `ftp://alice:Zz085secret@127.0.0.1/pub` → Connect. Reopen the dialog: the
   Address drop-down lists `ftp://alice@127.0.0.1/pub`.
2. Change Directory (Shift+F7): `ftp://alice:Zz085secret@127.0.0.1` → OK.
   Reopen: the drop-down shows `ftp://alice@127.0.0.1`.
3. F5 Copy from a disk panel, target `ftp://alice:Zz085secret@127.0.0.1/in` →
   cancel the copy once it starts. Reopen F5: the target history shows
   `ftp://alice@127.0.0.1/in`.
4. Command line: `echo ftp://alice:Zz085secret@127.0.0.1/f` + Enter. The console
   prints the full text (the command ran unchanged); the command-line drop-down
   shows `echo ftp://alice@127.0.0.1/f`.
5. Find (Alt+F7), Look in: `ftp://alice:Zz085secret@h` → Find (nothing is
   found). The Look-in drop-down of the still-open dialog shows `ftp://alice@h`.
6. Options → Save Configuration, then `reg export "HKCU\Software\Tandem Commander" after.reg`
   and search `after.reg` for `Zz085secret`: **0 hits**. Also *Export
   Configuration* and search that file: 0 hits.
7. A real connection with a password in the address (a test server, e.g. the
   SFTP container of feature 051 does not do FTP — any FTP server you have)
   still logs in.

### G2 — F1, cleaning of old entries (US1 scenario 5)

1. With 0.1.8 installed (or by importing a `.reg` with a value
   `ftp://alice:Zz085secret@host` under `…\0.1\Configuration\Change Dir History`
   and under the FTP plugin's `Host Address History`), start the Debug build.
2. Open the Change Directory and Quick Connect drop-downs: the entries are
   shown without the password.
3. Save the configuration; export; search: 0 hits.

### G3 — F3 (SC-003)

Open in the Markdown Viewer (F3 on the file) each of
`specs\085-privacy-defect-fixes\probe\autonav_*.md` and wait 30 s:

- `autonav_external.md` — no browser window opens; then click the link: it
  opens once.
- `autonav_relative.md` — no second viewer window; clicking the link opens
  `autonav_target.md` in one.
- `autonav_local.md` — no message box.

(Optionally, the feature-081 probe `specs\081-mdview-shared-webhost\probe\mdview_probe.ps1 -Scenario hostile`
with `-Fixtures` pointed at a folder holding these files asserts "one viewer
window, no extra dialog" automatically; it drives the build against the
current user's registry, so use the backup above.)

### G4 — F7 (SC-006)

1. Options → Configuration → Security → *Use Master Password*, set one; restart
   (so it is not entered in the session).
2. SFTP → Connect dialog → a bookmark → type a password, *Save password* on →
   *Save* (or Connect). The Master Password prompt appears → **Cancel**.
3. *Save password* is now unchecked. Save the configuration; under the SFTP
   plugin's bookmark key there is no `Password` value for that bookmark.
4. Repeat with the correct Master Password: saved, encrypted (the value
   starts with the encrypted-blob signature, not the scrambled one).
5. Repeat for a key passphrase with *Save passphrase*.

### G5 — F6 (SC-005)

With a configuration saved by 0.1.8 that holds FTP/SFTP passwords with and
without a Master Password: start the Debug build, connect to each bookmark
without typing the password — all log in. Save a new password, restart,
connect — it logs in.

### G6 — F4 (US6)

1. Open a `.md` file and a `.cpp` file in the same session: both render.
2. With 0.1.8 running at the same time and having shown a `.md` file, open a
   `.md` file in the new build: expected "engine unavailable" and the window
   closes (the accepted consequence); after closing 0.1.8 it renders.
