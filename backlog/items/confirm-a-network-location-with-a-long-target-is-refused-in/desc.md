---
title: Confirm a network location with a long target is refused in Browse
type: person-step
status: new
severity: 4
area: long-paths
source: leftover:286
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Confirm a network location with a long target is refused in Browse

## Problem

Feature 286 makes the core's Browse For Folder routine (`GetTargetDirectory`) refuse a picked
folder shortcut (a network location) whose target needs more than 259 bytes in UTF-8, instead of
silently handing back the shortcut's own folder. The rule is proven by `saltests`
(`TestFolderShortcut286`, real folder shortcuts) and the code path read, but the GUI route was not
driven: network locations live in the user's profile (`%APPDATA%\Microsoft\Windows\Network Shortcuts`)
and the hidden-desktop probe does not write there; the Browse tree does not list a folder shortcut
inside an ordinary folder.

## Evidence

`specs/286-folder-shortcut-browse/fix-log.md` *Owed to a person*; `quickstart.md` step 5; probe
`specs/286-folder-shortcut-browse/probe/fsc286_probe.ps1` rows `fsc-*` (INFO).

## Expected

The steps below pass on a build containing feature 286.

## Steps

- [ ] Create a folder `C:\fsc286\` + 90 CJK letters (e.g. paste `一丁丂七丄丅丆万丈三` nine times) and a
      network location to it: Explorer > This PC > *Add a network location* > address
      `\\localhost\C$\fsc286\<the folder>` (or create it in `Network Shortcuts` by hand: a folder
      with `desktop.ini` naming `{0AFACED1-E828-11D1-9187-B532F1E9575D}` and `target.lnk`).
- [ ] Tandem Commander > Configuration > Drives > "If path is inaccessible go to" > the browse
      button > This PC > pick the network location > OK -> one box "The path specified is too
      long."; the field keeps its previous text.
- [ ] The same with a network location to a short folder (`\\localhost\C$\fsc286`) -> the field
      holds `\\localhost\C$\fsc286`, nothing asked.
- [ ] Remove the two network locations and `C:\fsc286`.

## Log

- 2026-10-21 — created (source leftover:286)
