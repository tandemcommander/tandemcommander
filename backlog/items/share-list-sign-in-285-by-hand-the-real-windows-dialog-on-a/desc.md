---
title: Share list sign-in (285) by hand: the real Windows dialog on a server that refuses the list
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:285
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [real-file-server-person-rows, share-root-up-284-person-rows]
depends-on: []
reason: -
---

# Share list sign-in (285) by hand: the real Windows dialog on a server that refuses the list

## Problem

Feature 285 makes `\\server\` (Change Directory, and the way up from a share's root of 284) offer Windows' sign-in dialog when the server refuses its share list for want of a name and password, then read the list again. The hidden-desktop probe answers the sign-in through a Debug seam; Windows' real credential dialog and a real file server that refuses the list cannot be driven there.

## Evidence

`specs/285-share-list-sign-in/fix-log.md` sections *Checks after* (NOT DRIVEN) and *Review* (SHOULD 1); `quickstart.md` step 5. Probe `specs/285-share-list-sign-in/probe/signin_probe.ps1` - 20 PASS, all against `\\localhost` with the seams. Code: `SignInToUncServerW` (`src/drivelst.cpp`, `WNetAddConnection3W` with `CONNECT_INTERACTIVE | CONNECT_PROMPT` to `\\server\IPC$`), `CFilesWindow::PickServerShare` (`src/fileswnb.cpp`).

## Expected

Every step below gives the stated result on a Release or Debug build of 285 or later, on a machine whose Windows user has no session with the test server.

## Steps

- [ ] A file server that refuses its share list to the current Windows user (or to a guest): Change Directory `\\server\` -> Windows' sign-in dialog appears (not the "(5) Access is denied" box); sign in with an account that may list -> the share list appears under the directory line; pick a share -> the panel is in `\\server\share`
- [ ] The same, from `\\server\share` with Backspace -> the same dialog, then the list (route of 284)
- [ ] Cancel and Esc in Windows' dialog -> no message; Change Directory opens again with `\\server\` (Backspace route: the panel stays)
- [ ] A wrong password -> Windows' dialog itself asks again or one "Network Error" with the Windows text; nothing else changes
- [ ] *Remember my credentials* unticked -> after a sign-out and sign-in of Windows, `\\server\` asks again; ticked -> Windows stores the credential (Control Panel, Credential Manager) and the next `\\server\` lists without a dialog
- [ ] A server where the signed-in account may connect but still may not list shares -> one dialog, then one "(5)" error, no second dialog (CONNECT_PROMPT: the dialog is shown even when the current identity could connect `IPC$` - review SHOULD 1)
- [ ] An existing connection to the server under another user name (e.g. a mapped drive) and a different account typed -> the "Multiple connections to a server ..." message
- [ ] After the dialog closes, the share list takes the keyboard at once (arrows, Enter, Esc)

## Log

- 2026-10-21 — created (source leftover:285)
- 2026-10-21 — moved to Person steps position 25
