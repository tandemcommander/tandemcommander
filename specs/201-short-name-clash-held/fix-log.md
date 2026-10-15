# Fix log: 201 - Rename and Move never offer the file of a short-name clash for overwriting

Found by the review of 199 (the Renamer had the same fallback): the core's Quick Rename and the
worker's move to another entry's short (8.3) name move that entry aside for the rename - and when
that fails, go on to the overwrite question for it.

## Measured (before)

Probe `probe/short_clash_probe.ps1` (158's driver; short names are made on C:), the build at 200,
run with `-Expect103` so that the boxes count (`probe/result_before.txt`, 4 / 2):
- qr-free (the control): `x.txt` -> `LONGFI~1.TXT` renamed, `longfilename.txt` kept, no box;
- **qr-held** (`longfilename.txt` held open, share read+write, no delete): **"Confirm File
  Overwrite"** for the other file under its short name; Yes failed only because the file was held
  ("(5) Access is denied") - with the file free a moment later it would have been replaced;
- **f6-held** (the same through F6, the worker): the same question, then "Error Overwriting File
  (32)" with Retry - after the other program lets go, Retry deletes `longfilename.txt`.

## Work

`src/fileswn5.cpp` (Quick Rename), `src/worker.cpp` (the move): `shortNameClash` - the new name
matched another entry's DOS name only; the overwrite branch never runs for it, and `err` keeps the
reason the move aside (or the move) failed, which the ordinary error box shows.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 6 / 0: qr-held - "Error Renaming File (32)", no question; f6-held -
"Error Moving File (32)", no question; both files unchanged; the control as before. Regressions:
158's probe 10 / 0, 103's 46 / 0.

## Review
Refute-first review: sound - every route to replacing or deleting the other entry is closed when
`shortNameClash` is set (Quick Rename's only replace and the worker's delete-and-retry loop sit in
the guarded branch; `NORMAL_ERROR` only shows the box); Retry and the automatic retry of error 32
run the whole sequence again, the move aside succeeding once the other program lets go; the
worker's flag cannot be read uninitialized (the `goto` that jumps past its declaration lands where
it is not read); the reasons shown are the move aside's or the move's own; a restore failing after
a successful move (tunnelling) used to reach the overwrite question too - closed as well;
directories and 158 / 198 unaffected. Recorded in NEXT-WORK (older): the other entry can be left
under `salNNN` with only a trace when both restores fail (Quick Rename and the worker - 198 reports
its own temporary name, this step does not); **the create paths likely have the same defect** -
`SalCreateFileEx` (the F5 copy of a file named `LONGFI~1.TXT` into a folder where
`longfilename.txt` is held), `SafeCreateFile` (plug-ins unpacking such a member),
`SalCreateDirectoryEx` - when their move aside fails they go on to "it exists" and the overwrite
question; measure first. NIT recorded: Quick Rename's box does not name the held file.
