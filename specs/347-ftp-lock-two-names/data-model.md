# Data model - 347-ftp-lock-two-names

## Opened-file lock entry (`CFTPOpenedFile`, unchanged layout)

| Field | Role before | Role after |
|---|---|---|
| UID | identifier | unchanged |
| AccessType | read / write / delete / rename | unchanged |
| User | identity (exact) | unchanged |
| Host | identity (`StrICmp`) | **stored only, not compared** |
| Port | identity | unchanged |
| Path, PathType | identity (`FTPIsTheSameServerPath`) | unchanged |
| Name | identity (case rule of the server type) | unchanged |

Identity rule after: `User` equal (`strcmp`) AND `Port` equal AND same path by the server type AND
same name by the server type's case rule.

Conflict rule (`IsInConflictWith`): unchanged - different access types conflict; two writes
conflict; two reads / deletes / renames of the same type do not.
