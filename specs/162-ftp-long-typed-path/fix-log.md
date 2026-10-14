# Fix log: 162 - can a typed FTP path be cut at FTP_MAX_PATH? (measured: no)

Backlog: `specs/NEXT-WORK.md` item 13 (queue 104, entries 3 and 4; 116, 121).

## Premise

121's records (by reading): the plug-in copies a typed server path into `Path[FTP_MAX_PATH]`
(301) with `lstrcpyn` - a path over 300 bytes would be cut and the panel would go into another
folder; `ChangePath` with a connection open was not examined for the cut user part. A patch was
prepared (both branches of `fs2.cpp` `ChangePath` refuse with `IDS_TOOLONGPATH`) - not applied:
measure first.

## Measured

`probe/ftp_long_path_probe.ps1` on the current build (Debug x64 at 161), 134's FTP server on
127.0.0.1:2134, Czech; an ASCII path `/d/xxx...` typed in Change Directory with a trailing slash:

| Row | Path | Server got | Result |
|-----|------|-----------|--------|
| FIT | 200 B | CWD of the whole path (550, then `/d`, `/`) | whole |
| EDGE / EDGE-OPEN | 242 B (user part 259) | CWD of the whole path | whole |
| OVER / OVER-OPEN | 243 B (user part 260) | nothing | the core: "Zadaná cesta je příliš dlouhá." |
| FTPMAX | 299 B | nothing | the same |
| LONG / LONG-OPEN | 400 B | nothing | the same |

PASS 16, FAIL 0, NOT DRIVEN 0; registry restored + identical (C552FF47...).

Why (by reading, every route):
- `CFilesWindow::ChangePathToPluginFS` (`fileswn2.cpp`) refuses a user part of `MAX_PATH` bytes
  or more, `ChangeDir` (`fileswn3.cpp`) the same for a typed path ("plugins do not support longer
  paths"), and `ChangeAndListPathOnFS` copies the user part into `user[MAX_PATH]` before it calls
  the plug-in's `ChangePath` - so the plug-in never sees more than 259 bytes of user part; the
  path inside it is shorter still. `FTP_USERPART_SIZE` is 610 and `FTP_MAX_PATH` 301: neither cut
  is reachable, with or without an open connection (the "cut-user case" too).
- A bookmark's *Initial path*: the field takes at most 300 bytes (`EditLine` refuses longer, 104),
  `ChangePath` copies it whole into `Path`.
- The F5 target (`fs5.cpp` `CopyOrMoveFromDiskToFS`, `tgtPath[FTP_MAX_PATH]`): the core's target
  field takes 259 bytes - measured by 121 (batch121_probe rows P4/P5).
- Find *Look in*: `CSalPathBuf` has no maximum - `Set` / `AddBackslash` fail only on low memory,
  where the trace and the stop are right. 121's "near the program's maximum" was a wrong premise.
- A custom proxy-script line: 116 sized `FTPLOGINCMD_MAX_SIZE` for a command with every variable
  at its maximum twice (`static_assert` on the built-in lines); only a line the user writes with
  hundreds of literal characters exceeds it. Accepted, not changed.

## Decision

No code change. The prepared refusal would be dead code; the core's refusal is the program's
rule (`IDS_TOOLONGPATH`, nothing sent).

## Incident on the way

The first run of the probe (generated from 134's) lacked the registry backup block: its restore
failed with an empty `$existed`, the product key stayed with the probe's settings (Czech, hot
keys, an FTP option). Restored by hand from a leftover verified export
(`%TEMP%\tc093_dlg_backup.reg`, hash C552FF47... = the verified state): delete, import, export,
hash identical. The probe now backs up first; its second run restored the key itself.

## Review

Not needed for a change that is not made; the measurement and the reading are in this log.
