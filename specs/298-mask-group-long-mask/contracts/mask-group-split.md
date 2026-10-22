# Contract - `src/common/salmaskgroup.h` (feature 298)

Header-only, no globals. Internal to the core (not a plug-in interface); `::PrepareMask` and
`CSalamanderGeneral::PrepareMask` keep their signatures and contracts.

| Function | Contract |
|---|---|
| `const char* SalMaskGroupCutMask(const char* s, char* mask)` | Copies the mask that starts at `s` into `mask`, `;;` -> `;`; stops at the end, at a single `;`, at `|`, or at a byte a mask may not hold (`< 32`, `\ / < > : "`); NUL-terminates `mask`; returns where it stopped. `mask` holds at least `strlen(s) + 1` bytes; never writes more. |
| `char* SalMaskGroupTrimMask(char* mask)` | Cuts off trailing bytes `<= ' '` in place and returns the first byte that is not `<= ' '` (bytes compared unsigned). |
| `void SalPrepareMaskU8(char* mask, const char* src)` | The `PrepareMask` normalization: skip leading spaces, `**` -> `*`, `*?` -> `?*`, trim trailing spaces. `mask` holds at least `strlen(src) + 1` bytes; never writes more. |

Equivalence: for every input, the results equal the code of `CMaskGroup::PrepareMasks` / `PrepareMask` at
1bc8f164 run with unbounded buffers (saltests `TestMaskGroupSplit298`).
