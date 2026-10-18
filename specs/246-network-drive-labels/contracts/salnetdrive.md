# Contract: `src/common/salnetdrive.h` (feature 246)

Header-only, pure (no system state; `CompareStringOrdinal` is the only Windows call), wide
strings. Checked by `saltests` (`TestNetDrive246`). Used by `src/drivelst.cpp`.

## `BOOL SalNetDriveNameKey(const WCHAR* remote, WCHAR* key, int keySize)`

Explorer's `MountPoints2` sub-key name for a mapped network path.

- `remote` must be a UNC path `\\server\share[\path…]`: starts with exactly two
  backslashes, a non-empty server, a non-empty share. Trailing backslashes are ignored.
- Result: `##server#share#path…` — the leading `\\` becomes `##`, every further `\`
  becomes `#`; all other characters (also `#`, non-ASCII, spaces) are copied unchanged.
- FALSE (and `key[0] = 0` when `keySize > 0`): `remote` NULL or empty; not starting with
  `\\`; `\\?\…` or `\\.\…` (device prefixes); empty server (`\\\x`); no share
  (`\\server`, `\\server\`); an empty component inside (`\\srv\\x`); the key does not fit
  `keySize` units with its terminator (refused, never cut).

## `int SalNetDriveCleanName(WCHAR* name)`

Cleans a name read from the registry in place; returns its length in units (0 = no name).

- Every unit below U+0020 and U+007F becomes a space (tabs would split the menu's
  columns, line breaks would break a menu line).
- Leading and trailing spaces are removed.
- NULL → 0.

## `int SalNetDriveText(const WCHAR* name, const WCHAR* remote, BOOL doubleAmpersands, WCHAR* out, int outSize)`

The text shown for a mapped drive (menu column 2 or tooltip).

- `name` NULL/empty, or equal to `remote` by `CompareStringOrdinal(..., TRUE)` → `remote`.
- Otherwise `name + L" (" + remote + L")"`.
- `remote` NULL → treated as empty (the result is then `name` alone, or empty).
- `doubleAmpersands` → every `&` in the result is written as `&&` (the menu draws the
  column with prefix processing; the tooltip passes FALSE).
- Returns the number of units needed **including** the terminator. Writes the text only
  when `out != NULL && outSize >= needed`; otherwise writes `out[0] = 0` when
  `out != NULL && outSize > 0`. Never cuts.

## `BOOL SalNetDriveIsDisconnected(BOOL listed, DWORD connResult, DWORD conn3Result, DWORD conn3State)`

- `!listed` → TRUE (the letter is missing from `GetLogicalDrives()`: a remembered
  connection Windows did not restore — today's rule).
- `connResult == 1201` (`ERROR_CONNECTION_UNAVAIL`) → TRUE.
- `connResult == 0 && conn3Result == 0 && conn3State == 1` (`WNGC_DISCONNECTED`) → TRUE.
- Otherwise FALSE (an unknown answer keeps today's "connected" — fail-open is right here:
  the icon is informational, and picking the drive reconnects on access anyway).

Constants are repeated in the header (`SALNETDRV_ERROR_CONNECTION_UNAVAIL`,
`SALNETDRV_WNGC_DISCONNECTED`) because `saltests` does not include `winnetwk.h`; a
`static_assert` in `drivelst.cpp` ties them to the SDK values.
