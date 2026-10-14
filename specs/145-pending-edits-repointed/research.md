# Research: feature 145

## R1 - Measured (`probe/result_pre145.txt`, `Debug_x64` at `83727d38` = 0.1.10 core + 144)

- `resubst-pending`: the right panel opens `T:\arc.zip` (A), F4 on x.txt (a copy with one
  marker), `T:` re-pointed to B (a twin: 131 bytes, the same write time), the panel leaves the
  archive: *Update All* packed the copy into **B\arc.zip** - B's x.txt "content-of-member-1" +
  the marker; A unchanged. FAIL.
- `replace-pending` (control): the archive replaced at the same place by a renamed new file (x.txt
  tag 9), F4 edit pending: the core notices the change ("has changed. Archive will be reopened"),
  and leaving packs the edit into the new file. PASS - must stay so.

## R2 - Why

`CFileTimeStamps::CheckAndPackAndClear` (salamdr3.cpp) packs into `ZIPFile`, the name stored at
F4; the refresh's change test (fileswn2.cpp, "already opened archive") compares size and time
only. Nothing knows what the name led to.

## R3 - Decision: the final path, not the file id

- File id (144's `ZIPArchiveIdentity`): differs for the control too (rename over = a new file
  object) - would refuse a legitimate update. Rejected.
- Final path (`GetFinalPathNameByHandle`, normalized, DOS volume name - feature 107's
  `SalGetFinalPathU8Alloc`): A\arc.zip vs B\arc.zip for the re-point; the same path for the
  control. Chosen; split into a handle variant `SalGetFinalPathOfHandleU8Alloc` so the open takes
  it from the handle that gives the date and size (as 144 does for the identity).
- Either path unknown: no decision (the behaviour before).
- Refusal text: the existing `IDS_UPDATEFAILED` (Yes = try again, No = the Archive Update dialog
  with *Copy Selected To...*) - it does not say why (a sentence of its own needs a new string).
