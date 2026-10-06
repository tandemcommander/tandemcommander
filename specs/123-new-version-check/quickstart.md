# Quickstart: validating the New Version Check

**Feature**: 123-new-version-check. A validation guide, not an implementation
guide. Contracts: [update-source](contracts/update-source.md),
[stored-state](contracts/stored-state.md), [ui](contracts/ui.md).

## Prerequisites

- `build.cmd` (Debug x64) and `build.cmd full release` both green.
- Python 3.13 (fixture server, standard library only).
- GUI probes run on the hidden desktop: `tools/run_on_hidden_desktop.ps1`.
  They share `HKCU\Software\Tandem Commander` with an installed instance — the
  probe backs the whole key up and restores it (the 093 rule).
- Never `Start-Process -Wait` on the program or an installer (project memory).

## A. Pure rules

```batch
build.cmd
<build dir>\saltests\Debug_x64\saltests.exe
```

Expected: 0 failures; the count rises from 17,498 by the new `salupdcheck`
group (version order, JSON reader, release validation with the saved real
0.1.8 record and its mutations, throttle rule incl. a clock in the future).

## B. Fixture server and the request

```powershell
python specs\123-new-version-check\probe\updserver.py --port 8123   # logs every request
$env:TC_UPDATECHECK_URL = 'http://127.0.0.1:8123/latest/newer'
$env:TC_UPDATECHECK_PRETEND_VERSION = '0.1.8'
```

Fixtures (`/latest/<name>`): `newer`, `same`, `older`, `prerelease`, `draft`,
`noasset`, `asset-not-uploaded`, `foreign-url` (asset address on another
host), `foreign-html-url`, `bad-tag`, `dup-tag`, `oversized`, `truncated`,
`html` (captive portal page), `empty`, `403`, `429`, `500`, `redirect`,
`auth401` (Negotiate challenge), `hang`, `slow`.

Expected in the server log for every request: exactly the headers of the
contract, no `Cookie`, no `Authorization` (also after `auth401`), no second
request after `redirect`.

## C. Behaviour probe (Debug build)

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 `
  specs\123-new-version-check\probe\updcheck_probe.ps1
```

| Row | Setup | Expected |
|---|---|---|
| C1 | `newer`, option on | main window usable first; notification within 10 s; versions and date correct (SC-001) |
| C2 | `same` / `older` | nothing shown; About says latest |
| C3 | every failing fixture of § B | nothing shown, no message, state of knowledge unchanged, exit not delayed (SC-007, SC-008) |
| C4 | option off, 20 starts | 0 requests in the server log (SC-003) |
| C5 | option on, 20 starts in a row | 1 request (SC-004) |
| C6 | two instances started together | 1 request, 1 notification |
| C7 | *Skip This Version*, restart with time moved 25 h | no notification; About still shows the version; manual check shows the notification |
| C8 | *Remind Me Later*, restart at once / after 25 h | nothing / notification again |
| C9 | check box cleared in the notification | configuration page shows it off; later starts send nothing |
| C10 | manual command with `newer`, `same`, server stopped, `403`, `html` | notification / "latest version" / three distinct "could not check" texts, each within 15 s (SC-006) |
| C11 | manual command with `hang`, then Cancel | wait dialog after 0.5 s; Cancel returns at once; nothing shown |
| C12 | program closed while `hang` is in progress | exits without delay |
| C13 | start with a modal window already open | notification waits, appears after it closes |
| C14 | `Last Attempt` set one year ahead | a check runs |
| C15 | *Download* and *Release notes* (default browser replaced by a logging stub for the probe) | exactly the two constructed addresses |
| C16 | About dialog in the three known states; *Check now* | texts per contract; opening it sends nothing |
| C17 | start-up time, option on vs. off vs. offline (20 runs each) | no difference beyond noise (SC-002); `winhttp.dll` not loaded when off |

The probe supports `-Expect fixed|before`; on the build before the feature
every row reports "command not present".

## D. Update with the notification open (feature 080)

Run `specs/080-restart-manager-upgrade/probe/rm_probe.ps1` against the Debug
build with the notification open: the program agrees and closes, nothing is
left on screen, the restarted program does not show a second notification
within the same day.

## E. Older version

Start the published 0.1.8 with the `Update Check` subkey present and filled;
exit with *Save configuration on exit* on. Expected: starts and exits
normally, the subkey is still there and unchanged.

## F. Real endpoint

Debug and Release, no seam: Help → *Check for New Version*. Expected today:
"Tandem Commander 0.1.8 is the latest version." within a few seconds;
`X-RateLimit-Used` rises by one per command (observe with `curl -I` before and
after). Release: `dumpbin /imports` shows `winhttp.dll` only under delay
imports; `tools/check_runtime_deps.py` green.

## G. A person's pass (cannot be driven on the hidden desktop)

1. Design acceptance (SC-009): the notification at 100 %, 150 %, 200 %, light
   and dark theme, in all eight languages (screenshots from the probe are the
   starting point); keyboard only: Tab order, Enter, Esc, access keys.
2. Typing in the command line while the notification arrives: the keyboard
   focus stays in the command line.
3. Screen reader (Narrator): the window announces its title, the two versions
   and each control by name.
4. A real browser download from *Download*.

## H. Owed until the next release

- The *newer* path in a **Release** build against the real endpoint — proven
  the day the next version is published (a 0.1.8 + this feature build cannot
  exist as a release; the first released build with the feature is the next
  version itself, so the first real notification appears one release later).
- One antivirus scan of the Release build (first outbound connection of the
  core).

## I. Documentation gates

- `PRIVACY.md`: every sentence in the claim map (`fix-log.md`) matched against
  the server log of § B and the code (SC-010); validity line updated.
- `CHANGELOG.md` entry under `## [Unreleased]`; help topic builds; all eight
  languages build with `build.cmd full` (0 gaps in `translate.merge` dry run).
