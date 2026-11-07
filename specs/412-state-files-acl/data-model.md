# Data model - 412-state-files-acl

## StateAccess (result of `StateDir.restrictToOwner()`)

| Field | Type | Meaning |
|---|---|---|
| `private` | boolean | the folder itself grants only the user and SYSTEM (POSIX: `chmod 700` succeeded) |
| `contents` | `"reset"` \| `"failed"` | every entry inside inherits from the folder (`"reset"`; POSIX always) or at least one `icacls` call failed |

The launcher secret is stored exactly when `private` is true (unchanged rule of feature 344).

## Access of an entry after a start (Windows)

| Entry | DACL |
|---|---|
| the state folder | protected; full control for the user's SID and SYSTEM, `(OI)(CI)` |
| a file or folder inside | not protected; only ACEs inherited from the folder |
| a link inside | the link entry itself reset; its target untouched |
