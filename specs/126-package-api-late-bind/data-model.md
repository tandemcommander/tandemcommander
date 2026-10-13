# Data model: feature 126

No stored data.

`CSalShellPackageApi` - the two functions of the package lookup as a value:

| Member | Meaning |
|---|---|
| `GetPackagesByPackageFamily` | kernel32, Windows 8+; NULL when absent |
| `GetPackagePathByFullName` | kernel32, Windows 8.1+; NULL when absent |

Rule: the lookup needs both; with either NULL (or the table itself NULL) the answer is
"not found" and the caller's buffer is an empty string. The table is filled per lookup and
never cached.
