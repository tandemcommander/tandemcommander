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

// pairs one run pair (one first sort key on both sides): byte-identical names first, then a name
// without a twin with the other side's name without a twin that is the same ignoring case
template <class TExact, class TSameName, class TLeftTwin, class TRightTwin>
int SalTwinRunPairs(int nL, int nR, TExact exact, TSameName sameName, TLeftTwin leftTwin, TRightTwin rightTwin,
                    int* leftPartner, int* rightPartner);
// the walk order of a run pair: pairs first (partners at equal positions), then each side's rest
inline void SalTwinRunOrder(int nL, const int* leftPartner, int nR, const int* rightPartner, int* orderL, int* orderR);
// the merge comparison of positions within a run pair walked in that order: 0 = a pair
inline int SalTwinRunSlotCmp(int il, int ir, int pairs);
```

Review of 261 (S1): the first version switched pair by pair between the exact and the
case-insensitive order (`SalTwinAwarePairCmp`, removed); the locale first key ignores a soft
hyphen and folds NFC / NFD, so the two orders disagree inside one run and the merge stepped past a
partner. Pairing a run as a set is order-independent.
