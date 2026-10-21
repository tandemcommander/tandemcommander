# Research - 283 mask code page fold

## R1 Which byte-table sites are reachable with UTF-8 names (measured at cb0d80f5)

| Site (src/masks.cpp) | Reached when | UTF-8 name reaches it? |
|---|---|---|
| `AgreeMaskA` `LowerCase[*filename] == LowerCase[*mask]` (2 lines) | `AgreeMask`: name and mask both ASCII, or one of them is not valid UTF-8 (`SalU8ToWAlloc` fails) | No - anything else goes to `AgreeMaskW` (NFC + `CharLowerW`) |
| `AgreeQSMaskAux` `LowerCase[...]` | only caller `fileswn0.cpp` `AgreeQSMaskU8`: mask and name both ASCII | No |
| `CMaskGroup::AgreeMasks` `StrICmp(ext, mask + 3)` (include, exclude, table) | every mask `PrepareMasks` classified `MASK_OPTIMIZE_EXTENSION` | **Yes** - the defect |
| `COMPUTEMASKGROUPHASH` `LowerCase[...]` | the table (>= 10 EXTENSION include masks) | **Yes** - keys the table |

- Decision: change the classification only; the two unreachable loops stay as they are (their guard comments already say why).
- Rationale: smallest change that routes every non-ASCII `*.xxx` mask to the letter matcher.
- Alternatives considered: (a) a letter-aware comparison in the shortcut and a letter-aware table key - more code, two rules to keep equal to `AgreeMask` (NFC, `CharLowerW`), rejected (spec Clarifications Q3); (b) drop the shortcut entirely - slows every ASCII group, rejected.

## R2 ASCII shortcut mask vs a non-ASCII extension

The shortcut stays for ASCII masks, so a name with an accented extension is still compared with
`StrICmp` against them. A false equality needs every byte of the name's extension to fold to the
ASCII byte of the mask. A UTF-8 multi-byte sequence holds at least one continuation byte
(0x80-0xBF). Decision: prove by saltests that in every ANSI code page (874, 932, 936, 949, 950,
1250-1258) `CharLowerA`'s fold of a byte 0x80-0xBF is never ASCII (emulated: code page -> UTF-16 ->
`CharLowerW` -> code page, as `CharLowerA` does). Then no false match is possible, and a miss is
correct (no character outside ASCII is the same name as an ASCII letter - 092).

`AgreeMask` itself folds with `CharLowerW`, which maps e.g. the Kelvin sign to `k`; an ASCII
`*.k` shortcut mask does not match `x.K` (Kelvin) while `*.k*` does. Pre-existing, not named
by the item, unchanged (spec Assumptions).

## R3 Where the classification is used

`MASK_OPTIMIZE_*` is read only in `masks.cpp` (`PrepareMasks`, `AgreeMasks`) - grep at cb0d80f5.
`CMaskItemFlags` is internal to `CMaskGroup` (not part of the plug-in interface; plug-ins get an
opaque `CSalamanderMaskGroup`).

## R4 Callers (consumers of CMaskGroup::AgreeMasks)

cfgdlg.h, dialogs4.cpp, fileswn1.cpp (Select/Unselect), fileswn3.cpp (filter, thumbnails),
fileswn4.cpp (highlighting), fileswn5.cpp (Convert, ...), fileswn6.cpp / fileswna.cpp (criteria:
Copy/Move masks, Find), fileswn7.cpp / fileswnb.cpp (unpackers / associations), find.cpp,
finddlg1.cpp, mainwnd5.cpp, viewer2.cpp, worker.cpp (Recycle Bin masks), zip.cpp, the plug-in
service (spl_gen.h `CSalamanderMaskGroup`; automation, ftp, renamer). All get the corrected answer
through the one classification; none depends on the classification itself.
