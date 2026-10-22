# Data model - 298-mask-group-long-mask

No stored data changes.

- **Mask group text**: bytes (UTF-8), `;` separates masks, `;;` is a literal `;`, one `|` starts the exclude
  part; up to `MAX_GROUPMASK - 1` (1000) bytes when stored in `CMaskGroup`, any length when passed to
  `PrepareMasks(errorPos, masksString)`.
- **Work block** (per `PrepareMasks` call): two buffers of `strlen(text) + 1` bytes - the cut mask and the
  normalized mask; freed on every return.
- **Prepared mask** (unchanged): `CMaskItemFlags` byte + the normalized mask, heap, owned by the group.
