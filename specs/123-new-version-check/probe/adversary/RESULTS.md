# Results - adversarial test of `salupdcheck.h`, 2026-10-06

Header under test: `src/common/salupdcheck.h` as in the working tree of branch
`123-new-version-check` (1,234 lines). MSVC 19.40 (VS 2022 17.10 toolset
14.40.33807), x64, Windows 11 26300, Python 3.14.6. How to repeat: `README.md`.
Raw logs: `logs\`.

## Verdict per claim

| Claim | Verdict | Evidence |
|---|---|---|
| C1 no crash, no over-read, bounded time and stack | **held** | 3.77 M inputs in front of a no-access page and from exact-size heap blocks, 1.55 M of them under AddressSanitizer; worst 256 KB input 1.05 ms (`/O2`) / 4.5 ms (Debug flags); committed stack <= 8 KB |
| C2 TRUE only for a record meeting every rule | **held** | 0 of 3.77 M verdicts differ from the oracle, incl. 336,000 accepted records with the right version and time, and the exhaustive single-edit sweep of a valid record |
| C3 only constructed addresses, version = tag | **held**, one remark (F2) | invariant checked on every accepted record; all 1,331 boundary versions; F2: a tag with leading zeros is accepted with canonical addresses |
| C4 rejects whatever a strict parser rejects | **refuted in one respect (F1)**: text that is not valid UTF-8 is accepted. Nothing else: 0 grammar differences in 1.12 M exhaustive short texts and 320,000 random values | F1; other direction: F3 |
| C5 small functions behave as documented | **held**, NITs N1-N4 | 10.1 M unit checks per build, 480,000 differential cases |
| C6 no undefined behaviour under `/RTC1 /RTCc`, `/J` and not, ASan | **held** | all five builds: 0 run-time check reports, 0 sanitizer reports, identical verdicts |

No security defect was found. Findings: one deviation from the "strict"
claim without a way to exploit it (F1), one accepted spelling the contract's
wording suggests is refused (F2), one availability remark (F3), one cosmetic
defect in a real Windows locale (F4), four NITs.

## Findings

Reproduce F1-F3 with `python findings.py` (inputs in `findings\`).

### F1 - text that is not valid UTF-8 is accepted (C4) - no impact found

`CSalUpdJsonReader::ReadString` copies every byte >= 0x80 as it is (lines
519-522, 602-606: "UTF-8 passes through unchanged") and never checks that the
bytes form UTF-8. RFC 8259 section 8.1 requires UTF-8; a strict parser refuses.

| Input (`findings\`) | Header | Strict parser |
|---|---|---|
| `F1a` valid record + `,"body":"\xFF"` | accepted as 0.1.9 | refused |
| `F1b` valid record + `,"x\xC0\xAF":1` (overlong `/` in a name) | accepted | refused |
| `F1c` valid record + `,"body":"\xED\xA0\x80"` (encoded surrogate) | accepted | refused |
| `F1d` valid record + `,"body":"\xE2\x82"` (sequence cut by the closing quote) | accepted | refused |

In the campaign: 11,563 records with an invalid sequence accepted (generator
`utf8`), 41,984 of the 49,920 single-byte edits of the compact record that
produced invalid UTF-8 pass the bare grammar.

Why I could not turn it into anything: every name and value the program
compares is pure ASCII and is compared byte for byte, so a non-ASCII byte in a
read member can only make it differ; nothing from the answer is shown; no
second parser reads the same bytes. It is a refutation of the sentence "a small
strict JSON reader", not of the security rules. Fix if wanted: validate
sequences in `ReadString` (reject C0, C1, F5-FF, bad continuation, overlong
E0/F0 forms, ED A0-BF, F4 90+), or say in the header and the contract that the
encoding is not checked and why that is safe.

### F2 - a tag with leading zeros is accepted when the addresses are canonical (C2/C3 wording)

`findings\F2-leading-zeros-in-tag.json`: `"tag_name":"v00.01.009"` with
`html_url` `.../tag/v0.1.9` and the asset of 0.1.9 -> **accepted as 0.1.9**.
`SalUpdParseVersion` (lines 103-116) takes leading zeros, and the comparison at
1163 is against the re-printed numbers, not against the tag text.

Not exploitable (the version reported equals the tag's numbers, the addresses
are the constructed ones, and GitHub cannot produce such a record: the release
page of tag `v00.01.009` is `.../tag/v00.01.009`). But the contract's remark
"so `v0.01.9` cannot match its own addresses" and the saltests comment "leading
zeros ... can never match the addresses" read as if such a tag were always
refused. Either refuse it (after parsing a tag, re-print and compare with the
text - 3 lines) or pin the behaviour with a test.

### F3 - an asset whose `name` / `state` / `browser_download_url` occurs twice never matches (C4, other direction)

`findings\F3-asset-name-twice-same-value.json`: valid JSON, the installer asset
has `"name"` twice with the same correct value -> refused (`supeNoInstaller`,
line 939). The header documents it ("each member present exactly once"); the
contract (`update-source.md`, "Duplicate members") speaks of the top level
only. Deliberate strictness, GitHub never emits it - listed because the task
asks for every rejection of valid JSON beyond size, depth and top-level
duplicates. This is the only one found.

### F4 - `SalUpdStripWeekday` leaves a quoted separator hanging (cosmetic, real locale)

`adv_harness locales` over all 928 locales of this Windows: one bad result.
**se-FI** (Northern Sami, Finland): long-date picture
`dddd', 'MMMM d'. b. 'yyyy` -> `', 'MMMM d'. b. 'yyyy` -> the notification
would show **", golggotmánu 14. b. 2026"**. The separator after the weekday is
quoted literal text there, and lines 319-326 remove unquoted separators only.
Every other locale gives a clean date without the weekday.

### NITs

- **N1** `ReadString(out, 0, &bad)` on the empty string `""` reports
  `bad == FALSE` although not even the terminator fits (line 628 is never
  reached for an empty text). No caller passes a buffer of size 0.
- **N2** After a **failed** `ReadString` the caller's buffer holds the bytes
  stored so far **without a terminating zero** (`"abc` -> `abc` + old bytes;
  returns at 515, 520, 558, 594 skip lines 636-642). All callers in the header
  return at once and never look; the comment at 498-501 does not say it.
