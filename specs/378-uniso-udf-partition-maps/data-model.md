# Data model - 378-uniso-udf-partition-maps

## Logical volume descriptor (ECMA-167 3/10.6), one 2048-byte sector as held by `CUDF::Open`

| Offset | Size | Field | Use |
|---|---|---|---|
| 264 | 4 | Map Table Length (MT_L) | the table's end: 440 + MT_L (bounded by the sector) |
| 268 | 4 | Number of Partition Maps (N_PM) | the declared count |
| 440 | MT_L | Partition Maps | the maps one after another |

## Partition map

| Offset | Size | Field |
|---|---|---|
| 0 | 1 | type (1 physical, 2 virtual / sparable / metadata, others unknown) |
| 1 | 1 | length of this map in bytes (the walk's step) |

Minimum length taken: type 1 = 6, type 2 = 44 (research R2), others = 2.

## Rule

`SalIsoUdfLvdMapsFit(lvd, held, count)`: true with `count` = N_PM when every declared map lies in
[440, min(held, 440 + MT_L)) and has a length >= its minimum; false otherwise (`count` 0). No state.
