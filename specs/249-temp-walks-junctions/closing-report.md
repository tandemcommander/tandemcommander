# Closing report - 249-temp-walks-junctions
Backlog item: temp-dir-walks-follow-junctions - SFX temp cleanup and the external unpacker's walk follow junctions
Outcome: closed

## What changed

- `src/pack1.cpp` `PackUniversalUncompress`: the walk that finds the extracted subfolder of the
  archive path no longer enters a directory link (`DeleteAsDirLink`, feature 197, fail closed; a
  cloud placeholder is still a folder). A link refuses the unpack before anything is moved:
  `IDS_PACKERR_GENERAL` with `<path>: <system text of ERROR_REPARSE_POINT_ENCOUNTERED>` (composed on
  the heap, never cut; no new UI string), the temporary folder removed by 212 (the link as a link),
  `FALSE` to the caller (F5 / drag & drop out of an archive browsed by the external 7-Zip archiver).
- `src/plugins/zip/selfextr/selfextr.cpp` `_RemoveTemporaryDir`: a directory with a reparse point is
  removed as an entry, never walked (source only - the standalone `selfextr.vcxproj` does not build
  on this machine, D8003, and no `.sfx` ships).
- Feature 212's start-up `SAL*.tmp` sweep is now driven on the build (probe row SWEEP).
- Probe `probe/tempjunction249_probe.ps1` (new): rows SWEEP, PLAIN, UNPACK, DEEP; a fake `7z.exe`
  (`l` -> the real 7-Zip, `x` -> a junction) set as the 7-Zip executable; registry backed up and
  restored.

## Measurements (before / after, commands)

- 7-Zip 22.01 by hand (fix-log, *Reachability*): 7z / TAR / WIM with a stored junction, extracted
  with `7z x`: no junction pointing outside the output (TAR "Dangerous link path was ignored", WIM
  re-targeted inside the output). Reach needs an unpacker that restores a junction.
- Probe (hidden desktop): `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\249-temp-walks-junctions\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\249-temp-walks-junctions\probe\tempjunction249_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

| Row | Before (1c8140a0, `result_before.txt`) | Control without the pack1 change (`result_control_unfixed.txt`) | After (`result_after.txt`) |
|---|---|---|---|
| SWEEP | PASS | PASS | PASS |
| PLAIN | PASS | PASS | PASS |
| UNPACK | FAIL - the target's keep.txt moved into out | FAIL | PASS - refused with "System error: ...\PACK8F.tmp\top: (4395) ...", keep.txt kept |
| DEEP | (row added later) | FAIL | PASS - "...\a\top: (4395) ...", keep.txt kept |

After: 8 / 0 (4 RUN + 4 END rows), registry restored and identical.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED`
- `saltests.exe`: `saltests: 24319 checks, 0 failed` (unchanged count - no new pure rule; the decision
  is 197's `SalDeleteAsDirLinkDecision`)
- `cl /Zs` x86 of `selfextr.cpp`: no diagnostics
- Probe: 8 PASS / 0 FAIL / 0 NOT DRIVEN; negative control UNPACK and DEEP FAIL

## Reviews (findings and what was done)

Review 1 (refute-first, independent agent): no MUST. Re-ran the probe (8 / 0); its own variant row
MERGE (a junction restored outside the checked archive path, the target already holding that
folder) showed the existing link question and no loss; all callers enumerated (F5 / drag & drop,
drag to another application, custom unpackers without the walk; no Move route deletes archive
members after an unpack). SHOULD 1 (the fix-log said no project compiles `selfextr.cpp`) - corrected;
SHOULD 2 (closing records) - done here. NOTEs accepted (message wording -> Inbox item; fail closed on
an unreadable reparse folder and on 7-Zip's re-targeted WIM junction, spec Q2; SWEEP has no
build-without-212 control). No second review (no MUST findings).

## Owed to a person (with the new person-step items)

Nothing. All rows were driven on the hidden desktop; the self-extractor cannot be built on this
machine (its project fails with D8003) and is not shipped, so no check is owed for it.

## New Inbox items (slug - title)

- unpack-refused-at-a-link-names-a-temporary-folder-not-the - Unpack refused at a link names a temporary folder, not the archive folder
