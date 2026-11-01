# Data model - 373-wsl-share-list

No stored data. The one entity is the answer of the share-list job (`CUncSharesJob`):
`Shares[0..Count)` (UTF-8 names, hidden flag) and `Error` (0 or a Win32 error).

## Decision table (pure rules in `src/common/saluncserver.h`)

`firstErr` = the error of the `NetShareEnum` loop (0 = none), `count` = shares read by it,
`providerErr` = the result of the provider enumeration (0 = it ended normally).

| firstErr | count | Providers asked? (`SalUncShareListAsksProviders`) | Error after the providers (`SalUncProviderListError`) | otherwise Error |
|---|---|---|---|---|
| 0 | any | no | - | 0 |
| 53 | 0 | **yes (373; before: no)** | 0 when they gave a share, else 53 | - |
| 53 | > 0 | no | - | 53 (the list is shown: count > 0) |
| 51, 1231, 1232 | any | no | - | firstErr |
| `ERROR_MORE_DATA` | 0 | yes (as before) | 0 when they gave a share, else firstErr | - |
| `ERROR_MORE_DATA` | > 0 | no | - | `ERROR_MORE_DATA` |
| any other (5, 1326, 1707, ...) | 0 | yes (as before) | 0 when they gave a share, else firstErr | - |
| any other | > 0 | no | - | 0 (as before) |

`SalUncServerNotFoundErr(err)` = err in {53, 51, 1231, 1232} - today's `notFound` set,
unchanged; it decides the "otherwise Error" column together with `ERROR_MORE_DATA`.
