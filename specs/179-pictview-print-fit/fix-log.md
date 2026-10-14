# Fix log: 179 - PictView print: Fit never mirrors by a stored negative size; no wrap

Backlog: NEXT-WORK item 6a (found by 152's review).

## Read (printing is not driven on the hidden desktop)

`render1.cpp` CMD_PRINT mirrored the picture by the stored printed width / height's sign
(`Params.Width < 0`, a negative size typed with Fit off) also with *Scale to fit* on - reachable in
one dialog session: a negative width typed, then Fit ticked (the Fit handler keeps `Params.Width`).
The dialog and the preview (`print.cpp CreatePreview`, 152: Fit passes a positive size) showed the
picture upright. And `prevWidth * pvii.Width / selWidth` was an unsigned 32-bit product that wrapped
at a large scale of a big image (a selection printed at 600 dpi, ~2000 %, 50,000 px).

## Work

`src/plugins/pictview/render1.cpp`: `negW` / `negH` = a negative stored size only when Fit is off,
used for the selection's offset and the stretch's sign (the preview's rule); the full-image size by
`MulDiv` (a 64-bit intermediate, as the preview; a degenerate selection no longer divides by zero).

Build: BUILD SUCCEEDED. 152's preview probe as a regression: 21 / 0 (`regress_152.txt`).

## Review

Independent refute-first review: sound - the preview's Fit branch is unsigned, the offsets agree in
every Fit / aspect / negative / mirror / selection combination, no other print use of the sign in
Fit mode; MulDiv rounds where the old code truncated (at most 1 printer pixel, as the preview).
Recorded: a result above INT_MAX makes MulDiv return -1 (print and preview alike - a tiny selection
of a huge image at a huge scale); `abs((int)(Width * scaleX))` of an absurd typed size.

Owed to a person (with 152's step): print once with Fit on after a negative width was typed - the
paper upright like the preview; with and without a selection and a mirror.
