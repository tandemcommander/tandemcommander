# Contract: Configuration Migration to Version 106 (feature 084)

Covers FR-007 and SC-005, and clarification Q4 (entries referring to a
removed archiver are removed whether or not the user edited them).

## M0 — When it runs

- **Gate**: `ConfigVersion < 106 && !packersResetToDefaults`. On a fresh
  registry `ConfigVersion` is 0 and the defaults are used instead, so no
  migration runs.
- **Where**: in the configuration load block, after the four `Packers &
  Unpackers` sections are read and before `Plugins.CheckData()`.
- **Persistence**: the result is saved with the configuration, and
  `THIS_CONFIG_VERSION` becomes **106**.
- **Idempotent**: running the pure functions twice on their own output changes
  nothing (tested), with one exception the version gate makes harmless.
  `SalArcMigAssociation` deletes an index-0 record. Before 106 index 0 was JAR;
  after the migration it is 7-Zip, whose records M3 adds. The migration never
  runs on a configuration that is already at 106 (review nit 8).

## M1 — Custom packers and unpackers

For each **external** entry (Type 0), in both lists, the entry is **deleted**
if **either** holds:

1. One of its command or argument fields contains, case-insensitively, a
   token `$(<v>)` with `<v>` in the *removed variables* set
   ([data-model §7](../data-model.md)).
2. Its argument field (copy or move) is byte-identical to one of the former
   floppy-volume defaults (the `-v1440` / `-pav1440` strings of
   `packers.cpp:56-105` at 0.1.8).

Plug-in entries (Type < 0) and external entries matching neither rule are left
**byte-identical**. That includes entries using `$(Rar32bitExecutable)` with
their own arguments, and entries calling their own program path.

The *preferred packer/unpacker* index is adjusted exactly as `DeletePacker`
does today. If the preferred entry itself is deleted, the stored preference
becomes "none" (-1), as `DeletePacker`/`DeleteUnpacker` leave it. The Pack and
Unpack dialogs then pre-select the first entry that is offered
(`GetOfferedPreferedPacker`/`GetOfferedPreferedUnpacker`); an earlier wording
of this paragraph said the preference itself falls back (final review #3).

**Amendment (implementation, 2026-10-01; fix-log T007)**: the 0.1.8 defaults
for RAR carry stored titles like "RAR (External Win32, tested with v2.50)",
which SC-002 forbids, and OEM list files. Two more rules apply to them:

- **M1b**: a packer whose copy and move commands are both `$(Rar32bitExecutable)`
  and whose arguments equal the 0.1.8 default pair (with or without `-scol`)
  is **rewritten** to the new default. Its title becomes "RAR (WinRAR)" in the
  current language, and its arguments become the UTF-16 list form.
- **M1c**: an unpacker `$(Rar32bitExecutable)` with the 0.1.8 default arguments
  (with or without `-scol`) is **deleted**, because RAR is unpacked by the 7zip
  plug-in.
- **M1d**: when no unpacker calls `$(SevenZipExecutable)`, the 7-Zip default
  unpacker is appended. This is done in the migration, not in
  `AddDefault(105)`, because `case 0` falls through and a fresh configuration
  would get it twice.

RAR entries with any other arguments are kept byte for byte.

## M2 — Archive associations

For each record:

| Old unpacker | Old packer | Result |
|---|---|---|
| plug-in (< 0) | any | unpacker kept; packer handled by the next rows |
| 1 (RAR) | — | **kept** as index 1. The RAR row has no browse operations any more, so the runtime table skips this unpacker (data-model §2). When RAR is exposed (R3), the 7zip plug-in's `AddPanelArchiver("rar;r##", …, update)` takes the record over: unpacker becomes the plug-in, packer stays RAR index 1 (the existing overlap-takeover in `plugins1.cpp:866-1069`) |
| removed (0, 2–11) | — | **record deleted** |

| Old packer (record kept) | Result |
|---|---|
| plug-in (< 0) | kept |
| 1 (RAR) | kept as new index 1 |
| removed | `Packer Supported` = false |

*Note on `rar;r##`*: a record whose unpacker was already taken over by a
plug-in (e.g. a user who once enabled `unrar`) is kept with its plug-in
unpacker and, if its packer is 1, keeps RAR packing.

## M3 — 7-Zip default extensions

After M2, for each extension in the 7-Zip default set (fixed in
`inventory.md`, minimum `arj`, `a##`, `lzh`, `lha`) that **no remaining record
claims**, add one record: unpacker = 0 (7-Zip), packing not supported.

*As built* (final review #3): the set is two record groups,
`{"arj", "lzh;lha"}` (`SevenZipDefaultExtGroups`, `packers.cpp`). For each
group, one record is added holding the group's extensions that no remaining
record claims (none added when all are claimed); `a##` is not added.

## M4 — Predefined Packers

No code is needed. Rows with retired UIDs are ignored on load and are not
written back. The RAR row (UID 2) keeps its stored executable path.

## M5 — Everything else

Outside `Packers & Unpackers`, the migration changes **nothing**. The verifier
for SC-005 compares a registry export before and after. Its allow-list holds
only the pre-existing side effects of any configuration-version bump:

- `Version\Configuration`;
- `LastPluginVer` and `LastPluginVerOP`;
- the plug-in auto-install bookkeeping;
- `ShowSLGIncomplete`.

## M6 — Downgrade

Not supported. 0.1.8 reading a 106 configuration may interpret index 0 as its
JAR row, which affects only the 7-Zip records. Recorded in `CHANGELOG.md`.
