# Data model (261)

No stored data. Terms:

- **Case twins**: two names of one listing, byte-different, equal by `SalNameEqualOrdinalCI`.
- **Run of a first key**: the neighbouring items of a list sorted by `CmpNameExt` that are equal by
  its first key `RegSetStrICmpEx` (case-insensitive, locale / numeric aware). Twins are in one run.
- **Pick of a lookup**: index of the byte-identical item, else of the only ordinal-CI-equal item,
  else -1.
