# Research - 421

## R1 When may the automatic install start?

- **Decision**: when `SalUpdSilentInstallDecision` returns *now*: the arm is the automatic level's
  (source automatic), honoured (check on or test mode, level automatic), `Launches <= ConfirmedAt`
  and `< SALUPD_MAX_LAUNCHES`, the copy is eligible, the version is newer than the running one (or the
  arm is a test arm in a test session), this is the last instance, no product installer runs,
  `DecideCloseApp() == scadAgree`, at least 30 s since the last keyboard/mouse input (any program;
  `GetLastInputInfo`) unless the user asked for the check, and it was not started in this session for
  this version.
- **Rationale**: `DecideCloseApp` is the exact rule by which the program lets an installer close it
  without asking (080/088); starting an installer that the program would then decline to close is
  pointless. The idle wait keeps the program from closing under the user's hands. The 420 launch
  count and confirmation make a declined or cancelled installer never repeat on its own.
- **Alternatives**: a countdown window with *Postpone* (rejected: the maintainer asked for no window);
  start at once without idle (rejected: typing into a window that disappears); only at exit (420 -
  what the maintainer asked to change).

## R2 Which launch kind?

- **Decision**: `UpdInstall_InstallNow` (kind *now*: progress window, `/CLOSEAPPLICATIONS
  /RESTARTAPPLICATIONS`) for both Download & Install and the automatic install. It re-verifies the
  file, counts the launch, restores the arm from before after a failure (`SalUpdArmAfterFailedNow`)
  and reports failures; the restart brings the program back after the update.
- **Rationale**: one tested route (420 probes S/B rows, e2e). For the automatic install the arm from
  before is the automatic arm, so after a failure the next start offers the update (susaOffer) - never
  a loop.

## R3 Download & Install on a metered connection

- **Decision**: downloads (an explicit click is consent). The worker gets a flag that skips the
  metered test only for this request; background downloads keep 420's rule.

## R4 The level change on the open notification

- **Decision**: pure rule `SalUpdNoticeLevelChange(form, level, downloadOffered)`:
  classic + notify → nothing; classic + offer/automatic → start 420's flow (download, or a verified
  installer at once) when Download & Install would be offered, else nothing; offer + notify → the
  classic form; offer + offer → nothing; offer + automatic → plan the automatic install, close the
  window.
- **Rationale**: the flow of 420 (`StartUpdateFlow` with the classic form open) already replaces the
  classic form by the downloaded form when the download ends; the automatic branch of
  `ShowDownloadedUpdate` closes our classic form and starts the silent wait.

## R5 Strings and resources

- **Decision**: six new strings in free slots 14007-14012 of bundle 875 (the bundle of 420's update
  strings 14002-14006); `IDS_UPDATE_LEVEL_AUTO` changed (its translations get `english_fallback`);
  `IDS_UPDATE_HINT_AUTO` (14154) and `IDS_UPDATE_BTN_OK` (14152) removed (single strings, no bundle
  removed - rule 084). The label of the drop-down is dialog text in `IDD_UPDATENOTICE`.
- Access keys of the form: `&Download`, `Download && &Install`, `Remind Me &Later`, `&Skip This
  Version`, `&Check for a new version at start-up`, `Wh&en a new version is found:`,
  `Cancel Do&wnload`.

## R6 Probe

- **Decision**: a new hidden-desktop probe in the style of 420's `autoupd_probe.ps1` (copied helpers),
  driving the window by posted messages (`BM_CLICK`, `CB_SETCURSEL` + `CBN_SELCHANGE`), reading the
  stored level and the run log seam `TC_UPDATE_PROBE_RUNLOG`; a Debug seam `TC_UPDATE_PROBE_IDLE_MS`
  replaces the 30 s idle time (and lets a row force "the user is busy" with a huge value).
