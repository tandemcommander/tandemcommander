# Research - 348-ftp-lock-user-port

## R1 - Which connections are maybe the same server for the lock?

- **Decision**: every connection. Only the server path (`FTPIsTheSameServerPath` for the path
  type) and the file name (case-sensitive or `SalNameOrderEqualCI` by the path type) decide.
- **Rationale**: the item's *Expected* ("two users or two ports of a server do not write it at the
  same time"); feature 345 took the same step for the upload listing cache (every other connection
  is maybe the same server); 347 took it for host names. Neither the user name nor the port proves
  two servers: two accounts can share folders, one server can be reached through a forwarded port.
- **Alternatives considered**: (a) drop only the port, keep the user - leaves the item's main row
  (OTHER-USER) failing; (b) compare user only when both connections reach the same host - 347
  already made the host meaningless (rows ALL-OTHER would still fail); (c) make the second access
  wait instead of refusing - new waiting machinery in every caller, risk of deadlock between two
  operations each holding one lock; the item accepts refusing.

## R2 - Cost

- Two unrelated servers or accounts with files of the same server path and name (`/index.html`,
  chrooted accounts) now refuse each other's *conflicting* access while one runs (an upload with
  anything; a delete / rename with another kind of access). Two downloads still run together.
  The refused item fails "in use" and can be retried (`Retry` in the operation dialog); nothing is
  lost. Same class of cost as 347's (host) and 345's (listing cache), named in the item's *Notes*.

## R3 - Callers (to confirm at implementation)

`FTPOpenedFiles.OpenFile` sites (Grep): `operatsb.cpp` (upload: 3), `operats8.cpp` (download /
Move source read, Move delete: 2), `operats4.cpp` (delete: 1), `ctrlcon5.cpp` (panel view: 1;
Quick Rename from / to: 2). Every caller passes its own connection's user / host / port; one
operation holds one lock per worker, Quick Rename locks two names on one connection - no
self-conflict is introduced by ignoring user / port (one connection has one user and port).
