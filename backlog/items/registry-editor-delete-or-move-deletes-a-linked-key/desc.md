---
title: Registry Editor: Delete or Move of a key holding a registry link deletes the linked key
type: bug
status: open
severity: 7
area: data-safety
source: measure:296
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: 2026-10-22 49147f36
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: Delete or Move of a key holding a registry link deletes the linked key

## Problem

Delete (F8) or Move (F6) in the Registry Editor of a key whose tree holds a registry symbolic link
(a key made with `REG_OPTION_CREATE_LINK`, possible without elevation under HKCU) works through the
link by name: the delete recursion enumerates and deletes the subkeys of the key the link points at,
then `RegDeleteKeyW` on the link's name deletes **that key** - a key outside the selection, possibly
anywhere in the user's hive - while the link itself stays (so the selected key cannot be removed
either: "Unable to remove ..."). A Move also first copies the linked key's content into the target as
a plain key. The user loses a key they never selected, without being told.

## Evidence

Measured during feature 296 (`specs/296-regedt-link-target-tree/fix-log.md`, *Out of scope*): a
scratch script (`HKCU\Software\TcLinkDel296`, removed) created `Src\L` as a link to `Elsewhere`;
`RegDeleteKeyW(HKCU, "...\Src\L")` returned 0 and `Elsewhere` was gone, the link `Src\L` still there
(removed only by `NtDeleteKey` on a handle opened with `REG_OPTION_OPEN_LINK`). Sites at the closing
commit of 296: `CPluginFSInterface::DeleteKey` (`src/plugins/regedt/fs3.cpp`, `RegOpenKeyExW` +
`RegEnumKeyExW` through the link, then `RegDeleteKeyW(..., keyName)`), and for Move `SafeDeleteKey`
(`src/plugins/regedt/fs5.cpp`, `RegDeleteKeyW`) after `CopyOrMoveKeyRec` opened `source\L` by name.
Not driven in the program (reasoned from the code plus the measured API behaviour).

## Expected

Deleting or moving a key that holds a registry link never touches the key the link points at: the
link itself is removed (opened as a link) or the operation is refused for it with a message; a Move
does not turn the link into a copy of its target silently.

## Notes

Feature 296 fixed the opposite direction (a link in the **target** tree). The decision how a Move
should treat a link (recreate the link in the target, copy its target, or refuse) may need the
maintainer; refusing with the existing messages is the conservative option. Also check Export and
Find, which walk the tree by name too (they only read, but may walk out of the selected tree or loop).

## Log

- 2026-10-22 — created (source measure:296)
- 2026-10-22 — moved to Next position 1
- 2026-10-22 — verified at 49147f36: reproduced at 49147f36 by a hidden-desktop probe: F8 / F6 / Quick Rename of a key holding a link, or of the link, deleted the linked key (also via HKCR)
