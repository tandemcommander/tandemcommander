# Data model - 393-cpio-long-name

No new data. One existing structure is read differently:

- `SCommonHeader` (`src/plugins/tar/tar.h`): for a cpio header (`Format` = newc / crc / odc /
  binary / byte-swapped binary) the refusal of 306 / 308 / 321 now sets `Ignored` and `NameRefused`
  when `SalPaxNameUsableU8` says the name is not usable in the current pass (`Listing`).
  - Listing pass: a component over 255 UTF-16 units, a folder part over `MAX_PATH - 5` bytes, or a
    folder name over that bound inside a folder -> refused, "(206)" + path once.
  - Extraction pass: only a component over 255 UTF-16 units -> refused; asked for -> reported, the
    operation fails.
- `IsCpioGroupMember`: a refused name keeps its group (R3 of research.md); it is never written
  under its own name.
