# Fix log: 200 - PictView's Rename in a case-sensitive folder

Found by the review of 198: PictView's rename of the shown image (`render1.cpp`
`RenameFileInternal`) gates its overwrite with the code-page `StrICmp` and has no proof by the
temporary name for two spellings of one name - the shape the Renamer had before 196.

## Measured (before)

Probe `probe/pv_cs_probe.ps1` (the driver of 111's `shown_probe.ps1`: the image shown, zoomed,
CMD_IMG_RENAME; the folder made case-sensitive while empty), the build at 199
(`probe/result_before.txt`, 4 / 1):
- pv-cs-other (`a.png` shown, another `A.png`): **"Error Renaming File: (183) Cannot create a file
  when that file already exists."** - no overwrite question;
- pv-cs-new (the control: no `A.png`): renamed, the viewer follows.

## Work

`src/plugins/pictview/render1.cpp`: for two spellings of one name (`SalNameOrderEqualCI`, the 092
rule, instead of the code-page `StrICmp`) the rename goes through the temporary name; only its
result (the target outlived the file's name) proves another file (`provenOther`); the overwrite
question for such a pair needs that proof. As the Renamer (196) and the core (158 / 198).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 5 / 0: pv-cs-other - "Confirm File Overwrite", Yes: `A.png` holds the
shown image, `a.png` gone, the viewer shows `A.png` (held again, zoom kept, the image pixel-exact);
the control as before. Regression: 111's rename rows (ascii, Cyrillic, locked source, locked
target, read-only target) 11 / 0 (`probe/regress_111_rename.txt`).

## Review
Refute-first review: sound - the only destructive call (the replacing rename after Yes) is reached
for two spellings of one name only after `svtTargetIsOther`; every other result keeps the target;
a same-file case change on a folder answering "exists" ends `svtDone` now (before, a non-ASCII pair
the code-page `StrICmp` called different could be "replaced" by itself); links still refused first;
the viewer releases and retakes its handle around the rename. Taken: NIT 2 - a second change
notification after the temporary-name route (a panel without its own watcher kept `salNNN`).
Recorded: NIT 1 - two hard links of one file in a case-sensitive folder now get the overwrite
question (Yes removes one link, the data stays) - the loosening 198 accepted. Recorded in
NEXT-WORK (SHOULD-FIX, older): PictView has the 8.3 short-name trap 199 fixed in the Renamer -
renaming the shown `x.png` to `LONGFI~1.PNG` asks to overwrite and Yes replaces
`longfilename.png`. Final: the probe 5 / 0, 111's rename rows 11 / 0.
