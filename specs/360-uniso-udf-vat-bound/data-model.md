# Data model - 360-uniso-udf-vat-bound

No stored data. The values the rules decide on:

| Value | Source | Rule |
|---|---|---|
| information length (64-bit) | file entry offset 56 | `SalIsoUdfVatTableLength`: <= 2^32 - 1, else not a VAT |
| L_EA, L_AD (32-bit) | offsets 168 / 172 (plain), 208 / 212 (extended) | `SalIsoUdfVatDescArea`: 176 (+40) + L_EA + L_AD <= 2048, in 64 bits |
| descriptor type | ICB tag flags & 7 | `SalIsoUdfVatDescSize`: 0 → 8, 1 → 16, 2 → 20, 3 → 0 (embedded, the whole area), 4 - 7 → -1 (not a VAT) |
| descriptor position | the walk | `SalIsoUdfVatDescFits`: pos + size <= area end |
| bytes written, extent length | the walk, the descriptor (or L_AD) | `SalIsoUdfVatCopyFits`: written + length <= table length |

State: a VAT candidate is either *taken* (the walk wrote only inside the table) or *not a VAT* (`ERR_CONTINUE`,
table freed); a read failure keeps its existing `ERR_CONTINUE`.
