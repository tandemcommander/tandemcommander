# Data model - 345-ftp-upload-cache-user-port

No new data. Existing structures (feature 341), with the changed meaning:

- **Connection identity** - (host as typed, compared with `StrICmp`; user, `anonymous` = NULL,
  compared exactly; port). Equal identity = "own"; any difference = "maybe the same server".
- **CUploadListingsOnServer** (`ListingsOnServer`) - cached listings of one identity. A change
  reported for identity X: X's own entry applies the report; **every other entry** invalidates all
  its listings (before: only entries with X's user and port).
- **CUploadChangeStamp** (`ChangeStamps`) - latest change time per identity, bound 1,000, then
  `ChangeStampsLost` (fails closed). A panel listing of identity Y started at T is refused when
  **any stamp of another identity** is newer than T (before: only another host with Y's user and
  port).
