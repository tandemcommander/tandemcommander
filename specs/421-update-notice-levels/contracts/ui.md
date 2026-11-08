# Contract - user interface (feature 421; supersedes the forms table of 420's contracts/ui.md)

## Configuration > General

Unchanged, except the third level's text: *Install it automatically as soon as it is downloaded*.

## Notification (IDD_UPDATENOTICE) - two forms

Rows top to bottom: header band, versions, *Released*, *Release notes*, hint (3-4 lines), *Check for a
new version at start-up*, *Wh&en a new version is found:* + drop-down (Notify me only / Download it
and offer installation / Install it automatically as soon as it is downloaded), buttons.

| Form | When | Buttons (left to right) | Hint line |
|---|---|---|---|
| classic, installed copy, Download & Install offered | level 0; or no download yet (metered, failed, check the user asked for while downloading) | *Download && Install* (default), *Download* (browser), *Remind Me Later*, *Skip This Version* | `IDS_UPDATE_HINT_DLI` |
| classic, Download & Install not offered | no verifiable asset, refused installer | *Download* (default), *Remind Me Later*, *Skip This Version* | 123's text |
| classic, copy not installed by the installer | not eligible | *Download* (default), *Remind Me Later*, *Skip This Version* | `IDS_UPDATE_HINT_PORTABLE`; the level drop-down disabled |
| classic, downloading for Download & Install | after the click | *Cancel Do&wnload*, *Download*, *Remind Me Later*, *Skip This Version* | `IDS_UPDATE_DLI_PROGRESS` (version, per cent) |
| offer | level 1 (or level 2 with a plan that may not install silently) and a verified installer | *Install Now* (default), *Install When I Close*, *Remind Me Later*, *Skip This Version* | `IDS_UPDATE_HINT_OFFER` |

The drop-down is enabled only for an installed copy while the check box is checked. A change is stored
at once (`Update Level`), drops an automatic plan that no longer applies, and acts on the window by
`SalUpdNoticeLevelChange` (research R4). The automatic level has no form (research R1).

## Messages

- `IDS_UPDATE_DLI_FAILED` - *The installer of version %s could not be downloaded, or it did not pass
  the check.* + the pointer to *Download*.
- 420's messages (busy, damaged, run error, install failed) unchanged.

## Strings

| Id | Text |
|---|---|
| `IDS_UPDATE_BTN_DLINSTALL` 14007 | `Download && &Install` |
| `IDS_UPDATE_BTN_CANCELDL` 14008 | `Cancel Do&wnload` |
| `IDS_UPDATE_HINT_DLI` 14009 | `Download && Install downloads the installer, checks it and installs the update; Tandem Commander then starts again and your settings are kept. Download opens it in your web browser.` |
| `IDS_UPDATE_HINT_PORTABLE` 14010 | `This copy of Tandem Commander was not installed by the installer, so it cannot update itself. Download opens the installer in your web browser; run it to update.` |
| `IDS_UPDATE_DLI_PROGRESS` 14011 | `Downloading and checking the installer of version %s... %u %%` |
| `IDS_UPDATE_DLI_FAILED` 14012 | as above |
| `IDS_UPDATE_LEVEL_AUTO` 14098 (changed) | `Install it automatically as soon as it is downloaded` |
| `IDS_UPDATE_HINT_AUTO` 14154, `IDS_UPDATE_BTN_OK` 14152 | removed |
