# Data model - 276

No stored data changes. The one rule:

- **Information line buffer length** (`src/common/salinfolinebuf.h`)
  - `SAL_INFOLINE_FIRST_LEN` = 1000 - the first attempt (the panel's stack buffer, the plug-in
    contract's size).
  - `SAL_INFOLINE_MAX_LEN` = 65535 - the bound (hot-text positions and lengths are WORDs).
  - `SalInfoLineNextLen(len)` - the next length to try after `len` failed: doubled, capped at the
    bound; 0 when `len` already is the bound (no further attempt). A length below the first one
    gives the first one.
  - Invariants: strictly increasing until 0; reaches the bound in at most 7 steps from 1000; never
    above the bound.
