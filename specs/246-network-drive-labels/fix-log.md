# 246 — Network drive labels and disconnected-drive icons: fix log

Running log (newest at the bottom). Evidence lives in `analysis.md` and `probe/`.

## 2026-10-18 — start

- Source: a user's report (Czech, by e-mail/issue, relayed by the maintainer): a mapped
  SMB drive (Samba server) has a name in Windows ("Archiv") but Tandem Commander shows
  its UNC path (`\\SHARE_SAMBA\Share\Storage`); and the icon of such a drive does not
  change to the disconnected icon when the drive is disconnected. Same in Altap Salamander.
- Pre-analysis in the session (read-only):
  - drive menu text for `drvtRemote` is the UNC path by design
    (`src/drivelst.cpp:1816-1837`), tooltip copies it (`:2724`);
  - `DriveText + 2` is also the remote name handed to `RestoreNetworkConnection`
    (`:2455`) — the label must not replace it;
  - `drv.Accessible = (mask & i) != 0` (`:1753`): only a remembered connection absent from
    `GetLogicalDrives()` counts as disconnected; `GetDriveIcon` picks 31/33
    (`src/salamdr1.cpp:1053`);
  - the nethood plugin is unrelated (own `net:` FS item, no hook for A–Z items; off by default).
- Branch `246-network-drive-labels` created; three independent agents launched:
  static analysis of the text path, static analysis of accessibility/icon/refresh,
  empirical measurement of Windows behaviour (scratch only, cleanup required).
