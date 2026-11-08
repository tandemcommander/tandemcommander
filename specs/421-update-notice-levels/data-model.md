# Data model - 421

No stored value is added or changed in meaning. Stored state stays 420's
(`specs/420-auto-update-install/contracts/stored-state.md`): `Update Level` is now also written by the
notification's drop-down.

## In-session state (not stored)

### Install request (Download & Install) - `src/updinstall.cpp`

| Field | Meaning |
|---|---|
| `Requested` | a Download & Install click waits for its download |
| `Version` | the version it is for |
| `StartedDownload` | this request started the download (cancel stops it); FALSE when 420's download of that version was already running |

Transitions: click → requested (download started, or already running) → download done: taken by the
main window → `InstallNow` (ok) or failure message; cancel / Skip / window closed → dropped (download
stopped when `StartedDownload`).

### Download progress - `src/updinstall.cpp`

`Received` / `Total` bytes of the running download (guarded by the worker's critical section);
`Total` = the release's asset size.

### Silent install wait - `src/mainwnd3.cpp`

| Field | Meaning |
|---|---|
| `Pending` | the automatic install waits for its moment |
| `Release` | the release (version + digest) |
| `UserAsked` | the check was asked for by the user (no idle wait) |
| `TriedVersion` | the version already started in this session (never a second time) |

## Pure rules (`src/common/salupdinstall.h`)

- `SalUpdDownloadInstallOffered(eligible, release, refused, testMode)` → BOOL
- `SalUpdNoticeLevelChange(form, newLevel, downloadOffered)` → none / classic / flow / automatic
- `SalUpdSilentInstallDecision(arm, honoured, eligible, testMode, running, lastInstance, installerRunning, closeAgree, idleMs, userAsked, tried)` → now / wait / never
- `SalUpdSilentInstallPlanned(hasArm, arm, version)` → BOOL (the automatic level installs this arm silently, else shows the offer form)
