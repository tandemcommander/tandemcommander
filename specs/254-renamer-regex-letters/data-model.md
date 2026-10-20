# Data model: 254

No stored data changes. The in-memory structures:

## Unit

| Field | Meaning |
|---|---|
| bytes | 1-4 bytes of the text |
| value | code point (valid UTF-8 or WTF-8 lone surrogate) or `0x110000 + byte` (a byte that starts no unit) |

Invariant: units never overlap; a boundary is any position not inside a valid multi-byte unit.

## Compiled class operand (ANYOF, variable length)

| Offset | Size | Field |
|---|---|---|
| 0 | 32 | bitmap: bits 0-127 ASCII members, bits 128-255 members among invalid single bytes |
| 32 | 1 | flags: bit 0 NEG (the bracket's `^`, applied to non-ASCII units) |
| 33 | 2 | nTests (unaligned, memcpy) |
| 35 | 2 | nRanges |
| 37 | 5 x nTests | test: 4 bytes type mask, 1 byte negated |
| ... | 8 x nRanges | range: 4 bytes low, 4 bytes high (code points) |

Membership: ASCII / invalid byte -> bitmap (already inverted for `^`); other units -> NEG xor (in a
range or a test passes).

## Look-behind operand

The unsigned short width now counts units (was bytes; identical for ASCII).
