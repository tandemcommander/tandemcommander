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

When the program exits (or the plug-in is unloaded) while a Disk Map shell command waits for the person (e.g. the shell's Delete confirmation from the map's context menu), the core asks "DiskMap plugin has rejected to unload. Do you want to force it to unload?". Yes terminates the map's thread inside the shell after 200 ms (`ThreadQueue.KillAll(TRUE)`), as in every release. With the shell's confirmation still waiting (measured, 143 row E5): no crash, the file is kept, the Debug build shows its leak reports (monitored handles, CRT). But Disk Map calls `InvokeCommand` without `CMIC_MASK_ASYNCOK` (`GUI.ShellMenu.h`), so a confirmed shell operation (a permanent Delete of a large folder, a Paste with Replace) runs on the map's own thread: a forced unload in the middle of it terminates the operation where it is (a half-copied destination, a part of a folder deleted), and a lock or COM state of the shell may stay held for the rest of the session (review of 266, not measured). Feature 266 kept this as the core's force semantics (part (1) of backlog item `plugin-close-forced-unload-and-stray-box`) because the only route that avoids the termination reverses a recorded decision of feature 143.

## Evidence

At 266 (branch `266-close-stray-box`): `src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp` `CPluginInterface::Release` (the comment of feature 266 at `KillAll`); `src/plugins1.cpp` `CPluginData::Remove` calls `Release(parent, TRUE)` and then `FreeLibrary` whatever it returns (`spl_base.h`: with `force` the return value is not respected). 143's decision: `specs/143-diskmap-release-guard/spec.md` *Clarifications* and FR-004 ("a shell command and the shell's own windows are not touched - cancelling a shell operation half-way is not the plug-in's decision"), `contracts/close-in-loop.md`, `src/common/salloopclose.h`. Probe: `specs/266-close-stray-box/probe/result_143_E4-E6.txt` row E5 (PASS, with the Debug note of the leak reports). Research: `specs/266-close-stray-box/research.md` R1.

## Expected

The maintainer chooses A or B below; with B a feature implements it.

## Question

On a forced unload while a Disk Map shell command waits for the person, should the plug-in cancel the shell's window (an exception to 143's FR-004) so that the map's thread ends by itself, or keep terminating it?

## Options

- **A - keep the termination** (the state of 266). No change; the force is what the person asked for. A waiting confirmation: the file is kept, Debug leak reports. A confirmed operation in progress: cut off mid-way (a truncated destination, a partly deleted folder); a shell lock or COM state may stay held (not observed).
- **B - cancel, then wait.** On `Release(force=TRUE)` the map posts `IDCANCEL` to the `#32770` dialogs of its thread that it owns (as it already does for its own boxes) and the plug-in waits up to about 5 s for the thread to end before terminating it. The shell's confirmation is answered No for the person (the file is kept); the unload takes longer by up to 5 s when a shell window is not a `#32770` dialog or ignores Cancel (then it is terminated as now). A confirmed operation in progress is not helped unless its progress window is a cancellable dialog of the map's thread - otherwise it is still terminated after the wait (a longer bound, or no limit, trades that for a frozen main window). Reverses 143's FR-004 for the forced case only.

## Recommendation

A, with the limit stated. The case needs the person to answer "force?" Yes while a shell command of the map runs; with a waiting confirmation the result is safe (no crash, file kept). The harmful case - an operation in progress cut off - is the plain meaning of "force" and B does not reliably avoid it either; B touches the shell's windows, which 143 decided against. If the cut-off operation matters, the better fix is a different item: let the map invoke shell commands with `CMIC_MASK_ASYNCOK`, so that the shell may run a confirmed operation on its own thread, which a forced unload of the plug-in does not terminate (not verified for which verbs the shell honours it).

## Log

- 2026-10-20 — created (source measure:266)
