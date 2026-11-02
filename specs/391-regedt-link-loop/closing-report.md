# Closing report - 391-regedt-link-loop

Backlog item: registry-editor-copy-or-find-through-a-link-to-an-ancestor - Registry Editor: Copy or Find through a link to an ancestor walks in a loop
Outcome: closed

## What changed

- Copy (F5, drag and drop; the shared recursion of Move / Quick Rename too) and Find of the Registry
  Editor keep the identities (feature 292's internal key names) of the keys they are inside. A subkey
  opened by name that is one of them, or a key above one, is not followed:
  - Copy refuses it before anything is written, with feature 296's existing box "Can't copy a key to
    itself." naming it (OK skips, Cancel stops).
  - Find skips it silently, because its contents are already being searched.
- Copy also refuses a source key that is, or holds, one of the target keys it is writing now. Without
  this, a link to the target's parent made the copy copy itself.
- Links elsewhere are followed as before, including links to other keys of the target.
- Keys that open as predefined pseudo-handles (the Perflib language keys) are read as before.
- Code: `src/common/salregkeyid.h` (`SalRegKeyIdLeadsBack`, `SalRegIsPseudoKeyHandle`),
  `src/plugins/regedt/regedt.h` (`CRegWalkChain`, `CRegWalkLevel`), `fs5.cpp` (the walk functions,
  the checks in `CopyOrMoveKeyRec`, the refusal box moved into `RefuseCopyIntoItself`),
  `finddlg.h/.cpp` (`ScanKey` / `ScanKeyAux`), `src/saltests/saltests.cpp`.
- No UI string, dialog or resource changed, so no translation refresh was needed.

## Measurements (before / after, commands)

The probe is `probe/loop391_probe.ps1`, run on the hidden desktop:
`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\391-regedt-link-loop\probe\loop391_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe [-Lang czech] -OutFile ..."`.

- **Before (HEAD fbccd821):**
  - Copy through a self-link wrote 55 keys in a chain 27 levels deep; through a link to an ancestor, 38 keys; through a cycle of two links, 43 keys. Each ended with "Unable to open a registry key. (87)".
  - Find listed the one key 28, 10 and 15 times, each search ending with the same box.
  - Results: `loop391_before.txt`, `loop391_before_find.txt`.
- **After (final build):**
  - `loop391_after_r3_english.txt` and `_czech.txt`: 28 / 0.
  - The looping Copy rows show exactly one box and write 0 keys below the refused key.
  - The Find rows list 1 result each with no box.
  - The control rows (a link elsewhere, a key that was in the target, a sibling already written, Perflib, access-denied keys) behave as before.
- **Negative controls:**
  - The leads-back test forced off: `loop391_negctl.txt`, 11 FAIL (every looping row).
  - The pseudo-handle and target checks forced off: `loop391_negctl_review1.txt`, 3 FAIL (COPYTGT 29 keys 28 deep; FINDPERF with a "(6)" box).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- saltests: 30,755 -> 30,798 checks, 0 failed.
- Probes on the final build:
  - loop391: 28 / 0 (English and Czech)
  - 292 `alias292_probe`: 33 / 0
  - 294 `above294_probe`: 24 / 0
  - 296 `link296_probe`: 47 / 0
  - 297 `link297_probe`: 40 / 0
  - 390 `hkcr390_probe`: 10 / 0
- The product's registry key was restored identical after every probe.

## Reviews (findings and what was done)

- **Review 1**
  - MUST: the Perflib language keys open as pseudo-handles, and reading their identity gave a "(6)" box in Find and Copy. Fixed with `SalRegIsPseudoKeyHandle` and probe rows FINDPERF / FINDPERFNT. The reviewer's FINDPERFNT also failed on the old plug-in, because of a pre-391 access-denied box; the row now answers Skip All.
  - SHOULD: a link to the copy target's parent still looped. Fixed with probe row COPYTGT. The first fix ("lies in the target") broke 294's allowed merge (FLATTEN / FLATCOPY), so it was narrowed.
  - NOTEs: coverage, a box read-back artefact and stack use were recorded.
- **Review 2** (no MUST)
  - SHOULD: the narrowed rule still refused links into the target that never loop (COPYPRE / COPYSIB). Replaced by a chain of the target keys being written; rows COPYPRE / COPYSIB added.
  - NOTE 1 (2.6 KB more stack per recursion level): fixed with `noinline` helpers.
  - NOTEs 2 and 3 (identities of 1280+ units fail closed; an HKCR target split over halves is not caught): recorded as limits.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section and versions are the maintainer's, so the run did not create one:

  ```text
  - **Registry Editor: Copy and Find no longer go round in circles through a registry link** (feature 391).
    - **Before:** copying a key whose subkeys held a registry link pointing back at the key itself, at a key above it, or at the key the copy was being written into, copied the same keys over and over - a chain about 28 keys deep was written into the target before an error "Unable to open a registry key. (87)" stopped it. Find listed the same key up to 28 times and ended with the same error.
    - **Now:** each key is copied and found once. Copy shows "Can't copy a key to itself." for the link that leads back (OK skips it and the copy goes on, Cancel stops); Find simply does not go through such a link again. A link pointing anywhere else is followed as before.
    - **Limitation:** the message has no *Skip All*; registry links are made only by special tools, so most users never meet one.
  ```

- No person-step item: every row was driven on the hidden desktop. The Find window was opened with a plug-in hot key posted to the panel; no real keyboard was needed.

## New Inbox items (slug - title)

None. Limits that remain, recorded in the history entry:

- The box has no Skip All.
- An identity of 1280 units or more fails closed.
- An HKCR target whose new subkeys land in the other half is not caught (Windows still stops it with error 87).
- A walk whose start has no identity catches a loop one level later.

Probe note: 257's probe method (Ctrl+Shift+G) opens no Find window while the opt-in browser-like tab shortcuts of 312 are on. This is 312's design, not a defect. The probes of 190–192 and 257 would need another hot key.
