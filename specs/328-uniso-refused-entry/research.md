# Research - feature 328

## R1 What the refusal does today (measured, d61d0612)

`CISO9660::AddFileDir` on a refused `AddDir` / `AddFile`: `dir->Clear(pluginData)` and
`Error(IDS_ERROR)` ("UnISO: Error"), returns FALSE; `ListDirectoryRe` sets `ret = ERR_TERMINATE` for
that directory; the parent turns it into `ERR_CONTINUE`, and from then on "descend only when
everything is OK" skips every later folder of the walk (probe: `zlast\z.txt` lost too). A refusal in
the root directory makes `ListDirectory` return FALSE - the image does not open. `dir->Clear` also
wipes a hybrid's other file systems listed before (UDF / HFS folders of `CUDFISO`).
`UnpackWholeArchive` extracts whatever `ListArchive` returned and succeeds: with "Delete archive"
the image is deleted (probe rows J-UNP-DEL, G-UNP-DEL before).

## R2 Why genisoimage images still hit it after 326

genisoimage `-R` writes `SP` in the root's `.` record and `RR` first in every record (dump of
`gdeep.iso`: `['SP','RR','PX','TF','CE']`, then `['RR','NM','PX','TF']`). 326's fit check fails and
sets `SuspVolume = FALSE`, but `SalSuspRockRidgeStart` still accepts records starting with `RR`, so
the Rock Ridge names come back and are refused.

- Decision: the fit check runs for every non-Joliet volume; when it fails the walk enters a
  decision mode instead of switching `SP` off.

## R3 Rock Ridge vs ISO 9660 names

- Decision: a file: Rock Ridge name if the listing takes it, else the ISO 9660 name, else left out.
  A folder (decision mode): Rock Ridge name if its whole subtree fits with Rock Ridge names (the
  subtree then leaves decision mode); else the Rock Ridge name when it is not longer than the ISO
  9660 name, or when counting the subtree with ISO 9660 names below lists no fewer entries under
  the Rock Ridge name than under the ISO 9660 name; else the ISO 9660 name.
- Rationale: by induction the decided listing of every folder holds at least as many entries as the
  listing with ISO 9660 names below it, so the volume holds at least as many as 326's whole-volume
  ISO 9660 listing (the listing rule is monotone in the folder part's length); shallow folders keep
  their Rock Ridge names (deep.iso of xorriso: `a\b\c` Rock Ridge, `D...\E...` ISO, `deep.txt`).
- Alternatives: whole-volume ISO 9660 names (326) - contradicts the item's *Expected*; per-entry
  fallback without counting - `deep.txt` of the xorriso tree is lost (its ISO folder names of 31
  letters under Rock Ridge parents are still 276 bytes deep); greedy "ISO 9660 for every ancestor
  of a refused entry" - loses the shallow Rock Ridge names the user sees first.

## R4 The report

- Decision: TAR's form (321 `ReportRefusedName`): `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` +
  blank line + the left-out in-image paths, one per line, at most 10, then `...`; the box is
  `SalamanderGeneral->ShowMessageBox(text, LoadStrU8(IDS_PLUGINNAME), MSGBOX_ERROR)` with a heap
  text (the plug-in's `Error()` formats into 1024 bytes - it would cut a path); shown once per
  `ListArchive`.
  No new string.
- The image records a left-out entry also when the core's `AddDir` / `AddFile` refuses after the
  rule passed (out of memory): `Error(IDS_ERROR)` as before but without `Clear`, and the listing
  is marked incomplete so a whole unpack fails.

## R5 Out of scope (Inbox)

UDF (`udf.cpp` `ScanDir`: "Error", rest of the folder lost), XDVDFS (`xdvdfs.cpp`: "Error", rest of
the folder lost), HFS+ (`hfs.cpp`: "too long path", the whole HFS listing ends), audio (`Clear`).
