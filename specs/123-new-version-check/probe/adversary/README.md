# Adversarial test of `src/common/salupdcheck.h` (feature 123)

An independent attempt to break the pure part of the new-version check: the
strict JSON reader, the release-record rules, the constructed addresses, the
time and version parsers, the throttle rule and the Debug-only loopback-URL
parser. Written by a tester who did not write the header or its saltests.
Nothing under `src/` is modified; everything lives here.

Results of the run of 2026-10-06: **`RESULTS.md`**.

## Files

| File | What it is |
|---|---|
| `adv_harness.cpp` | console harness including the header as it is (no STL, so `/RTCc` builds) |
| `build.cmd` | builds five variants into `bin\` |
| `adv.py` | generators, the Python oracle, the comparison (`--seed`, `--count`, `--only`, `--exh`) |
| `mutants.py`, `build_mutant.cmd` | mutation test of this suite: 49 deliberately broken copies of the header that the suite must notice |
| `findings.py` | writes the reproducing inputs of the findings to `findings\` and prints both verdicts |
| `findings\*.json` | the reproducing inputs (exact bytes) |
| `RESULTS.md` | counts per generator and verdicts |
| `logs\` | the raw output of the runs behind `RESULTS.md` |

`bin\`, `obj\`, `out\` are build and run products (ignored by git).

## Build

```bat
build.cmd
```

Needs VS 2022 (`vcvars64.bat` at the Community path) and Python 3 on PATH.

| Variant | Flags | Why |
|---|---|---|
| `adv_rtc_J.exe` | `/Od /RTC1 /RTCc /J /MTd` | the product's Debug flags: stack and uninitialised-variable checks, "cast to smaller type loses data", `char` unsigned |
| `adv_rtc_noJ.exe` | the same without `/J` | `char` signed (stand-alone probes, other compilers) |
| `adv_o2_J.exe` | `/O2 /J /MT` | optimised code; timing |
| `adv_asan_J.exe` | `/fsanitize=address /Od /J` | AddressSanitizer |
| `adv_asan_noJ.exe` | the same without `/J` | AddressSanitizer, `char` signed |

All five compile with `/W4` without a warning.

## Run

```bat
bin\adv_rtc_J.exe unit            :: direct tests (C5, buffers)            - every variant
bin\adv_o2_J.exe perf             :: worst-case time and stack (C1)
bin\adv_o2_J.exe locales          :: SalUpdStripWeekday on every installed locale
python adv.py --seed 1 --count 40000 --exe bin\adv_o2_J.exe --exe bin\adv_rtc_J.exe
python adv.py --exh --exe bin\adv_o2_J.exe --exe bin\adv_asan_J.exe
python mutants.py                 :: is the suite able to see defects at all?
python findings.py                :: the findings, reproduced
```

A run prints one line per generator and executable (`N cases, M disagreements`)
and ends with `TOTAL disagreements`. Every generator is seeded with
`"<seed>/<generator name>"`, so `--seed S --count C --only <name>` reproduces a
case exactly; disagreeing inputs are saved under `out\mismatch\`.

## How an input is run (memory safety, C1/C6)

`batch` mode runs every input twice:

1. placed so that its **last byte is followed by a `PAGE_NOACCESS` page** - an
   over-read of one byte faults in every build, sanitizer or not;
2. from an **exact-size `malloc` block** - the AddressSanitizer builds see
   over- and under-reads through the red zones.

Output buffers (`ReadString`, the address builders, the loopback path) are
exact-size tails in front of a no-access page as well. The two runs must give
the same result (`INV_NONDETERMINISTIC` otherwise). On every accepted record
the harness itself checks the invariants of C3: both addresses are rebuilt,
must begin with `https://github.com/tandemcommander/tandemcommander/releases/`
and hold only `[a-z0-9:/.-]`; `PublishedText` is 20 bytes and parses back to
`PublishedUtc`; on a refusal the release structure is all zero and the error
code is set.

## The oracle (C2, C3, C4)

`adv.py` decides what a text "really" says with **Python's `json` module**
(`object_pairs_hook` keeps duplicates and order, `parse_constant` refuses
`NaN`/`Infinity`), then applies the rules of `contracts/update-source.md`
written again from the contract, not from the header: top-level object, the six
read members exactly once, `draft`/`prerelease` the literal `false`, the tag
pattern, a real UTC time from 1601, `html_url` and one asset
(`name`/`state`/`browser_download_url` each once) equal to the addresses built
in Python from the tag's numbers. Nesting over 32 and size over 256 KB are
refusals, as the contract says.

Compared per case: the grammar verdict of the bare reader (`SkipValue(1)` +
`AtEnd`), accept/refuse of `SalUpdParseLatestRelease`, the error class, the
version and the FILETIME.

The text is read as **Latin-1** for this verdict (JSON's structure is ASCII, so
this is the byte-exact reading), and strict UTF-8 validity is tracked
separately - the header does not validate UTF-8 (finding F1), and with a
strict-UTF-8 oracle that one known difference would bury everything else.

