# Contract: name rules of feature 261 (`src/common/salnamerun.h`, core only)

Internal to the core (no plug-in uses `salnamerun.h`); listed so callers and tests agree.

```cpp
// nameAt(i, &name, &len): the i-th candidate (len < 0 = up to the terminator)
template <class TNameAt> int SalNamePickIndex(int count, const char* name, int nameLen, TNameAt nameAt);
//   -> index of the byte-identical candidate (the first one), else of the only candidate equal by
//      SalNameEqualOrdinalCI, else -1 (none, or two or more such candidates)

// sameKey(i, k): items i and k have the same first sort key; isTwin(i, k): byte-different and the
// same name ignoring case. Walks the neighbours of 'index' while sameKey holds.
template <class TSameKey, class TIsTwin> BOOL SalHasCaseTwinInRun(int count, int index, TSameKey sameKey, TIsTwin isTwin);

// the comparison Compare Directories uses for one pair: exact (-1/0/1 of exactCmp) when the first
// keys are equal and either name has a twin, else pairCmp
inline int SalTwinAwarePairCmp(BOOL sameKey, BOOL leftTwin, BOOL rightTwin, int exactCmp, int pairCmp);
```
