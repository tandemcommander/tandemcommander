# Closing report - 296-regedt-link-target-tree
Backlog item: registry-editor-move-through-a-link-in-the-target-tree - Registry Editor: Move into a key holding a registry link to the source writes into the source
Outcome: closed

## What changed

`src/plugins/regedt/fs5.cpp` only:

- `CopyOrMoveKey` (signature unchanged; callers `CopyOrMoveFromFS` - F5 / F6 / drag and drop - and
  `QuickRename`) is a wrapper around the static recursion `CopyOrMoveKeyRec`, which carries the
  operation's source (`CRegCopyTop`: root, heap copy of the path, identities read lazily).
- `SafeCheckTargetLink`, before every target key is created: the key opened as a link
  (`REG_OPTION_OPEN_LINK`, `SymbolicLinkValue` of type `REG_LINK`). No key / no link = as before. A
  link into the source (identity, 292's rule) or holding the source with the path back (294's rule,
  its loop now the shared `SafeRegKeyIdsReachSource`) = the existing "Can't move/copy a key to
  itself." box naming the full source key (OK skips, Cancel stops); a dangling link and every other
  error = the existing open-error box (fails closed); other links followed as before.
- No UI text, no plug-in interface change, nothing stored.

## Measurements (before / after, commands)

Probe `specs/296-regedt-link-target-tree/probe/link296_probe.ps1` through
`tools\run_on_hidden_desktop.ps1` (commands in `fix-log.md`):

| Build | Rows | Result |
|---|---|---|
| `main` 4420aae1 (`-Expect before`) | 10 rows | 14 PASS / 15 FAIL: Move lost z=9 / w=7 without a box, Copy wrote into the source, dangling links created keys inside it |
| feature, before the review | 10 rows | 29 PASS / 0 FAIL (English and Czech) |
| feature, after the review | 16 rows (+ link two levels up, second level, chain, Quick Rename onto a dangling link, Quick Rename control, HKCR view) | 47 PASS / 0 FAIL (English and Czech) |
| negative control: chain branch off | LINKUP, LINKMOVE | 2 FAIL (LINKUP) |
| negative control: the check off | the six new rows | 10 FAIL |

Registry restored identical after every run (SHA-256 34FA77DB...125A).

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- Build `build.cmd` Debug x64: BUILD SUCCEEDED (first attempt C2082, a parameter name clash, fixed).
- `saltests`: `26304 checks, 0 failed` (no rule changed).
- Probes: `link296_probe` 47 / 0 English and Czech; 292's `alias292_probe` 33 / 0; 294's
  `above294_probe` 24 / 0.

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD 1 (HKCR not shown): measured that HKCR passes
`REG_OPTION_OPEN_LINK` through, row HKCRMOVE added (fails without the check). SHOULD 2 (probe gaps):
the review's five scratch rows moved into the probe. NOTEs accepted (no Skip All in the refusal box,
the box does not name the link, dangling links elsewhere now refused, FR-005 not driven). Details in
`fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

Nothing. The change is driven completely on the hidden desktop (no keyboard, clipboard or elevation
needed); HKLM targets follow the same code and are not driven (they need administrator rights to
create a link; no data-loss route differs).

## New Inbox items (slug - title)

- registry-editor-delete-or-move-deletes-a-linked-key - Registry Editor: Delete or Move of a key holding a registry link deletes the linked key
