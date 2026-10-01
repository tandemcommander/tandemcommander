# Contract: `src/common/salrandom.h` (086)

Header-only; include it from any core, test or plugin source. No globals, no
plugin-API dependency.

## `inline BOOL SalGenRandom(void* buf, int len)`

- Fills `len` bytes at `buf` from the operating system's cryptographic random
  generator (`BCryptGenRandom`, system-preferred RNG; `bcrypt.lib` is linked
  by the header's `#pragma comment`).
- `len == 0` → TRUE, nothing written.
- `len < 0`, or `buf == NULL` with `len > 0` → FALSE, nothing written.
- Returns FALSE if the generator fails; the buffer content is then undefined —
  the caller MUST NOT use it as random data.
- Thread-safe; no state.

## Callers (the only ones)

| Caller | On FALSE |
|---|---|
| `src/pwdmngr.cpp` `FillBufferWithRandomData` (core password manager) | `TRACE_E`, fill with the pre-085 generator |
| `src/plugins/zip/crypt.cpp` `FillBufferWithRandomData` (AES salt, ZIP 2.0 header) | `TRACE_E`, fill with the pre-086 generator |

A new consumer of random bytes for anything security-relevant calls
`SalGenRandom`; it never seeds `rand()` with time or process id.

## Tests (`saltests`, `TestRandom086`)

success for 16 B; argument rules above; two 16-byte draws differ; a 64 KiB
draw contains all 256 byte values; the buffer around the requested range is
not touched.
