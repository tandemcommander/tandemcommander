# Data model - 358-uniso-udf-vat-missing

## CUDF::CPartitionMapping (existing, `src/plugins/uniso/udf.h`)

| Field | Meaning | Rule (this feature) |
|---|---|---|
| `Translation` | the VAT entries (virtual block -> physical sector), inside `VAT` | NULL until a VAT is found; never read when NULL |
| `Entries` | number of entries | 0 at construction; `<=` the table's bytes / 4; index valid only when `< Entries` |
| `Length` | bytes of the table | 0 at construction |
| `VAT` | the table buffer (owned, `delete[]` in the destructor) | unchanged |

## States of a virtual partition at open

- VAT found -> the volume opens, translation by `SalIsoUdfVatTranslates`.
- VAT not found / search terminated / VAT sector unreadable -> the volume does not open (`CUDF::Open` FALSE).

## Pure rules (`src/common/salisoudfvat.h`)

- `bool SalIsoUdfVatTranslates(unsigned long long lbNum, unsigned long long entries, bool hasTable)`
- `bool SalIsoUdfVat200Entries(unsigned long long infoLen, unsigned long long headerLen, unsigned long long tableLen, unsigned long long& entries)`
