# Closing report - 381-uncab-wtf8-name
Backlog item: uncab-wtf8-flagged-name-refused - UnCAB: one UTF-8 cabinet name with an unpaired surrogate makes the whole cabinet fail
Outcome: closed

## What changed

- `src/plugins/uncab/uncab.cpp` `CabNameToU8`: decides how a stored entry name is read through the new
  header-only rule `src/plugins/uncab/cabname.h` (`CabNameReadAs`: as UTF-8 / code page / refuse). A
  name flagged `_A_NAME_IS_UTF` that is valid WTF-8 (an unpaired surrogate as its 3-byte form) is now
  accepted byte for byte; a flagged name that is not even WTF-8 is still refused; unflagged names and
  the next-cabinet / next-disk names stay code page; the unflagged guess of a continued entry
  (`fdintPARTIAL_FILE`) also takes WTF-8 as UTF-8. Names are never cut (the buffer refusal is
  unchanged).
- `src/plugins/shared/splunicode.h`: new inline `SplIsWtf8` (the feature 089 decoder; no ABI change).
- `src/saltests/saltests.cpp`: `TestCabName381`.
- `src/plugins/uncab/vcxproj/uncab.vcxproj` (+ `.filters`): lists `cabname.h`.
- No UI string, dialog or menu changed (no `.slt` refresh); no change to `PRIVACY.md` claims.

## Measurements (before / after, commands)

- Fixture `probe/cab381.py` (stored MS-CAB writer; Windows `expand.exe` lists and extracts its
  control cabinet). Probe `probe/cab381_probe.ps1` on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\381-uncab-wtf8-name\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\381-uncab-wtf8-name\probe\cab381_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`.
- Before (bd7cc15e, `result_before.txt`): PASS 14, FAIL 4 - flagged `a<U+D800>b.txt` / `a<U+DC00>b.txt`:
  Unpack extracts nothing (not even `c.txt`), the cabinet is kept; Enter does not open the cabinet; no
  message at all.
- After (`result_after.txt`): PASS 18, FAIL 0 - both cabinets list and unpack under the exact names;
  controls and refusals unchanged. Registry restored and identical in every run.
- The item's "FDI error" was not measured: the refusal is silent (`FDIERROR_USER_ABORT`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `python tools/check_encoding.py --plugins` -> TOTAL 17 -> 16, no `uncab/uncab.cpp`.
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- `saltests.exe` -> `saltests: 30404 checks, 0 failed` (exhaustive over all 16,646,655 strings of 1-3
  bytes against the core's `SalU8ToW`); negative control (strict rule planted) -> 10 failed.
- Probe `cab381_probe`: 14 / 4 -> 18 / 0.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST, no SHOULD. Its negative control (the old `uncab.spl` from `main`,
  own worktree and build folder) reproduced 14 / 4; its extra probe (F5 from inside the cabinet, F5 of
  one of near-identical names, F3, a CESU-8 pair, a refused entry after a good one) 12 / 0.
  NOTE 1 (CESU-8 pair accepted, comments said "valid WTF-8") fixed: comments + a saltests vector.
  NOTE 2 (the guess accepts `ED A0..BF 80..BF` code-page bytes) accepted per spec Clarification 1.
  NOTE 3 (silent refusal) -> Inbox item below. NOTE 4: six old review worktrees from earlier sessions
  (`%TEMP%\rev325\neg`, `rev328`, `rev330`, `rev332`, `rev335`, `rev341r3`) are still registered in
  `git worktree list` - the maintainer may prune them.

## Owed to a person (with the new person-step items)

- `CHANGELOG.md` has no `## [Unreleased]` section: add this entry (feature 343 style) when the next
  release section is opened:

  - **A cabinet with a name holding an unpaired surrogate could not be opened** (feature 381). A `.cab`
    archive one of whose files was stored with a UTF-8 name containing an unpaired surrogate - a name
    Windows allows - could not be opened or unpacked at all, not even its other files, and nothing
    said why. Such a name is now listed and extracted under exactly that name. A name that is not
    valid UTF-8 at all is still refused, which still fails the cabinet without a message (to be fixed
    separately).

- No person-step item: the change is fully driven on the hidden desktop.

## New Inbox items (slug - title)

- `uncab-a-cabinet-whose-entry-name-is-refused-fails-without` - UnCAB: a cabinet whose entry name is
  refused fails without any message
