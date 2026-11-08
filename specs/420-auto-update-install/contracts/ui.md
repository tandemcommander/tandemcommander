# Contract - user interface (feature 420)

> **Superseded in part by feature 421** (`specs/421-update-notice-levels/contracts/ui.md`): the
> notification has a level choice and *Download & Install* on its classic form; the automatic form
> below is gone - the automatic level installs without a window as soon as nothing can be lost; the
> third level reads *Install it automatically as soon as it is downloaded*.

## Configuration > General

Under *Check for a new version of Tandem Commander at start-up*: label *&When a new version is
found:* and a drop-down list: *Notify me only* / *Download it and offer installation* / *Install it
automatically when I close Tandem Commander*. Enabled while the check box is checked. Read fresh when
the page opens; written at once on OK only when the user changed it (123's pattern). Changing it
to a value other than 2, or clearing the check box, drops an arm of source *automatic*.

## Notification (IDD_UPDATENOTICE) - three forms

| Form | When | Buttons (left to right) | Hint line |
|---|---|---|---|
| classic | level 0, not eligible, metered, no download data, download failed, manual check before the download finished | *Download* (browser), *Remind Me Later*, *Skip This Version* | 123's text |
| offer | level 1 and a verified installer | *Install Now* (default), *Install When I Close*, *Remind Me Later*, *Skip This Version* | `IDS_UPDATE_HINT_OFFER` |
| automatic | level 2 and a verified installer (armed) | *Install Now* (default), *OK*, *Skip This Version* | `IDS_UPDATE_HINT_AUTO` |

Buttons are laid out left to right at run time from the visible ones. *Install When I Close*
arms (source user) and closes the window; *OK* closes it (the arm stays); *Skip This Version*
records the skipped version (123), drops an arm of it and deletes its installer. Showing rules
(no keyboard taken from a working user, one notification per user, owned by the main window,
`SALCLOSEAPP_WINDOW_PROP`) are 123's. A notification of another form or version of ours is
replaced. Test mode: the *Released* line reads `IDS_UPDATE_TESTMODE`.

## About

Test mode: the update line reads `IDS_UPDATE_ABOUT_TESTMODE` in front of the normal text.

## Messages

`IDS_UPDATE_INSTALL_FAILED` - *The update to version %s was not installed (Setup ended with code
%u). It will be installed when you close Tandem Commander.*
`IDS_UPDATE_ERR_RUN` - *The installer of version %s could not be started.* + system text.

> **Feature 422** (`specs/422-install-now-not-at-exit/spec.md`): nothing is installed at the exit any more - *Install When I Close*, the question "install it when you close?" and the exit install are removed; the automatic level installs right away after the check at start-up (no idle wait); a check the user starts always shows the notification.
