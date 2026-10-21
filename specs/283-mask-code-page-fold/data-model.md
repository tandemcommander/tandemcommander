# Data model - 283

No stored data changes. One in-memory value changes meaning:

- **CMaskItemFlags::Optimize** of a prepared mask (`CMaskGroup::PreparedMasks` / `MasksHashArray`):
  `MASK_OPTIMIZE_EXTENSION` now only for an all-ASCII extension; an accented `*.xxx` mask gets
  `MASK_OPTIMIZE_NONE` and is matched by `AgreeMask`. Consequence: the extension table
  (`MasksHashArray`) holds ASCII masks only; `hashableMasks` counts only them.
- Masks strings (registry, histories), `MAX_GROUPMASK`, the plug-in interface: unchanged.
