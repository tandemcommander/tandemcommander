---
title: Backlog app tests fail now and then removing their fixture folder with EPERM
type: tech-debt
status: open
severity: 3
area: tooling
source: review:412
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app tests fail now and then removing their fixture folder with EPERM

## Problem

`npm run check` of the backlog app (`tools/backlog-app/`) fails now and then in `test/write-channels.test.ts`: the `afterEach` cleanup `rmSync(root, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 })` (`test/helpers/fixture-repo.ts`) throws `EPERM, Permission denied: \\?\C:\Users\<user>\AppData\Local\Temp\backlog-app-repo-<random>`. The failing test is usually "commits at once while a loop lives (the commit channel)", the one that starts a real loop. A green change can fail the gate for no reason of its own, and every failure leaves a fixture folder behind in `%TEMP%` (58 `backlog-app-repo-*` folders there on 2026-11-07).

## Evidence

Measured during feature 412 (branch `412-state-files-acl`, `specs/412-state-files-acl/fix-log.md` sections *Review* and *Findings fixed on the way (continued)*), code at `64eae1d4`:
- `npm run check`: 1 failure (EPERM at `fixture-repo.ts:89`, called from `write-channels.test.ts:96`) in 1 of 2 full runs after review 3 of 412, and in 1 run of review 1 of 412; the next full runs green.
- The file alone: 6 / 6 green in the run; review 4 of 412: 0 / 8 failures with the current `afterEach` (`loop.kill()`), 2 / 14 failures with an attempt that ended the loop's whole tree with `killTree()` (`taskkill /T /F`) - so the loop's process tree is probably not what holds the folder: after both failures no python, git or taskkill process was left, and the leftover folders could be deleted a few minutes later.
- The attempt was reverted (it also could hang the hook when `taskkill` cannot run).

## Expected

The backlog app's tests never fail on removing their own fixture folder, and leave no `backlog-app-repo-*` folder in `%TEMP%`.

## Approach

- First find what holds the folder: on an EPERM, walk the fixture and try each entry (deepest first), and report the entry that cannot be removed and the processes holding it (e.g. `handle.exe` is not available - Restart Manager `RmGetList` through PowerShell, or `openfiles`).
- Candidates: a watcher of the app (`fs.watch` on a folder of the fixture) that `services.stopAndDrain()` does not close; Windows Search or Defender scanning the fresh git objects; the loop's own files.
- Only then fix: close the holder, or wait for it with a bounded retry that reports the holder; a longer `maxRetries` alone hides the cause.
- Measure the base rate first (the failure is rare: about 1 in 7 to 10 runs of the file): count over 30+ runs before and after.

## Notes

Severity 3: only the tests of the developer tool are affected; the product and the app itself are not, and a re-run is green. Found by review 1 and review 4 of feature 412, which did not fix it: telling one attempt from another needs dozens of 30-second runs, beyond that run.

Also seen, not verified as related: the commit-channel test writes `<fixture>-plan.json` beside the fixture in `%TEMP%` and never deletes it.

## Log

- 2026-11-07 — created (source review:412)
- 2026-11-07 — edited Approach
- 2026-11-07 — edited Notes
- 2026-11-07 — moved to Next position 89
