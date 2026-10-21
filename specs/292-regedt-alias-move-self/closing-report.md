# Closing report - 292-regedt-alias-move-self
Backlog item: registry-editor-move-of-a-key-onto-itself-through-hkey-users - Registry Editor: Move of a key onto itself through HKEY_USERS deletes the key
Outcome: closed

## What changed

- `src/common/salregkeyid.h` (new, header-only): the identity rule - `SalRegKeyIdSame`,
  `SalRegKeyIdWithin` (case ignored, whole path elements), `CSalRegKeyIds` with `SalRegKeyIdsAdd`
  (refuses a name that does not fit, never cuts), `SalRegKeyIdsAnySame`, `SalRegKeyIdsAnyWithin`.
- `src/plugins/regedt/fs5.cpp`: a key's identity is the full internal name the registry reports for
  the opened key (`NtQueryKey` KeyNameInformation, links followed); roots by a fixed rule; a path
  under `HKEY_CLASSES_ROOT` is each half that holds it. `CopyOrMoveFromFS`: the "target folder is
  the panel's key" check and the "target key inside the source" check also compare identities; a
  folder of two identities (HKCR) against one of them refuses values and decides keys one by one;
  an identity that cannot be read stops through the existing error boxes. No UI string added.
- `src/plugins/regedt/precomp.h` includes the header; `src/saltests/saltests.cpp`
  `TestRegKeyId292`.

## Measurements (before / after, commands)

Probe `specs/292-regedt-alias-move-self/probe/alias292_probe.ps1` on the hidden desktop
(`tools\run_on_hidden_desktop.ps1`, command lines in `fix-log.md`):

- before (main 9781daee): 18 PASS / 9 FAIL - ALIASMOVE (key gone), ALIASVALUE (value gone),
  HKCRMOVE (key gone), ALIASCOPY (no refusal), ALIASINTO (nested copies).
- after (final build): English 33 PASS / 0 FAIL / 0 NOT DRIVEN, Czech 33 / 0; registry restored
  identical each time. Rows added during the reviews: HKCRROOT, HKCRBOTH (HKCRBOTH on the build of
  424d9438: FAIL - it went on to write the machine half).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`
- `.\build.cmd`: `BUILD SUCCEEDED` (no warning from the changed files)
- `saltests.exe`: `saltests: 25330 checks, 0 failed`; negative control (boundary check broken):
  1 failed
- probe: as above

## Reviews (findings and what was done)

- First (80c44acd): no MUST; SHOULD 1 (predates: Move into the key above the parent loses a
  same-name subkey) -> Inbox; NOTE 2 (every HKCR path as both halves refused real copies) -> fixed.
- Second (424d9438): MUST 1 (an HKCR key held by both halves; an elevated Move onto the machine
  half would delete it) -> fixed (each half that holds the path), probe row HKCRBOTH with a
  negative control; NOTE 4 (Move from machine-only HKCR into the user's Classes does nothing) ->
  Inbox.
- Third (efc150da): no MUST, no SHOULD; NOTE 1 (unset default value refused) -> fixed; NOTE 3
  (where HKCR creates a key) -> person step.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `registry-editor-292-elevated-hkcr-checks` - Registry Editor 292: elevated checks of Move through
  HKEY_CLASSES_ROOT (the elevated refusal and where a key created through HKCR lands).
- Not driven otherwise: drag and drop between two Registry Editor panels (the same function),
  the fail-closed path, `HKEY_CURRENT_CONFIG` / link cases, the root case `HKEY_USERS\<SID>` into
  `HKEY_CURRENT_USER\` (modelled in saltests).

## New Inbox items (slug - title)

- `registry-editor-move-of-a-key-into-the-key-above-its-parent` - Registry Editor: Move of a key
  into the key above its parent loses a same-name subkey
- `registry-editor-move-from-hkcr-to-user-classes-does-nothing` - Registry Editor: Move from HKCR
  into the user's Classes key does nothing
- `registry-editor-292-elevated-hkcr-checks` - Registry Editor 292: elevated checks of Move through
  HKEY_CLASSES_ROOT (person step)
