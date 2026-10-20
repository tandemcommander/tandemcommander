# Contract: the Paste copy-name rule (`src/common/salcopyname.h`)

Core-internal (no plug-in relies on it).

```text
int SalMakeCopyNameU8(const char* name, BOOL isDir, const char* hyphenCopy, int attempt,
                      char* out, int outSize)
  -> SAL_COPYNAME_OK       out = the candidate, at most 255 UTF-16 units
  -> SAL_COPYNAME_TOOLONG  more than 255 units, or does not fit outSize; out = ""
```

The candidate (Windows Explorer since Vista; a faithful port of the old fileswn6.cpp branch):

- `ext` = the last `.` and what follows, for a file only; an extension holding a space is none.
- `num` = the first `(digits)` in the name (`()` counts, as before).
- attempt 1, or no `num`: `base + hyphenCopy [+ " (attempt)" when attempt > 1] + ext`, `base` the
  name without `ext`.
- attempt >= 2 with `num`: `num` replaced by `(attempt)`; `hyphenCopy` goes before `ext` (when
  `num` is before `ext`) or after the name part before `ext` (when `num` is inside `ext`); without
  `ext` `hyphenCopy` goes at the end.

A higher attempt is never shorter than a lower one at the same place in the name, so the caller
stops at the first TOOLONG.
