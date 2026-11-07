# Closing report - 406-regedt-hkcr-both-halves
Backlog item: registry-editor-hkcr-move-both-halves-leaves-machine-half - Registry Editor: Move of an HKCR key held by both halves leaves its machine half
Outcome: closed

## What changed

- `src/common/salregkeyid.h`: `SAL_HKCR_DELETE_BOTH` (appended to 390's enum; the old values keep
  their numbers); `SalRegHkcrDeleteHalf(TRUE, TRUE)` returns it (was `VIEW` = the delete through
  HKCR); `SalRegValueSame` (type, size, bytes).
- `src/plugins/regedt/fs5.cpp`, `CopyOrMoveKeyRec`, for a Move of an HKCR key held by both halves:
  - before anything of the key is copied, `SafeHkcrMachineHalfNoLink` refuses a machine's half that is
    a registry link (297's test reaches only the user's half through HKCR);
  - at the end, the machine's half is deleted first by its real path - after `HkcrMachineHalfCopied`
    checks that the copy holds all of it (no machine value hidden by a different user's value of the
    same name; a non-empty machine class equal to the user's; value buffers start doubled and grow) -
    then the user's half by its real path;
  - every failure and refusal in the existing "Unable to remove the original registry key." box
    (refusals with `ERROR_NOT_SUPPORTED`, as 297); Retry / Skip / Skip All / Cancel as before; when the
    machine's half fails nothing of that key is deleted.
- No new UI string, no dialog change, no plug-in ABI change - no `.slt` refresh.

## Measurements (before / after, commands)

- Direct (script `%TEMP%\tcmeasure\hkcr_view.ps1`, not elevated, only HKCU written): the merged view
  hides a machine value behind the user's of the same name; `RegDeleteKeyW(HKCR, ...)` returns 0 and
  removes only the user's half.
- Probe `probe/hkcr406_probe.ps1` (hidden desktop, not elevated; `tools\run_on_hidden_desktop.ps1`):
  before (8bb3c295) 6 PASS / 7 FAIL - no box, the user's half deleted, the machine's half left;
  after 26 PASS / 0 FAIL / 0 NOT DRIVEN in English and Czech (rows BOTHMOVE, BOTHSKIP, BOTHSHADOW,
  BOTHEQUAL, BOTHTOP, BOTHCLASS, BOTHLINK, BOTHSELF).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: BUILD SUCCEEDED (warnings only the old C4267 of `fs2.cpp`).
- `saltests.exe`: `saltests: 282544 checks, 0 failed` (282,524 before; `TestRegHkcrBoth406`;
  negative control with the old rule 5 failed).
- Probes: 406 26 / 0 (English, Czech); 390 10 / 0; 292 33 / 0; 294 24 / 0; 296 47 / 0; 297 40 / 0;
  registry restored identical after every run.

## Reviews (findings and what was done)

Three refute-first reviews, no MUST in any (details: `fix-log.md`, *Review*).
- Review 1: SHOULD control characters in the fix-log (fixed); SHOULD the value check did not double /
  grow its buffers as the copy does (fixed); NOTEs - top-key and class rows added, exact class compare
  (fixed); race / box naming / (50) without a reason accepted.
- Review 2: SHOULD a machine's half that is a registry link was not tested (fixed:
  `SafeHkcrMachineHalfNoLink`); NOTEs accepted (long class, vanished half, round limit).
- Review 3: SHOULD the link refusal is drivable unelevated through Windows' own
  `Wow6432Node\AppID` link (fixed: probe row BOTHLINK; the elevated checklist line for it dropped);
  NOTEs (a stock `Wow6432Node\TypeLib` made review 2's finding reachable; a link higher on the path is
  not new with 406; name-based test; stack frame) recorded.

## Owed to a person (the lines added to the release checklist)

1 check added to `manual-checks-owed-before-the-next-release`: the elevated Move of a both-halves
scratch key `.tc406` (both halves really removed; a hidden value `m` refuses the machine's half with
(50)) (feature 406).

CHANGELOG: `CHANGELOG.md` has no `## [Unreleased]` section (the newest is `## [0.2.0] — 2026-10-25`),
so no entry was written there. The entry for the next release:

```text
- **Registry Editor: a Move of an `HKEY_CLASSES_ROOT` key held by both the machine's and the user's classes left the machine's half** (feature 406).
  - **Before:** the Move copied the key and then deleted the source through `HKEY_CLASSES_ROOT`, which removes only the user's part; the machine's part stayed and was still shown, and the Move reported success - also without administrator rights.
  - **Now:** both parts are deleted by their real paths, the machine's first; without administrator rights the Move ends with "Unable to remove the original registry key." naming the machine's key, and nothing of the source is deleted. The machine's part is never deleted while it holds a value hidden by the user's value of the same name, or when it is a registry link - the same box with "The request is not supported."
  - **Limitation:** the refusal does not say why; a change of the user's part by another program between the copy and the delete is not seen.
```

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- `specs/FEATURE-HISTORY.md` (line 2294, on `main` before this feature): a BEL character where
  `T:\arc.zip` had lost its backslash (the here-document trap) - fixed; `grep -P` for control
  characters now finds none in the file.

## New Inbox items (slug - title)

None.
