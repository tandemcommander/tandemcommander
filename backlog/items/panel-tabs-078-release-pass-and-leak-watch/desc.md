---
title: Panel tabs (078) by hand on the Release build, and the 88-byte leak watch
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:078
who: person
created: 2026-09-20
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [onscreen-pass-081-mdview-shared-host]
depends-on: []
reason: -
---

# Panel tabs (078) by hand on the Release build, and the 88-byte leak watch

## Problem

Panel tabs (078) were verified by a GUI driver against the Debug build only; a manual pass on the Release build was part of the 0.1.8 ship gate and is still owed. Also, 078/079 sessions showed an 88-byte Debug-CRT leak at exit; 081 found and fixed a leak of exactly that size in CTcWebKeeper - whether that was the same leak is unconfirmed.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('078 panel tabs on the Release build, the 078/079 88-byte leak watch') and §3 (~lines 1096, 1136) (at 7993914c). Steps: specs/078-panel-tabs/closing-report.md item 3 'Human-owed GUI steps' (~line 96) and specs/078-panel-tabs/quickstart.md.

## Expected

The 078 human-owed steps pass on the Release build; the leak report either never appears again under a DBWIN listener (record it as explained) or does (then it was something else - a new item).

## Steps

- [ ] 078 quickstart §5 remaining items on the Release build: move / delete / rename in several tabs, hot paths, Working Directories, two Drive Bars, bug report dialog, plug-in load sweep
- [ ] 078 §7.1-7.4 and 7.6: archive and SFTP tabs across a restart, Export Configuration .reg inspection, kill-and-restart, Process Monitor proof of no registry writes on tab changes
- [ ] 078 §8.4 (Ctrl+Shift+T/W with the command line focused), §9.1 inside an archive, §9.3 Escape during a drag, §9.5 strip-background menu
- [ ] 078 §10.2-10.6: narrow panel, five-minute idle, 10,000-entry switch timing, themes, scaling; §13 visual pass over all eight languages
- [ ] Leak watch: in Debug sessions run under a DBWIN listener and note whether the 88-byte Debug-CRT leak at exit appears again

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