- **N3** `SalUpdParseLoopbackUrl` accepts leading zeros in the port
  (`http://127.0.0.1:00080/x` -> 80; up to 5 digits). Debug-only seam, harmless.
- **N4** Comment at line 843: `supeMissingField` "is missing or has the wrong
  type" - a wrong type is reported as `supeBadTag` / `supeBadTime` /
  `supeForeignNotes` / `supeDraft` / `supePrerelease` / `supeNoInstaller`
  (confirmed by the error-class comparison, 0 differences against that model).

## Counts

`cases / disagreements` per build. Random generators: seeds 1-6, 8-10
(`--count 40000`, seeds 2 and 8 `--count 20000` on all five builds). The
generator `real_reser` exists from seed 3, the non-JSON white space and
hex-boundary cases from seed 8 (added after the mutation run showed them
missing).

| generator | cases | oracle accepts | o2_J | rtc_J | rtc_noJ | asan_J | asan_noJ |
|---|---|---|---|---|---|---|---|
| hand | 148 (100 before seed 8; run with every seed) | 23 of 148 | 1,044 / 0 | 1,044 / 0 | 248 / 0 | 248 / 0 | 248 / 0 |
| struct | 320,000 | 144,276 | 320,000 / 0 | 320,000 / 0 | 40,000 / 0 | 40,000 / 0 | 40,000 / 0 |
| struct_mut | 320,000 | 27,872 | 320,000 / 0 | 320,000 / 0 | 40,000 / 0 | 40,000 / 0 | 40,000 / 0 |
| mini_mut | 480,000 | 3,562 | 480,000 / 0 | 480,000 / 0 | 60,000 / 0 | 60,000 / 0 | 60,000 / 0 |
| real_mut | 160,000 | 86,668 | 160,000 / 0 | 160,000 / 0 | 20,000 / 0 | 20,000 / 0 | 20,000 / 0 |
| real_reser | 66,000 | 61,773 | 66,000 / 0 | 66,000 / 0 | 6,000 / 0 | 6,000 / 0 | 6,000 / 0 |
| utf8 | 64,000 | 11,563 | 64,000 / 0 | 64,000 / 0 | 8,000 / 0 | 8,000 / 0 | 8,000 / 0 |
| grammar | 320,000 | - | 320,000 / 0 | 320,000 / 0 | 40,000 / 0 | 40,000 / 0 | 40,000 / 0 |
| string | 320,000 | - | 320,000 / 0 | 320,000 / 0 | 40,000 / 0 | 40,000 / 0 | 40,000 / 0 |
| version | 160,000 | - | 160,000 / 0 | 160,000 / 0 | 20,000 / 0 | 20,000 / 0 | 20,000 / 0 |
| time | 160,000 | - | 160,000 / 0 | 160,000 / 0 | 20,000 / 0 | 20,000 / 0 | 20,000 / 0 |
| loopback | 160,000 | - | 160,000 / 0 | 160,000 / 0 | 20,000 / 0 | 20,000 / 0 | 20,000 / 0 |
| exh_mini | 120,952 | 264 | 120,952 / 0 | 120,952 / 0 | 120,952 / 0 | 120,952 / 0 | 120,952 / 0 |
| exh_short | 1,118,480 | - | 1,118,480 / 0 | 1,118,480 / 0 | 1,118,480 / 0 | 1,118,480 / 0 | 1,118,480 / 0 |
| exh_dup | 299 | 1 | 299 / 0 | 299 / 0 | 299 / 0 | 299 / 0 | 299 / 0 |
| **total** | **3.77 M** | **336,000** | 3,770,775 / **0** | 3,770,775 / **0** | 1,553,979 / **0** | 1,553,979 / **0** | 1,553,979 / **0** |

