# Data model - feature 322

## HFS+ catalog (in memory, loaded whole)

```text
offset 0               header node: BTNodeDescriptor (14 bytes, kind = 1) + BTHeaderRec (106 bytes)
node n                 bytes [n * nodeSize, (n + 1) * nodeSize) - valid only when inside the catalog
  descriptor           fLink (BE32) | bLink | kind (S8) | height | numRecords (BE16) | reserved
  record area          [14, nodeSize - 2 * numRecords)
  record table         numRecords BE16 offsets from the node end backwards (record i at nodeSize - 2 (i + 1))
```

## Record reference (the rule's output)

| Field | Meaning |
|---|---|
| `Offset` | the record's first byte, from the catalog start |
| `Avail` | bytes from there to the end of its node's record area (>= 2) |

## Catalog record view (for the consumers)

| Field | Rule |
|---|---|
| key length `k` (BE16 at 0) | `k >= 6` and `2 + k + 2 <= Avail` (the record type follows the key) |
| parent ID (BE32 at 2) | raw |
| name length `n` (BE16 at 6, when `k >= 8`) | `8 + 2 n <= 2 + k`; else 0 |
| body | at `2 + k`, `Avail - 2 - k` bytes; a folder record needs 88, a file record 248 |

## States of the walk

`OK` (records listed) - `NOT_HEADER` (first node is not a header node: the old message) -
`DAMAGED` (any bound above broken, or a node seen twice) - `NOMEM`.
