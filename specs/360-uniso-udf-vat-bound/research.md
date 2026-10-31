# Research - 360-uniso-udf-vat-bound

## R1 - The sites at HEAD (ddf0465a)

- `CUDF::ReadVAT` (`src/plugins/uniso/udf.cpp`): `DWORD length = (int)fe.InformationLength` - a 64-bit length
  cut (the Debug build's run-time check "a cast to a smaller data type has caused a loss of data" fires for
  IL + 2^32); `offset = 176 + fe.L_EA (+40 for an extended entry)`, `end = offset + fe.L_AD` in 32 bits.
- `CUDF::ReadAllocDesc`: type 3 (embedded) `memcpy(vat + *o, data, fe->L_AD)`; types 0 - 2 decode an 8 / 16 /
  20-byte descriptor and `Image->ReadBlock(..., ad.Length, vat + *o)` - `ad.Length` up to 2^30 - 1; types 4 - 7
  fall out of the switch with `ad` uninitialised (Run-Time Check Failure #3) and return 0 - the walk never
  advances while the reads keep writing at `vat + *o`.
- Caller chain: Enter / Alt+F9 on an image → `CISOImage::Open*` → `CUDF::Open` → `ReadSupportingTables` (case
  `mapVirtual`) → `CheckForVAT(sector, ...)` for each file entry in the search window → `ReadVAT`. The sector is
  the 2048-byte stack buffer of `ReadSupportingTables`.
- Consumers of `ReadVAT`'s result: `CheckForVAT` only (both the 2.00 and the 1.50 branch); `ReadAllocDesc` has
  one caller (`ReadVAT`).

## R2 - Where the refusal goes

- Decision: every new refusal returns `ERR_CONTINUE` from `ReadVAT` (the table freed) - `CheckForVAT` passes it
  on, the search tries the next sector, and without another VAT feature 358's `VatMissing` + "Missing virtual
  allocation table." ends it.
- Rationale: the item's *Expected* ("is not taken as a VAT ... feature 358's path"); no new message (no `.slt`
  refresh).
- Alternatives: `ERR_TERMINATE` with a new box - rejected (a new string, and a damaged entry is not a reason to
  stop looking at the next sector).

## R3 - Descriptors that cover less than the information length

- Decision: accepted as before (the copy is bounded, the tail of the buffer stays as allocated).
- Rationale: the item names only descriptors that exceed the length; refusing a shorter cover would change a
  case nobody measured (stop-rules §1 step 4). Review 2 of feature 358 noted the uncovered tail (heap content →
  a garbage sector number → a failed read, no read outside the buffer): recorded as an Inbox item.

## R4 - Order of the checks

- The existing strategy switch stays first (its box "unknown allocation strategy" and `ERR_TERMINATE` are
  unchanged); then the length, the area and the descriptor type are decided before the buffer is allocated
  (nothing to free); the per-descriptor checks run inside the walk (the table freed on refusal, as the read
  failure already did).

## R5 - The extended-attribute length that wraps

- `L_EA` = 0xFFFFFF00 made `176 + 40 + L_EA` wrap to 24 (32-bit); measured at HEAD as no visible failure (358's
  header rule refused the resulting table) but the reader parsed the descriptor tag as table data. The 64-bit
  area rule refuses it (`first` = 216 + L_EA > 2048).
