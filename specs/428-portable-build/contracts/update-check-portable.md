# Contract: new-version check in the portable edition (FR-017, Q-13, Q-14, Q-29)

Builds on 123 / 420 – 422 (`src/common/salupdcheck.h`, `src/updcheck.cpp`, `src/upddlg.cpp`,
`src/updinstall.cpp`). The request, its headers, the schedule (on by default, about once a day,
1 h after an unreachable attempt) and *Help > Check for New Version* / the About-box check are
unchanged.

## Asset rule

- New pure builders in `salupdcheck.h`: `SalUpdPortableName(ver)` →
  `tandemcommander-<ver>-x64-portable.zip`, `SalUpdPortableUrl(ver)` →
  `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/<name>`.
- `SalUpdParseLatestRelease(..., edition)`: for `portable` the release must carry that asset
  (state `uploaded`, `browser_download_url` equal to the built URL - the same checks
  `SalUpdReadAsset` makes for the installer; two such assets are accepted as two installers are);
  otherwise the record is not accepted (`supeNoPortable`, logged): the background check finds nothing
  to offer and a check the user starts says the release could not be checked. The installer asset is **not** required for the
  portable edition, and the normal edition's rule is unchanged.
- saltests: present / missing / twice / not uploaded / wrong URL / draft / pre-release for both
  editions.

## Behaviour

| Item | Portable edition |
|------|------------------|
| `UpdInstall_IsEligible` | FALSE at compile time (no uninstall-entry read) |
| Notification | the existing window, link *Release notes* / *Download page* opens the release page; no *Download & Install*, no *Install Now*, no level list; hint `IDS_UPDATE_HINT_PORTABLE_EDITION` ("Download the new portable archive and unpack it next to this one; copy the settings folder into it.") |
| Configuration > General | only *Check for new versions*; the *When a new version is found* list and its label are hidden (the page lays out without the gap) |
| Stored state | `Update Check` subkey in the session hive (follows `SalCfgBaseKey()`); `Install *` / `Download Refused` never written |
| Claim mutex | `Local\TandemCommanderUpdateCheck_P<scope>` |
| Files | none (no `%LOCALAPPDATA%\…\Updates`) |
| `--updatetest` | refused with a message in the portable edition (it tests installing) |

## PRIVACY.md

The portable edition makes the same single request as the installed program; the statement says
so in its portable section (FR-019).
