# Data model - feature 394

## SCommonHeader (plug-in internal, `src/plugins/tar/tar.h`)

| Field | New | Meaning |
|---|---|---|
| `Ignored` | - | not extracted under its own name |
| `NameRefused` | - | (308 / 393) the name cannot be used; an extraction asked for it fails |
| `NameEmpty` | yes | (394) a cpio member whose name normalizes to nothing; also `Ignored`; never asked; may carry a hard-linked file's data |

`Initialize` resets `NameEmpty` to FALSE.

## Group membership (`SalCpioKeepsGroupMember`)

member stays in its group ⇔ not a folder ∧ (not ignored ∨ ignored only for an unusable name) ∧
newc/crc ∧ regular file ∧ nlink > 1.

## Group states

Unchanged (`SAL_CPIO_GROUP_NONE / WRITTEN / LOST`, feature 310).
