# Data model - 397

**Hex field text** - a NUL-terminated UTF-16 string held in a buffer of `capacity` units.

| Part | Meaning |
|---|---|
| outside quotes | hex digits separated by single spaces; the rule folds double spaces, groups digits by two |
| `"…"` | quoted text, any characters, searched as their UTF-8 bytes; the rule only puts a space before an opening quote glued to the previous token and after a closing quote glued to the next |
| caret `start` / `end` | positions in UTF-16 units, moved with every insertion or removal before them |
| limit `maxLen` | the rule inserts a space only while the length is below `maxLen` (= the field's limit, 200) |

Invariants: the rule never removes a character other than a leading space or a second space
outside quotes; it never inserts between a high and a low surrogate; the result length is at most
`max(input length, maxLen)`.
