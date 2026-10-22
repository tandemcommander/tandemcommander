# Research: 304 - plug-in folder picker and long folder-shortcut targets

All measured at 3fa858bb on Windows 11 (10.0.26300), programs in `probe/` (see `fix-log.md`).

## R1 - Does GetPath cut, and does a larger buffer help?

- Decision: treat every `GetPath` answer of MAX_PATH - 1 = 259 units or more as possibly cut.
- Rationale: on a drive without 8.3 names `GetPath(SLGP_UNCPRIORITY)` answers NOERROR with exactly
  259 units for targets of 260, 261, 300 and 400 units, with a 260- and with a 32,768-unit buffer
  (the shell cuts internally). On a drive with 8.3 names it answers the short form (whole, the
  same folder). A target of 259 units is answered whole - so 259 alone cannot tell "whole" from
  "cut".
- Alternatives: a 32,768-unit buffer only (the item's hint) - measured not enough; `SLGP_RAWPATH`
  - not tried as the fix: it would change the answer for every shortcut (environment strings),
  not only the long case.

## R2 - Where is the whole name?

- Decision: `IShellLinkW::GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`.
- Rationale: measured - it gives `\\?\D:\...` with the whole 260..400 units on D:, the plain
  259-unit name for 259, and the same 8.3 form as `GetPath` on C:.
- Alternatives: reading the LinkInfo block of the `.lnk` by hand - a file-format parser for no
  gain.

## R3 - When to follow the item-list name

- Decision: compare in the plain form (`\\?\UNC\` → `\\`, `\\?\` removed), ordinal, ignoring case
  (`CompareStringOrdinal`): the answer equal to the item-list name → whole; the answer a prefix of
  it (longer item-list name) → the item-list name is the whole of what was cut → follow it; any
  other difference (e.g. the UNC form of a mapped drive vs the drive form), no item list, or no
  file-system name → refuse.
- Rationale: follows whole where provable (UnCAB's 780-byte buffer can take a 300-unit ASCII path),
  fails closed otherwise (CLAUDE.md: refuse rather than cut).
- Alternatives: always refuse 259+ units - would refuse a whole 259-unit target that is followed
  today (a regression); always take the item-list name - would drop the UNC preference for short
  targets (behaviour change outside the item).

## R4 - How to write such a shortcut in a test

- Decision: build the item list folder by folder (`SHParseDisplayName` of a short base +
  `IShellFolder::ParseDisplayName` per component + `ILCombine`), `SetIDList`, save.
- Rationale: `SetPath` refuses 260+ units (E_FAIL), `SHParseDisplayName` of the long path yields
  the 8.3 form. The cut appears only on a volume without 8.3 names: saltests uses `%TEMP%` and,
  when `%TEMP%` has 8.3 names, also the folder of `saltests.exe` (the build folder); the identity
  assertion (the result names the target folder or the pick is refused) holds on both.
