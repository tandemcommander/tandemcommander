# Data model - 420-auto-update-install

## Release record (extends 123's `CSalUpdRelease`)

| Field | Source | Rule |
|---|---|---|
| `Version`, `PublishedUtc`, `PublishedText` | 123 | unchanged |
| `HasAsset` | the installer asset (name, state, `browser_download_url` as 123) has `id` and `url` once each | `url` == `SalUpdAssetApiUrl(id)` |
| `AssetId` | asset `id` | decimal, 1..15 digits, no sign, no fraction, no leading zero |
| `AssetSize` | asset `size` | decimal as above; 0 = absent |
| `HasDigest`, `Digest[32]` | asset `digest` | exactly `sha256:` + 64 hex digits (either case) |

A repeated `id`, `size`, `digest` or `url` in the installer asset makes the asset carry no download
data (`HasAsset` FALSE); 123's acceptance of the record does not change.

## Update level (`Update Level`, REG_DWORD in `Update Check`)

| Value | Meaning |
|---|---|
| 0 | notify only (123) |
| 1 | download and offer installation - **default when absent or out of range** |
| 2 | install automatically when the program closes |

## Arm (values in `Update Check`)

| Value | Type | Meaning |
|---|---|---|
| `Install Version` | REG_SZ `<a>.<b>.<c>` | the armed version; absent = nothing armed |
| `Install Digest` | REG_SZ 64 lowercase hex | the digest the installer must have |
| `Install Source` | REG_DWORD | 1 the user (a click), 2 the automatic level |
| `Install Test` | REG_DWORD | 1 armed in test mode |
| `Install Launches` | REG_DWORD | installer launches for this version (0..3; Install Now may count past 3) |
| `Download Refused` | REG_SZ | a version whose downloaded installer failed the signer / signature / version check - not downloaded again (ignored in test mode) |

Invalid or partial values = nothing armed (all are removed together).

### Honoured arm (`SalUpdArmHonoured`)

- source user: always;
- source automatic: the check option on (or test mode) and the level = 2.

### Start-up decision (`SalUpdStartupArmDecision`)

| Condition (in order) | Decision |
|---|---|
| nothing armed | none |
| the running copy is not eligible (portable copy, build tree) | none - the installed copy's arm and files are left alone (review 1) |
| `Install Test` and not test mode now | drop (state + file) |
| not honoured | drop the state (file kept, rule of the clarifications) |
| not test: running version >= armed | done: drop the state + file |
| test: launches > 0 | done: drop the state + file |
| launches >= 3 | give up: nothing is started; the arm is kept with its count (review 1 S1), so a later check at the automatic level does not restart it - the update is only offered (Install Now) |
| (at completion) the installer file fails verification / is missing | drop the state + file |
| (at completion) an installer of the product runs | nothing now (review 1 M1); the arm waits |
| launches > 0 (an installer was started and did not install it) | offer (notification), never started at the start; the arm stays (review 2 S1) |
| otherwise | complete now (*Install Now* route) - only when no other instance of the executable runs in the session (fix-log F1: the arm then belongs to that instance's exit, and the installer would close its windows); otherwise the arm waits |

### Exit decision (`SalUpdExitDecision`)

Install at exit only when: an honoured arm exists, launches < 3, the exit is normal (not
`UnattendedClose`, not `CriticalShutdown`, `SM_SHUTTINGDOWN` 0 - recorded when the main window is
destroyed, because an installer's close resets `UnattendedClose` before the end of the exit,
fix-log F2), this is the last instance of this
executable in this session, the installation is eligible, and the file verifies. Not test-mode
specific (a test arm at a test-mode exit installs; started later without the switch it is dropped).

## Files (`%LOCALAPPDATA%\Tandem Commander\Updates`)

| File | Life |
|---|---|
| `tandemcommander-<ver>-x64-setup.exe.part` | while downloading; deleted on failure, at exit cancel, and at the next start |
| `tandemcommander-<ver>-x64-setup.exe` | verified installer; deleted when superseded, skipped, failed verification, reached, or when a test-mode session starts (re-download) |
| `setup-<ver>.log` | the installer's log of the last launch for that version; deleted with the installer |
