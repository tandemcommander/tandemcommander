# Fix log: 177 - F6 Move onto an existing file (closed by measurement)

Backlog: NEXT-WORK item 5h (found by 175's review): `worker.cpp` `DoMoveFile` deletes an existing
target after the overwrite question and then retries the move - a move that then fails would leave
the target gone.

## Measured

Probe `probe/move_over_probe.ps1` (hidden desktop, the build at 176): `probe/result.txt`, 4 / 0.

- MV-PLAIN: F6 of `src\b.txt` onto the existing `dst\b.txt`, the overwrite question Yes: replaced.
- MV-HELD: `src\b.txt` held open by another program without `FILE_SHARE_DELETE` (it cannot be
  renamed): the **first** move already fails with 32 ("Error Moving File") - the overwrite question
  is never reached and `dst\b.txt` keeps its content. Windows reports the source's sharing before
  the target's existence.

So the loss needs a lock that appears exactly between the delete of the target and the move of
the source (another program opening the source in that moment). Not reproducible without a race;
no code change (as 162). The branch stays recorded in the item's text.
