# Data model - 369-nrg-sinf-chunk-size

## NRG chunk (from the image)

| Field | Bytes | Meaning |
|---|---|---|
| ID | 4 | `CUEX`, `DAOX`, `SINF`, `ETNF`, `ETN2`, `CDTX`, `END!`, ... |
| Size | 4, big-endian | bytes of the body that follows |
| body | Size | the chunk's data |

The next chunk starts at `body start + Size` - after every chunk, known or not (FR-003).

## SINF body

| Field | Bytes | Meaning |
|---|---|---|
| count | 4, big-endian | tracks in this session |

Usable only when `Size == 4` and the body lies within the image (`SalNrgSinfUsable`) and it is read
whole; otherwise: no session count, `ListingLeftOut` incomplete (FR-001, FR-002).
