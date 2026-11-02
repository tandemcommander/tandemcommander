# Research - feature 394

## R1 Where the member is lost

- Decision: `ReadArchiveHeader` returns early for an empty normalized name with `Ignored = TRUE`,
  `LinkType = 0`, before the name split, the time conversion and the attributes;
  `IsCpioGroupMember` requires `!Ignored || NameRefused`. Measured at 32c55a19 with the probe
  (9 FAIL rows: `a.txt` empty, archive deleted).
- Rationale: matches the item's *Evidence*; the same mechanism feature 393 fixed for refused names.

## R2 Keep in the group (vs report and fail)

- Decision: keep the member in its group as not asked (the item's first choice; feature 393's way).
- Rationale: `SalCpioLinkDecide` already writes a not-asked carrier's data under the first waiting
  name (WRITE_FOR_WAITING) and reports the data-first layout; nothing new is needed there.
- Alternatives: set `NameRefused` - rejected: an extraction asked for a refused name reports
  "(206)" and fails; GNU cpio's folder `.` could then match a whole-unpack mask and fail every
  `find . | cpio -o` archive.

## R3 Time and attributes of the written file

- Decision: convert them in the empty-name branch (cpio only), as the normal path does.
- Rationale: WRITE_FOR_WAITING writes with the carrier's `FileInfo.LastWrite` / `Attr`; without the
  conversion the file would get the raw (unconverted) values.

## R4 crc checksum of data written from an Ignored carrier

- Decision: verify when the data is written (`!simulate`), not only when not `Ignored`.
- Rationale: the only callers that write from an `Ignored` header are the group paths (enumerated:
  `DoUnpackArchive` and `UnpackOneFilePass` pass `simulate = Ignored || !found`); feature 393's
  refused carrier had the same gap. Refuses corrupt data instead of writing it with success.

## R5 Pure rule

- Decision: `SalCpioKeepsGroupMember` in `salcpiolink.h` with saltests checks (stop-rules §2.5),
  plus checks that `.`, `./`, `/`, `..` and `` normalize to nothing (the trigger).
