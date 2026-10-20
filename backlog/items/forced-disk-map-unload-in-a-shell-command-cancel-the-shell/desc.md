---
title: Forced Disk Map unload in a shell command: cancel the shell window or terminate
type: decision
status: new
severity: 2
area: other-plugins
source: measure:266
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

# Forced Disk Map unload in a shell command: cancel the shell window or terminate

## Problem

When the program exits (or the plug-in is unloaded) while a Disk Map shell command waits for the person (e.g. the shell's Delete confirmation from the map's context menu), the core asks "DiskMap plugin has rejected to unload. Do you want to force it to unload?". Yes terminates the map's thread inside the shell after 200 ms (`ThreadQueue.KillAll(TRUE)`), as in every release: no crash, the file is kept, but the Debug build shows its leak reports (monitored handles, CRT) and the terminated thread may leave shell state behind. Feature 266 kept this as the core's force semantics (part (1) of backlog item `plugin-close-forced-unload-and-stray-box`) because the only route that avoids the termination reverses a recorded decision of feature 143.

## Evidence

At 266 (branch `266-close-stray-box`): `src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp` `CPluginInterface::Release` (the comment of feature 266 at `KillAll`); `src/plugins1.cpp` `CPluginData::Remove` calls `Release(parent, TRUE)` and then `FreeLibrary` whatever it returns (`spl_base.h`: with `force` the return value is not respected). 143's decision: `specs/143-diskmap-release-guard/spec.md` *Clarifications* and FR-004 ("a shell command and the shell's own windows are not touched - cancelling a shell operation half-way is not the plug-in's decision"), `contracts/close-in-loop.md`, `src/common/salloopclose.h`. Probe: `specs/266-close-stray-box/probe/result_143_E4-E6.txt` row E5 (PASS, with the Debug note of the leak reports). Research: `specs/266-close-stray-box/research.md` R1.

## Expected

The maintainer chooses A or B below; with B a feature implements it.

## Question

On a forced unload while a Disk Map shell command waits for the person, should the plug-in cancel the shell's window (an exception to 143's FR-004) so that the map's thread ends by itself, or keep terminating it?

## Options

- **A - keep the termination** (the state of 266). No change; the force is what the person asked for; the file is kept; the Debug build shows leak reports; a thread killed inside the shell may leave a lock or COM state behind for the rest of the session (not observed).
- **B - cancel, then wait.** On `Release(force=TRUE)` the map posts `IDCANCEL` to the `#32770` dialogs of its thread that it owns (as it already does for its own boxes) and the plug-in waits up to about 5 s for the thread to end before terminating it. The shell's confirmation is answered No for the person (the file is kept); the unload takes longer by up to 5 s when a shell window is not a `#32770` dialog or ignores Cancel (then it is terminated as now); a progress dialog of a running shell operation is not on the map's thread and is not cancelled. Reverses 143's FR-004 for the forced case only.

## Recommendation

A. The case needs the person to force the unload while a shell window of the map is open, and the result is already safe (no crash, file kept). B touches the shell's windows, which 143 decided against, for a Debug-only symptom.

## Log

- 2026-10-20 — created (source measure:266)
