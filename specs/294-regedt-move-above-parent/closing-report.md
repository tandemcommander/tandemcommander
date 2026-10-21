# Closing report - 294-regedt-move-above-parent
Backlog item: registry-editor-move-of-a-key-into-the-key-above-its-parent - Registry Editor: Move of a key into the key above its parent loses a same-name subkey
Outcome: closed

## What changed

- `src/common/salregkeyid.h`: `SalRegKeyIdBelow(key, outer)` - the path of one key identity below
  another (strictly inside, case ignored, whole elements), else NULL.
- `src/plugins/regedt/fs5.cpp`: `SafeRegKeyHoldsPath` and a third test in the key check of
  `CPluginFSInterface::CopyOrMoveFromFS`: when the target key holds the source (by identity) and the
  source holds its own path below the target, the key is refused with the existing "Name: <key>
  Error: Can't move/copy a key to itself." box (OK skips, Cancel stops) before anything is written;
  another open error goes through the existing open-error box (fails closed). A merge into the key
  above the parent without the repeated chain is still allowed.
- `src/saltests/saltests.cpp`: `TestRegKeyIdBelow294` (18 checks).
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` (entry + index row "Data-loss guards").
- No UI string, no plug-in interface change.

## Measurements (before / after, commands)

Probe `probe/above294_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`, commands
in `fix-log.md` and `quickstart.md`):

- before (main e752f9b9): **14 PASS / 10 FAIL** - ABOVEMOVE, ABOVEALIAS, ABOVEDEEP, ABOVEOK lost
  x=3 without a box; ABOVECOPY wrote into the source (`probe/above294_before.txt`).
- after: **24 PASS / 0 FAIL** English (`probe/above294_after.txt`), **24 / 0** Czech
  (`probe/above294_after_czech.txt`); registry restored identical every time.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- Build `build.cmd` (Debug x64): BUILD SUCCEEDED.
- saltests: `25458 checks, 0 failed` (25,440 before); negative control (no whole-element test): 1 failed.
- 292's probe on this build: 31 / 1 (one "opened no dialog" timing flake before any code of this
  feature runs), re-run **33 / 0**.

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD. It re-ran build, saltests, both probes and a scratch
probe of its own (14 / 0: case-differing chain, two keys selected with OK / Cancel, read access
denied with Cancel / Skip). NOTE 1 (a registry link in the target tree into the source) -> Inbox;
NOTE 2 (HKCR across halves, admin) - existing items; NOTE 3 (message wording) and NOTE 5 (probe flag)
accepted; NOTE 4 (changelog / history) done at closing.

## Owed to a person (with the new person-step items)

Nothing new. The elevated HKCR cases remain in `registry-editor-292-elevated-hkcr-checks`.
Drag and drop between two Registry Editor panels uses the same function and was not driven.

## New Inbox items (slug - title)

- registry-editor-move-through-a-link-in-the-target-tree - Registry Editor: Move into a key holding a registry link to the source writes into the source