("0 disagreements" with the byte-exact oracle; the UTF-8 difference of F1 is
counted apart, see README "The oracle".) Plus a separate `real_reser` run of
6,000 cases, seed 7, on `asan_J`: 0.

The 264 accepted cases of `exh_mini` are all version 0.1.9: edits that keep
the record valid (white space between tokens, `\/` for `/`, and a changed digit
of `published_at` that is still a real time - 86 different times, each equal to
the oracle's). Not one single edit of a valid record yields another accepted
version.

`unit` mode: 10,095,514 checks, 0 failures, in each of the five builds (N1 and
N2 are printed as "confirmed", not counted as failures).

`locales`: 928 pictures, 1 bad result (F4).

## Time and stack (C1)

Worst inputs of 256 KB, best of five runs, one fresh thread each
(`logs\perf_o2.txt`, `logs\perf_rtc.txt`):

| Input | `/O2` | `/Od /RTC1 /RTCc` |
|---|---|---|
| 256 KB of `[` / of `{"a":` | < 1 us (refused at level 33) | < 2 us |
| string of lone high surrogates | 0.29 ms | 1.2 ms |
| 43 K members | 0.89 ms | 2.6 ms |
| valid record, 20 K assets before the installer | 0.80 ms | **4.4 ms** |
| valid record, 1.1 K copies of the installer asset | **1.04 ms** | 2.7 ms |
| 3.9 K values nested to the limit | 0.75 ms | 1.9 ms |

Everything is linear in the input (two passes). Committed stack after the
parse: **<= 8,192 bytes** in both builds for every input (4 KB granularity,
thread start-up included); 24 KB under AddressSanitizer. The largest time seen
in the whole random campaign on `/O2`: 1.13 ms.

Remark, not a defect: a record with 1,100 copies of the installer asset is
accepted ("at least one element" in the contract).

## Is the suite able to see a defect? (`mutants.py`)

49 copies of the header with one planted defect each (`logs\mutants.txt`).

- **43 killed** - by `unit` (12), by the hand-written and random cases (31).
  Planted over-reads and buffer overflows by one byte were caught as access
  violations at the no-access page (`fit_off_by_one`, `append_number_size`,
  `append_text_size`, `hex_overread`).
- **6 survived, each shown to be an equivalent mutant** (no input can tell it
  from the original):
  - `depth_asset_elem`, `depth_asset_member` (pass 2 counts a level too
    shallow): pass 1 skips `assets` with the correct depth and refuses first.
    So the depth arguments 3 and 4 in `SalUpdReadAsset` cannot be observed -
    and pass 2 can never accept something pass 1 would refuse for depth.
  - `url_bad_ignored` (`!bad` dropped at line 922): a "bad" string is always
    stored as `""`, which never equals the wanted text. The `!bad` tests at
    908 / 915 / 922 are defence in depth.
  - `leap_100`, `second_60`, `hour_24`: on this Windows `SystemTimeToFileTime`
    itself refuses 2200-02-29, hour 24 and second 60 (checked directly), so the
    header's own range checks at 275-283 are a second line. The comment
    "accepts second 60 on some systems" was not reproduced here.
- The first run also had **two real holes in this suite**, since closed:
  `formfeed_space` (form feed taken as white space) and `hex_g` (`G` taken as a
  hex digit) survived because no generator produced non-JSON white space
  between tokens or the characters next to the hex ranges. Cases added (`hand`:
  9 kinds of non-JSON white space in 3 positions, 10 near-hex characters;
  tokens and string fragments for the random generators); both mutants are
  killed now, and seeds 8-10 ran with them against the real header: 0
  disagreements.
