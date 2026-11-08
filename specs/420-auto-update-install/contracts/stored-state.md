# Contract - stored state (feature 420)

Extends `specs/123-new-version-check/contracts/stored-state.md`. All values live in
`HKCU\<configuration root>\Update Check`, are written at once and read fresh, like 123's.

| Value | Type | Written by | Rule |
|---|---|---|---|
| `Update Level` | REG_DWORD 0/1/2 | General page | absent or > 2 = 1 |
| `Install Version` | REG_SZ | arming | `<a>.<b>.<c>`, ASCII |
| `Install Digest` | REG_SZ | arming | 64 lowercase hex |
| `Install Source` | REG_DWORD 1/2/3 | arming | 1 user, 2 automatic, 3 offered only (never honoured) |
| `Install Test` | REG_DWORD 0/1 | arming | test mode |
| `Install Launches` | REG_DWORD | each start of the installer | 0..3 |
| `Install Confirmed` | REG_DWORD | Install When I Close, Yes to the question, a start that failed before anything ran | <= `Install Launches`; optional (missing = 0) |

The `Install` values are written and removed together; a missing or invalid one of the first five =
nothing armed (`Install Confirmed` is optional). Test mode writes the `Install` values (with `Install Test` = 1) but none of 123's values.
Configuration export / import carries them like 123's values (the key is under the configuration
root); importing replaces them. `PRIVACY.md` *New version check* lists them.
