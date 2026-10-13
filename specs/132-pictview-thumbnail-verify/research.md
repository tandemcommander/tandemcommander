# Research: feature 132

## R1 - Is the loss real? (the library called directly)

- **Decision**: yes, in the library; measured with `probe/exifdll_measure.py` on the EXIF.DLL of
  0.1.9 (`probe/exifdll_result_before_v019.txt`): 6 of 13 shapes of file are written with a loss
  and the call returns success.
- **Causes** (`exif/libjpeg/jpeg-data.c`): every APP1 is parsed as Exif (XMP becomes an empty
  Exif block); the loader returns at the first thing it does not understand and the writer
  writes what was collected; segment lengths are written as 16 bits without a check; "the byte
  before the last one is 0xFF" is taken as the end marker.

## R2 - Is it reachable in the program?

- **Decision**: no - in no release since feature 006. `WicSaveImage` (`wicengine.cpp`) accepts
  only the raw 32-bit export of the panel thumbnails; Update Thumbnail asks for a scaled JPEG
  picture in memory and gets `PVC_UNSUP_OUT_PARAMS`. First probe run: every row "Unable to save
  the image ... not supported by the built-in image engine", every file unchanged.
- **Consequence**: the note of 131 ("far more files reach that stage now") was wrong; the
  accented-path fix of 131 in this command had no visible effect either.
- **Alternatives considered**: (a) record "unreachable" and stop; (b) keep only the hardening;
  (c) repair the command with the hardening as its condition. Chosen (c): the command is in the
  menu, the repair is one function on top of what the engine already has, and the hardening
  cannot be shown in the program without it. The command rewrites users' files again, which it
  has not done since 006 - hence two independent safeguards and the probe mode "oldlib".

## R3 - What may differ between the original and the new file?

- **Decision**: only Exif APP1 ("Exif\0\0") and JFXX APP0 ("JFXX\0") blocks before the first
  SOS; fill bytes are not compared (the library does not write them back).
- **Rationale**: these are the two things the library changes on purpose (`exif.c`
  `EXIFReplaceThumbnail`: Exif thumbnail, or insert / replace a JFXX block). The library also
  removes an APP0 block shorter than 4 bytes ("invalid"); the rule does not allow that - such a
  file is refused (fails closed; no real file is known to have one).
- **Not compared**: the content of the Exif block (the library re-serialises the tags).

## R4 - The thumbnail picture

- **Decision**: `CWicDibSource` (no copy of the decoded frame) -> `IWICBitmapScaler` (Fant) ->
  converter to 24-bit BGR or 8-bit gray (`PVCM_GRAYS`) -> JPEG encoder, quality 0.8, into an
  `HGLOBAL` stream -> one `WriteFunc` call. Cancel through the progress callback as elsewhere.

## R5 - The question about a missing Exif block

- **Decision**: the built-in engine never sets `PVFF_EXIF`, so every file was asked "this file
  does not contain EXIF data ... create a JFXX thumbnail instead?" - also a file with Exif, whose
  Exif thumbnail the library then updates. The plug-in looks at the file's blocks itself
  (`SalJpegHasExif` on the first megabyte). Setting `PVFF_EXIF` in the engine would also switch
  on the viewer's auto-rotation and its Exif dialog - another feature, not done here.
