# Fix log - 292 Registry Editor: Copy / Move of a key onto itself through another root name

Backlog item `registry-editor-move-of-a-key-onto-itself-through-hkey-users` (source review:287).

## Measured before (main at 9781daee, Debug x64)

1. `NtQueryKey(KeyNameInformation)` from PowerShell (P/Invoke, KEY_READ):
   - `HKCU\Software` and `HKU\<SID>\Software` -> `\REGISTRY\USER\S-1-5-21-...-1001\Software`
   - `HKCU\sOFTWARE` -> `...\Software` (the stored case)
   - `HKCR\.txt` -> `\REGISTRY\USER\<SID>_Classes\.txt`; `HKCR\CLSID` -> `...<SID>_Classes\CLSID`
   - `HKCU\Software\Classes` and `HKU\<SID>_Classes` -> `\REGISTRY\USER\<SID>_Classes`
   - `HKCC\Software` -> `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Hardware Profiles\0001\Software`
   - any root with an empty subkey (HKCU, HKCR, HKCC, HKLM, HKU) -> status `C0000008`
     (`RegOpenKeyExW` hands back the predefined handle itself); `sam` 0 -> open error 5.
2. New probe `probe/alias292_probe.ps1` (fixture under `HKCU\Software\TcProbe292` and
   `HKCU\Software\Classes\TcProbe292`; helpers of 098, structure of 287):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\292-regedt-alias-move-self\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\292-regedt-alias-move-self\probe\alias292_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile specs\292-regedt-alias-move-self\probe\alias292_before.txt"
   ```

   Result: **18 PASS / 9 FAIL**, registry restored identical (SHA-256 34FA77DB...125A).
   - ALIASMOVE: overwrite question "Overwrite HKEY_USERS\<SID>\...\<K>\v with HKEY_CURRENT_USER\...\<K>\v",
     All -> `Zdroj\<K>` and its subkey **gone** (TEXT FAIL, STATE FAIL)
   - ALIASCOPY: overwrite question instead of 1053 (TEXT FAIL); data unchanged (STATE PASS)
   - ALIASINTO: no 1067; the key copied into itself ~16 levels deep, then "Unable to open a
     registry key. (87)" (TEXT FAIL, STATE FAIL)
   - ALIASVALUE: overwrite question, All -> value `v` **gone** (FAIL, FAIL)
   - HKCRMOVE: overwrite question, All -> `Classes\TcProbe292\Zdroj\<K>` **gone** (FAIL, FAIL)
   - ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE: PASS (controls)
   - every END row PASS (exit 0, no report)

## Consumers (enumerated with Grep)

- `CopyOrMoveKey(` - called from `CopyOrMoveFromFS` (fs5.cpp) and from itself (subkeys).
- `CopyOrMoveValue(` - `CopyOrMoveFromFS` (fs5.cpp) and `QuickRename` (fs3.cpp).
- `SafeDeleteKey` - only `CopyOrMoveKey`.
- `CopyOrMoveFromFS` - the plug-in interface entry for F5 / F6 and drag and drop (mode 5) between
  Registry Editor panels.
- `QuickRename` (fs3.cpp): one root, one key (`CurrentKeyRoot` both sides), the target must not
  exist (`TestKey`) - cannot meet an alias; unchanged.

## Decisions

- Identity = the reported internal name (research R1); roots by a fixed rule (R2); HKCR = both
  halves + the opened key, any match refuses (R3, conservative, spec Clarifications).
- Both existing checks are kept and get an "or by identity" (R4); no message added.
- An identity that cannot be established fails closed through the existing boxes (R4).

## Analyze

Two passes: 0 CRITICAL, 0 HIGH. C1 (MEDIUM, root-inside-source edge case not tested) fixed in T003.
C2 (LOW, FR-008 has no own task) - covered by the incremental build (no `.slt` gap) and this log.
U1 (LOW, drag and drop not driven) - an assumption of the spec; the same function serves it.

## Implementation

- `src/common/salregkeyid.h` (new, header-only): `SalRegKeyIdSame`, `SalRegKeyIdWithin`,
  `CSalRegKeyIds` (6 identities of 1280 units), `SalRegKeyIdsAdd` (refuses, never cuts),
  `SalRegKeyIdsAnySame`, `SalRegKeyIdsAnyWithin`.
- `src/plugins/regedt/fs5.cpp`: `AddOpenedRegKeyId` (NtQueryKey KeyNameInformation via
  GetProcAddress; overflow -> ERROR_FILENAME_EXCED_RANGE; other status -> RtlNtStatusToDosError),
  `AddRegKeyIdOf`, `AddRegRootIds` (HKLM / HKU constants, HKCU = RegOpenCurrentUser, HKCC = the
  opened `Hardware Profiles\Current`, HKCR = both class keys, others fail), `GetRegKeyIds` (HKCR:
  both halves joined with the path + the opened key), `SafeGetRegKeyIds` (existing open-error box),
  `AddRegKeyIdsJoined`.
  `CopyOrMoveFromFS`: (1) after the target folder exists, the identity sets of the panel's key and
  of the target folder; an error -> `ErrorL(..., IDS_ACCESS, ...)` and back to the dialog; the
  "onto itself" block runs when the text test OR `SalRegKeyIdsAnySame` (the latter not when one
  folder is the HKCR root - then values are refused in the item loop and keys go to (2)). (2) for
  each key: the text "prefix" test OR `SalRegKeyIdsAnyWithin(target, source)` (target = the opened
  target key, or when it does not exist the target folder ids + new name; source = the opened
  source key); an identity error -> the `RegOperationError(IDS_OPEN)` box (Skip leaves the key,
  Cancel stops); too long -> `IDS_LONGNAME`, stop. (This is the design after the review, see
  *Review*; the first version joined the folder ids also for existing keys and gave every HKCR path
  both halves; the second used the opened HKCR key alone. Final: an HKCR path = each half that
  holds it, opened separately; a two-identity folder -> values refused, keys per key.)
- `src/plugins/regedt/precomp.h` includes the header; `src/saltests/saltests.cpp`
  `TestRegKeyId292`.
- No UI string added or removed; no `spl_*.h` change.

## Checks after

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (and `.\build.cmd rebuild`) | `BUILD SUCCEEDED`; warnings only the pre-existing C4267 of `regedt\fs2.cpp` (untouched) and others outside the feature |
| saltests | `saltests.exe` | `saltests: 25322 checks, 0 failed` (first version); after the review `25321 checks, 0 failed` (the HKCR model rewritten: one check fewer) |
| saltests negative control | `SalRegKeyIdWithin` boundary replaced by `return TRUE`, rebuilt | `25322 checks, 1 failed` (the "Key2" not inside "Key" check); restored, rebuilt, 0 failed |
| probe after (English) | `alias292_probe.ps1` -> `result_after.txt` / `alias292_after.txt` | first version 27 / 0; after the review (row HKCRROOT added) **30 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (34FA77DB...125A) |
| probe after (Czech) | `-Lang czech` -> `result_after_czech.txt` / `alias292_after_czech.txt` | first version 27 / 0; after the review **30 PASS / 0 FAIL**, registry restored identical |
| probe before (negative control) | `-Expect before` on main 9781daee | 18 PASS / 9 FAIL (above) |
| clang-format | VS LLVM `clang-format --lines` on the new code | clean (`saltests.cpp` as a whole is not clean on main either: 1731 lines) |

Not driven: drag and drop between two Registry Editor panels (mode 5) - it reaches the same
`CopyOrMoveFromFS` after the dialog; the root-inside-source case (`HKEY_USERS\<SID>` into
`HKEY_CURRENT_USER\`) - a build without the fix would copy the user's whole hive; it is modelled in
`TestRegKeyId292`, and the sources of the root rule were measured in PowerShell (P/Invoke,
KEY_READ): `RegOpenCurrentUser` -> `\REGISTRY\USER\S-1-5-21-...-1001`;
`HKLM\SYSTEM\CurrentControlSet\Hardware Profiles\Current` -> `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Hardware Profiles\0001`;
`HKLM\Software\Classes` -> `\REGISTRY\MACHINE\SOFTWARE\Classes`.

## Review

### First review (independent agent, refute-first, on commit 80c44acd)

No MUST. Re-ran: build up to date, saltests 25322 / 0, encoding guard 0, probe 27 / 0 (registry
identical); measured that `HKU\S-1-5-18` / `HKU\.DEFAULT`, `CurrentControlSet` / `ControlSet001`
report one name and that a key only in HKCR's machine half reports `\REGISTRY\MACHINE\...`.

| Finding | Done |
|---|---|
| SHOULD 1 (predates 292) Move of a key into the key above its parent, the moved key holding a same-name subkey: the recursion copies onto the source, which is then deleted - reproduced on the hidden desktop, also under one root name | out of scope: Inbox item `registry-editor-move-of-a-key-into-the-key-above-its-parent` (`review:292`) |
| NOTE 2 Copy / Move between the HKCR root (or any HKCR path) and one of its halves refused although the target is another key (e.g. F5 of a machine-only `HKCR\.123` into `HKCU\Software\Classes\`, a real copy before) | fixed in scope: an existing key has only its opened identity (exact, also under HKCR); only the HKCR root has both halves; with the HKCR root as one folder keys are decided one by one, values refused. New probe row HKCRROOT (Move of `HKCR\TcProbe292` - user half only - into `HKCU\Software\Classes\`: refused by its own identity with 1067, unchanged). Spec Clarification, FR-003, research R3 / R4, contract and data model revised |
| NOTE 3 the identity set sized without spare room | moot after NOTE 2 (at most 2 identities now); comment at `SAL_REGKEYIDS_MAX` |
| NOTE 4 not driven: the fail-closed path, Copy into itself via an alias, multi-selection, drag and drop, HKCC / link cases, the root-inside-source case | recorded; the fail-closed path cannot be provoked without also failing the copy's own open; the machine-only HKCR copy (NOTE 2) is not driven either - it would write a per-user file association |
| NOTE 5 `sourceEqualsTarget` set, never read (upstream) | unchanged (not this feature's code) |
| NOTE 6 CHANGELOG / FEATURE-HISTORY not yet written | done at closing |

After the changes: build SUCCEEDED, saltests 25321 / 0, probe English 30 / 0 and Czech 30 / 0,
registry restored identical. The HKCRROOT row was not run on a build without the fix (it would
delete the fixture key there; the first version of this fix gave 1066 for it).

### Second review (independent agent, refute-first, on commit 424d9438)

| Finding | Done |
|---|---|
| MUST 1 a key under HKCR held by both halves reports only the user's half, but its subkeys and values are listed from both and a Move deletes through HKCR: a Move onto `HKLM\Software\Classes\` (elevated) copies the machine-only parts onto themselves and deletes them; also panel `HKCR\X` (X in both) against `HKLM\Software\Classes\X\`, the reverse direction and "into" (`HKCR\K` into `HKLM\Software\Classes\K\`) | fixed: `GetRegKeyIds` gives an HKCR path one identity per half that holds it (`HKLM` / `HKCU` `Software\Classes\<path>` opened separately); the folder check treats any two-identity folder like the HKCR root (values refused, keys per key). `TestRegKeyId292` models `{machine\K, user\K}` against `machine\K` and `machine\K\K` (and the machine-only `.123` copy staying allowed). New probe row HKCRBOTH: a real extension key held by both halves on this machine (`.3fr`), at the HKCR root, F6 into `\HKEY_LOCAL_MACHINE\Software\Classes\`, non-elevated (the row refuses to run elevated), only read. Negative control on the 424d9438 build (`probe/alias292_hkcrboth_424d9438.txt`): TEXT FAIL - "Unable to create a registry key. (5) Access denied" (it went on to write the machine half), nothing changed. Final build: 1067 naming `.3fr`, unchanged. The elevated deletion itself is a step owed to a person |
| NOTE 2 an existing target key that is a registry link pointing outside the source: only its opened identity is used, a Move of S into S\Sub\ through another root name where `S\Sub\<name>` is such a link is not refused; a runaway copy that ends at the long-name box, no delete (also on main; exotic) | recorded, not changed |
| NOTE 3 four identity sets (~61 KB) on the stack | accepted (1 MB stack, 3 MB reserve measured by the first review) |
| NOTE 4 (main too) Move of a machine-only `HKCR\K` into `HKCU\Software\Classes\` copies it to the user's half and then deletes that copy through HKCR: the Move does nothing and reports success; nothing lost | Inbox item `registry-editor-move-from-hkcr-to-user-classes-does-nothing` (`review:292`) |
| NOTE 5 the probe had no key held by both halves; HKCRROOT never run as a negative control | HKCRBOTH added with its negative control (above); HKCRROOT stays without one (it would delete the fixture key on main) |

Checks after the fix of MUST 1: build SUCCEEDED (a C4010 of a new test comment ending in `\`
swallowed the next line `a.Count = 0;` - fixed, rebuilt: no warning from the changed files);
saltests `25330 checks, 0 failed`; encoding guard `TOTAL: 0 finding(s)`; probe English
**33 PASS / 0 FAIL / 0 NOT DRIVEN** (`result_after.txt`, on the build before the comment fix - the
plug-in binary is the same) and Czech **33 / 0** (`result_after_czech.txt`, final build); registry
restored identical both times.

### Third review (independent agent, refute-first, on commit efc150da)

No MUST, no SHOULD. Re-ran: build, saltests 25330 / 0, encoding guard 0, probe 33 / 0 (registry
identical). Measured read-only: all 6,870 HKCR top-level keys exist in at least one half (no new
failure of `GetRegKeyIds`); 251 keys held by both halves list values and subkeys of both; no
machine class key refuses KEY_READ to a non-elevated user. Own scratch rows (fixture `TcReview292`,
real `.3fr` read only, non-elevated) 22 / 0: a value from `HKCR\.3fr` into
`\HKLM\Software\Classes\.3fr\` refused (1066); keys from it decided one by one (a user-only subkey
let through to "access denied", a machine-only one refused with 1067); the reverse direction
refused; HKCR root into `\HKEY_USERS\<SID>_Classes\` refused; controls work.

| Finding | Done |
|---|---|
| NOTE 1 an unset (Default) value in a two-identity folder raised 1066 and ended the operation (it was skipped before) | fixed: the unset default is skipped before the refusal (`fs5.cpp`, item loop) |
| NOTE 2 values of a two-identity folder refused even when the write would reach the other half; a value rename there too | accepted (spec FR-003, conservative; nothing lost) |
| NOTE 3 where `RegCreateKeyEx` through HKCR creates a key that does not exist yet is assumed (the half of the deepest existing ancestor), not measured - needs elevation; a wrong assumption gives the runaway copy ending at the long-name box, no delete | owed to a person (person-step item) |
| NOTE 4 closing documents pending | done at closing |

Final checks (after the NOTE 1 change): build SUCCEEDED (no warning from the changed files);
saltests `25330 checks, 0 failed`; encoding guard `TOTAL: 0 finding(s)`; probe English
**33 PASS / 0 FAIL / 0 NOT DRIVEN** and Czech **33 / 0** on the final binary; registry restored
identical (34FA77DB...125A) every time.
