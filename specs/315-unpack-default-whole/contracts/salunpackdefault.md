# Contract - `src/common/salunpackdefault.h` (feature 315)

Internal to the core (not a plug-in interface). Header-only, no globals; `saltests` checks it.

```cpp
// 'text' whole into 'buf' (TRUE), or 'buf' empty (FALSE) when it does not fit 'size' bytes with its
// terminator or an argument is NULL / 'size' <= 0
BOOL SalUnpackDefaultCopy(const char* text, char* buf, int size);

// 'buf' + '\' + the first 'nameLen' bytes of 'name' (no '\' when 'buf' is empty or ends with one)
// whole (TRUE); when the result does not fit 'size' bytes (FALSE), 'buf' holds the name alone (a
// subfolder next to the archive, what an empty entry gets), or is empty when even the name does not
// fit - never the path without its subfolder; 'nameLen' <= 0
// (nothing to append): 'buf' unchanged, TRUE; NULL arguments / 'size' <= 0: FALSE, 'buf' unchanged
BOOL SalUnpackDefaultAddSubdir(char* buf, int size, const char* name, int nameLen);
```

```cpp
// an empty target after OK ("next to the archive"): 'panelPath' whole into 'buf' (TRUE); FALSE (refuse,
// 'buf' empty) when it does not fit 'size' bytes, or when 'subdirNameLen' > 0 (the subfolder the
// setting asks for) does not fit even alone
BOOL SalUnpackEmptyTarget(const char* panelPath, int subdirNameLen, char* buf, int size);
```

Guarantees: never writes more than `size` bytes; never leaves a prefix of the input in `buf`.
