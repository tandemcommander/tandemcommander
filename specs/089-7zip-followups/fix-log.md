# Fix log: feature 089 — 7zip plug-in follow-ups

Branch `089-7zip-followups`, based on `088-plugin-interface-107`. Decisions
by the author (maintainer away): `spec.md` *Clarifications*.

## Baseline (T001)

saltests 1918 / 0; feature 087's engine probe 0 failed on the Debug engine.

## S1 — one RAR association

- `CArchiverConfig::NeverBrowses` (`pack3.cpp`): the archiver has no list
  command by design (RAR console, index 1).
- `src/common/salarcassoc.h`: `SalExtListContains`, `SalExtListRemove`.
- `CSalamanderConnect::AddPanelArchiver` (`plugins1.cpp`), mode *extension
  update, view only*: a record whose external unpacker never browses and that
  holds a requested extension is taken over for viewing (packer and
  extension list kept); the requested extensions it holds leave the
  plug-in's other records; extensions the plug-in already serves are not
  added again; the rest goes to the unchanged legacy code.
- 7zip plug-in: configuration version 5, the registration is repeated once
  for versions 1–4.

**Registry probe** `probe/assoc_probe.ps1` (written and first run by a
separate agent, re-run by the author after the review fixes: 80 PASS, 0
FAIL). Layout found: `HKCU\Software\Tandem Commander\0.1\Packers &
Unpackers\Archive Association\<n>` with `Extension List`, `Packer
Supported`, `Packer Index`, `Unpacker Index`; a plug-in is stored as
`-Index-1` (7zip = -3 here).

| Start configuration | Stored after one start and exit |
|---|---|
| A — the maintainer's real 0.1.8 configuration (plug-in version 3, `rar;r##` RAR/RAR, `7z` plug-in/plug-in) | `rar;r##`: packer 1 (RAR), unpacker -3 (7zip); `7z`: -3 / -3; plug-in version 5 |
| B — 087 development, joined (`7z;rar;r##` of the plug-in + the core record) | the same |
| B2 — 087 development, new-installation shape (already taken over) | the same |
| C — no configuration (first start, no prompt appeared) | the same records (order differs) |
| any of them, second start | association export hash-identical |

Informational (not a failure): a configuration already at core version 106
whose `plugins.ver` counter is current does not load the plug-in at start,
so the repair happens when the plug-in is first loaded — a build with a new
`plugins.ver` (every release) loads all plug-ins at the first start.

The registry key was backed up and restored by the probe; verified identical
(3133 lines, same SHA-256) after every run.

## S2 — surrogate names

- `src/plugins/shared/splunicode.h`: the strict Windows conversion first,
  then the WTF-8 routine of the core, ported header-only
  (`SplUnicodeDetail`). `SplU8ToWExtAlloc` inherits it.
- `src/plugins/7zip/structs.h`: `U8ToUString` / `UStringToU8` use them; 7za's
  own conversion stays only as the fallback for bytes that are not UTF-8.
- saltests `TestSplUnicode089`: parity with `SalWToU8` / `SalU8ToW` and round
  trips over valid text, astral pairs and every kind of unpaired surrogate;
  the exact bytes; 11 malformed inputs rejected (as the core rejects them);
  buffer limits; the extended-length path helper.
- The reviewer's independent brute force: **181,789,444 checks, 0 failures**
  (all 65,535 single units, edge triples, 2 million random strings against an
  independent reference, the core and the old strict call; 35.9 million byte
  strings for the decoder; no over-read at a `PAGE_NOACCESS` boundary).
- Engine level (`probe/surrogate_engine_probe.ps1`): the 26.03 engine stores a
  name with a lone surrogate (`Lone<D800>surrogate.txt`); the installed
  7z.exe extracts it with identical UTF-16 units. The driver of feature 087
  has its own strict conversion, so this says nothing about the plug-in's
  path — that is the unit tests' job.

## S3 — updating a cleaned name

`GetArchiveItemList` stores the cleaned name in `CArchiveItem::Name` and
remembers whether it equals the stored one (`NameIsStoredName`).

## Independent review — ACCEPT, one SHOULD-FIX, fixed

The reviewer compiled the new `AddPanelArchiver` block verbatim against a
mock record store and traced seven stored states (0.1.8, joined in either
order, already taken over, record deleted, another plug-in owns `rar`,
`rar` only, `rar;r##;foo`): results as designed, index handling after
`DeleteFormat` correct, no change for the other `(FALSE, TRUE)` callers
beyond not duplicating an extension.

- **SHOULD-FIX**: with cleaned names two archive items can share a name
  (`a:b.txt`, `a_b.txt`), and the merge replaced whichever sorted first.
  Fixed: the file replaces the item really stored under that name when
  there is one, else the first; the others stay.
- NIT fixed, older defect: an archive **directory** item matched by name was
  dropped from the archive (neither side went onto the update list) — an
  empty folder vanished when the same folder was added again, and a file
  added under a folder's name removed the folder item. The directory item
  now stays; such a file is not packed.
  The reviewer confirmed the fixes and pointed out what the second one also
  repairs: on a **Move** into the archive, a file that met a folder of the
  same name was not packed, yet its source was deleted afterwards
  (`CanDelete` stayed TRUE, `7zip.cpp`); it is kept now.
- NITs fixed: an empty stored path is not cleaned (the listing does not
  either); a comment in `salarcassoc.h`; contract C2 states when the
  take-over does not apply (no RAR-console record claims `rar`).
- Recorded: the take-over block has no unit test of its own (the string
  helpers have; the block was checked by the reviewer's mock and by the
  registry probe over four start configurations).

## Gates

| Gate | Result |
|---|---|
| Debug and full Release builds | succeeded; runtime closure OK; encoding guard `TOTAL: 0` |
| saltests | **2039 / 0** (1918 + converters + extension lists) |
| 087 engine probe (Debug engine) | 0 failed |
| 089 `assoc_probe.ps1` | 80 PASS / 0 FAIL |
| 088 `viewers_probe.ps1` (regression) | 0 failures |
| plug-in interface | 107, no vtable change; `splunicode.h` is header-only |
| `PRIVACY.md` | no change (nothing about network, storage of personal data, credentials, crash reports or the installer) |

## Owed to a person

`quickstart.md`: the associations page after an update; packing into RAR
with WinRAR installed; a lone-surrogate name through the 7zip plug-in in the
GUI; adding into a cleaned-name folder and adding an existing folder again.
