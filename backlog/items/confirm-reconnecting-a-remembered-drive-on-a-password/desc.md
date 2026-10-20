---
title: Confirm reconnecting a remembered drive on a password-protected share (feature 264)
type: person-step
status: open
severity: 3
area: encoding
source: leftover:264
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Confirm reconnecting a remembered drive on a password-protected share (feature 264)

## Problem

Feature 264 made the reconnection of a remembered, disconnected network drive wide (exact
path, any characters) while keeping its credential handling: the saved user name, Windows'
credential dialog after refused credentials, and the "trying to reconnect, press Esc" wait
window. These parts need a real keyboard and a password-protected share, which the hidden
desktop of the probes does not have; they were checked by reading only.

## Evidence

Feature 264, `specs/264-remembered-drive-reconnect/fix-log.md` section *T013* (NOT DRIVEN rows)
and `quickstart.md` section *Owed to a person*; `RestoreNetworkDriveW` in `src/drivelst.cpp`.
Driven on the hidden desktop (`probe/run264.ps1`): reconnection with the exact path, the saved
provider (row N1), an unreachable server (row U1), the panel path change (row P1).

## Expected

Every step below gives the stated result.

## Steps

- [ ] On a machine with a share that needs a user name and password other than the Windows
      logon (another PC or a NAS), map it as a remembered drive (Explorer: Map network drive,
      "Reconnect at sign-in", "Connect using different credentials"), with a folder name in
      Cyrillic or Chinese in the path. Disconnect it so it stays remembered
      (`net use Z: /delete` would forget it - instead sign out and back in with the server off,
      or pull the network cable), then make the server reachable again.
- [ ] Pick the drive in Tandem Commander's drive bar: it reconnects without asking (the saved
      user name and Windows' saved credentials are used) and the panel shows its root.
- [ ] Remove the saved credentials (Control Panel, Credential Manager, Windows Credentials),
      disconnect the drive again, pick it: Windows' credential dialog appears; Cancel -> the drive
      stays disconnected and no further message appears.
- [ ] Repeat and type the correct password -> the drive is connected, the panel shows its root.
- [ ] With the server switched off (or unplugged), pick the drive: after about 3 seconds the
      wait window "trying to reconnect ... Esc" appears; Esc closes it at once and the panel stays
      where it was.

## Log

- 2026-10-20 — created (source leftover:264)
- 2026-10-20 — moved to Person steps position 10
