# Contract: stored state

**Feature**: 123-new-version-check. `PRIVACY.md` lists these values — change
them together.

## Location

`HKEY_CURRENT_USER\Software\Tandem Commander\0.1\Update Check`

A new subkey of the existing registry root. No `THIS_CONFIG_VERSION` bump, no
migration. Absent key or value = default.

| Value | Type | Content | Default |
|---|---|---|---|
| `Check At Startup` | `REG_DWORD` | 1 = on, 0 = off | 1 |
| `Last Attempt` | `REG_QWORD` | UTC `FILETIME` of the last claimed check | absent |
| `Last Attempt Answered` | `REG_DWORD` | 1 if that attempt received an HTTP status (also when the body then failed); 0 while the attempt runs, when nothing answered, and after a cancel | 0 |
| `Last Success` | `REG_QWORD` | UTC `FILETIME` of the last valid answer | absent |
| `Latest Version` | `REG_SZ` | `<major>.<minor>.<patch>` | absent |
| `Latest Published` | `REG_SZ` | `YYYY-MM-DDThh:mm:ssZ` | absent |
| `Skipped Version` | `REG_SZ` | `<major>.<minor>.<patch>` | absent |

Nothing else is stored: no address, no text from the answer, no history of
checks, no identifier.

## Rules

1. **Written at once, read fresh.** A value is written when it changes, not
   with the configuration on exit; every use reads the registry again. The
   values are not members of `Configuration` and are not touched by
   *Save configuration on exit* or the configuration version logic.
   *Export Configuration* copies the whole registry branch, so an exported
   file contains them, and an import replaces them. The two places that clear
   the whole branch (removing a damaged configuration, and overwriting the
   configuration during an upgrade import) remove them too: the option is
   then back at its default, on.
2. **Read defensively.** A value of the wrong type, an unparsable version or
   date, or a time in the future is treated as absent.
3. **One claim per interval.** Reading the state, deciding that a check is due
   and writing `Last Attempt` happen under the named mutex
   `Local\TandemCommanderUpdateCheck` (per logon session).
4. **Failure keeps knowledge.** Only `surNewer` / `surUpToDate` write
   `Last Success`, `Latest Version`, `Latest Published`.
5. **A store that cannot be written** (policy, read-only hive): the check still
   runs for this instance; the claim and the choices simply do not persist. No
   error is shown.
6. **Older versions.** 0.1.8 and older never read the subkey; they must keep
   working with it present (verified by a probe row). Uninstalling leaves it
   with the rest of the per-user data, as documented.
7. **Kernel object names** use the product's `TandemCommander…` prefix
   (feature 046).

## Window property

A visible notification window carries the property
`TandemCommander.UpdateNotice` (value 1) so that other instances of the same
user can find it (`EnumWindows` + `GetProp`) — the basis of "one notification
per user" — and `TandemCommander.ClosesUnattended` (feature 088) so that an
installer's update can close the program while it is open.
