# Data model - 326-uniso-rrip-without-rr

- **Directory record** (ISO 9660 9.1): length (byte 0), extent, data length, flags, file
  identifier length (byte 32), identifier (from 33), a padding byte when the identifier length is
  even, then the **System Use area** up to the record's length.
- **SUSP entry**: signature (2 bytes), length (1, includes the 4-byte header), version (1), data.
- **`SP`** (only in the root's `.` record, at byte 0 of its System Use area): length 7, version 1,
  check bytes `BE EF`, LEN_SKP.
- **`RR`** (RRIP 1.09/1.10, dropped in 1.12): flags of the RR entries present; when it is a record's
  first entry the plug-in has always read that record as Rock Ridge.
- **`NM`** (RRIP): flags (bit 0 CONTINUE), name part; **`CE`**: block, offset, length of a
  continuation area; **`ST`**: terminator.
- **Volume state in `CISO9660`** (new): `SuspVolume` (the root's `.` record carries `SP`),
  `SuspSkip` (its LEN_SKP); set in `Open`, read-only afterwards.