Labels: `SECURITY_ACCEPTED_BUT_ORACLE_REJECTS`, `SECURITY_WRONG_VALUES`,
`AVAILABILITY_REJECTED..._BUT_ORACLE_ACCEPTS`, `GRAMMAR_ACCEPTS_INVALID`,
`GRAMMAR_REJECTS_VALID`, `ERRCLASS` (same verdict, another reason).

## Generators

| Name | What it makes |
|---|---|
| `hand` | 148 hand-written attack records, each with my own expected verdict (checked against the oracle too) |
| `struct` | records built from pools of good and near-miss values (tags, times, 45 address tricks: scheme, host case, userinfo, trailing dot, homoglyph, percent-encoding, NUL, lone surrogate ...), with 14 structural attacks (missing / duplicated / nested / retyped read members, split assets, second `assets`, depth 29-33, pads to 511/512/513 bytes and to 256 KB), serialised with random escapes (`\uXXXX`, `\/`, surrogate pairs, upper/lower hex) and white space |
| `struct_mut` | the same followed by 1-3 byte-level mutations |
| `mini_mut` | a 390-byte valid record with 1-2 byte-level mutations (every byte matters) |
| `real_mut` | the real answer for 0.1.8 with 1-3 byte-level mutations |
| `real_reser` | the real answer re-serialised in another spelling, with a member duplicated / removed / retyped at a random nesting level |
| `utf8` | records with an invalid UTF-8 sequence inserted somewhere |
| `grammar` | random JSON values of any type (valid and slightly invalid), chains at depth 30-34 |
| `string` | string literals from 55 fragments (escapes, surrogate combinations, NUL, invalid escapes) read into buffers of size 0, 1, exact, one short, 40, 512 - result bytes compared |
| `version`, `time`, `loopback` | `SalUpdParseVersion` (both forms, explicit length and zero-terminated, embedded NULs), `SalUpdParseUtcTime`, `SalUpdParseLoopbackUrl` against regular-expression references |
| `exh_mini` (`--exh`) | **every** byte value at every position of the 390-byte record, every deletion of 1 and 2 bytes, every truncation, 52 tokens inserted at every position |
| `exh_short` (`--exh`) | **every** text of 1-5 symbols over 16 JSON symbols (1,118,480 texts) |
| `exh_dup` (`--exh`) | every read member duplicated at every position (same / other value), removed; a second `assets` at every pair of positions |

Byte-level mutation = flip, bit flip, delete, insert or overwrite with one of
52 tokens (`{ } [ ] " : , \ \u \ud83d \u0000 true NaN "tag_name" ...`,
BOM, NUL), duplicate / delete / move a chunk, truncate, swap.

## `unit` mode (C5)

- the address and version printers with **every buffer size from 0 to need+3**
  for 1,331 versions incl. `UINT_MAX` parts (no write past the size given, empty
  string on failure), NULL and negative sizes;
- 300,000 random version pairs: order against a reference, print → parse round
  trip, explicit lengths one short / one long;
- `SalUpdStatusWantsBody` for every status 0..69,999 and odd 32-bit values, with
  and without a result pointer;
- `SalUpdAutoCheckDue` over 14 x 14 boundary times (0, 1 h ± 1, 24 h ± 1,
  2^63, 2^64-1 ...) x 8 flag combinations against the sentence in data-model.md;
- `SalUpdStartupNoticeWanted`, `SalUpdKnownState` for every result and relation;
- `ReadString` with every buffer size around the need for texts ending in a
  1-, 2-, 3- and 4-byte character; the 511/512-byte limit;
- `SalUpdParseLoopbackUrl`: NULL arguments, sizes 0/1/2/exact, every prefix of
  a good URL in front of a no-access page;
- `SalUpdParseUtcTime`: **every day from 1601-01-01 to 9999-12-31** plus day
  numbers 0 and 32 of every month, against `FileTimeToSystemTime` counting
  forward (3,067,671 accepted days);
- `SalUpdStripWeekday`: 17 fixed pictures and 400,000 random ones with
  properties (never longer, no `ddd` left outside quotes, quoted text and all
  other characters kept in order), each in front of a no-access page.

## `perf` mode (C1)

21 inputs of 256 KB chosen to be the worst for each loop (`[`, `{"a":`, lone
surrogates, the re-read path after a high surrogate, white space, one huge
number, 131 K array elements, 43 K members, 20 K duplicate members, 20 K
assets, values nested to the limit ...). Each runs on a fresh thread; the time
is the best of five runs, the stack is the committed part of that thread's
stack afterwards (4 KB granularity, thread start included).

## `mutants.py` - does "no finding" mean anything?

49 copies of the header, each with one planted defect of a kind the suite
claims to look for (limit off by one, buffer off by one, prefix instead of
exact comparison, duplicate allowed, trailing bytes allowed, leap-year rule,
over-read in `\u`, ...). The suite must fail on each. See `RESULTS.md` for the
kill list; a survivor is a hole in the suite and is listed there as such.
