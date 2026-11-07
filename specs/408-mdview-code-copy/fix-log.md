# Fix log - 408-mdview-code-copy

Backlog item `drobna-uprava-markdown-preview` (GitHub issue #20): a *Copy* control on
every code block of the Markdown Viewer.

## Measurement before (HEAD 924e7c82, on `main`)

- `tests\mdview_htmlgen_test\build_and_run.cmd` -> `53 passed, 0 failed`.
- `build_and_run.cmd dump` of a fenced C block -> `<pre><code class="language-c"><span class="hl-kw">int</span> a;`
  - no control: the gap exists.
- Reading: `src/common/webhost/webhost.cpp` NavigationStarting cancels every
  navigation not starting with `https://mdview.invalid/doc.html` and calls
  `Callbacks::OnActivateLink` only when `get_IsUserInitiated` (085 F3);
  NewWindowRequested does the same. mdview routes it to
  `CViewerWindow::ActivateLink` (viewer.cpp), where an in-host address such as
  `https://mdview.invalid/copy/3` reaches the "other local target" branch (a message
  box with the resolved path). So the shared host needs no change and no web message
  is needed.
- `BL verify` recorded at 924e7c82.

## Decisions

- D1. The copy address is `https://mdview.invalid/tc-copy-<token>/<n>`; `<token>` is
  32 hex digits from `SalGenRandom` (header-only `src/common/salrandom.h`) made once per
  viewer window. Every address with the prefix `https://mdview.invalid/tc-copy-` is
  consumed by the copy handler (a wrong token or number copies nothing and never falls
  through to the message box). Generator failure -> the window renders no controls.
- D2. Pure rules (the copied text from a block's source; parsing a copy address) live in
  `htmlgen.{h,cpp}` next to `MdPageWidthFromStored`, tested by the mdview generator
  harness (`tests/mdview_htmlgen_test`), not in `src/common/`: they are mdview's own
  and the harness is where mdview's pure rules are tested (314 precedent).
- D3. Copied text: the block's md4c source (`Gen::codeBuf`), one final LF dropped, NUL
  -> U+FFFD (what the page shows), LF -> CR LF (Code Viewer's copy rule), explicit
  length to `CopyTextToClipboardW`.

## Log

- Feasibility probe `probe/feas408_probe.ps1` on the HEAD build (hidden desktop,
  `result_feas.txt`): a raw-HTML document with a fixed red box styled by `:target`, a
  blue block link to `#t1`, a green block link to `foo.txt`. First run: probe error (my
  `$lines` collided with the library's `$script:Lines`); second: the click landed on the
  block's edge and the colour test was too strict (the page is colour-managed:
  green renders about 130,255,50). Third run 4/0: a click posted to
  `Chrome_RenderWidgetHostHWND` performs the fragment jump (red pixels 0 -> 4800), the
  page does NOT scroll (blue top 34 -> 34), and a click on `foo.txt` opens the viewer's
  "other local target" box - so a posted click counts as a user activation and the
  host's `OnActivateLink` route can be driven by a probe. Decision D4: the confirmation
  is a fixed-position notice shown by `:target` through a same-document fragment
  navigation (two notices used alternately, so every copy changes the target).
- speckit-analyze run 1: 0 CRITICAL, 0 HIGH; C1 MEDIUM (FR-005 untested) fixed by the
  FAILCOPY probe row in T013; C2 LOW (Find after a copy) accepted: the notice uses the
  same same-document fragment navigation as Find, a later Find navigates to its own
  fragment; C3 LOW (a self-started navigation) accepted: filtered by the shared host
  (085 F3) before the viewer sees it. Run 2: no CRITICAL / HIGH / MEDIUM left.

## Implementation

- T001 strings 2197-2199 (bundle 137 free slots, rule 084) in `mdview.rh2` / `lang/lang.rc2`.
- T002-T004 `htmlgen.{h,cpp}`: `MdCopyUi`, `MdHtmlResult::codeBlocks`, the wrapper
  `div.tc-code` + `a.tc-copy` per block, `CopyCss()` and the two `tc-copied-<k>` notices only
  when the page has a control, `MdCodeClipboardText`, `MdParseCopyLink`.
- T005-T006 harness `tests\mdview_htmlgen_test\build_and_run.cmd`: 53 -> **98 passed, 0
  failed** (45 new rows). Negative control: three temporary mutations of the generator
  (keep the last LF; accept a leading zero; add the CSS also to a page without blocks) ->
  89 passed, **9 failed** (exactly the rows for those rules); the file restored from a copy
  (CRLF checked: 907 CRLF, 0 LF).
- T007-T010 `viewer.{h,cpp}`: token (16 bytes of `SalGenRandom`, hex) per window; serial per
  rendered rebuild; `ActivateLink` asks `MdParseCopyLink` first (OK -> `CopyCodeBlock`,
  REFUSED -> nothing); `CopyCodeBlock` copies with `CopyTextToClipboardW` (explicit length,
  > INT_MAX refused) and on success navigates to `#tc-copied-<k>` (k alternates); the Debug
  seam `TC_MDVIEW_PROBE_COPY_LOG` (contracts/probe-seam.md).
- T011: `git diff main -- src/common/webhost src/plugins/mdview/webglue.cpp` is empty;
  `MdConfigureHost` still sets `ScriptsEnabled = false`, `WebMessagesEnabled = false`.
- `.\build.cmd` -> BUILD SUCCEEDED, no mdview warning.

## Probe `copy408_probe.ps1` (hidden desktop)

- Before: no build of HEAD kept (the run rebuilt it); the state before is the HEAD
  measurement above (no control in the generated page) and the feasibility probe (a click on
  an in-host address reaches the viewer's "other local target" box - what a forged copy link
  would have done before the copy branch).
- Run 1: OPEN FAIL - my fixture's list block was empty (six backticks before `n in
  PowerShell = three backticks + a literal n: the fence took "n  in list" as its info string).
- Run 2: 13 PASS / 2 FAIL: SHOWN (one posted move, no hover) and KEY (the probe expected
  block 0, but Tab continues from the last clicked link, foo.txt, so it focused block 1's
  control and Enter copied block 1 - correct browser behaviour; the screenshot shows the
  control with its focus outline).
- Run 3: KEY PASS (586 px changed in block 1's corner, seam = block 1); SHOWN still 0 px.
- Run 4 (final, `result_after.txt`): **14 PASS, 0 FAIL, 1 NOT DRIVEN** - SHOWN NOT DRIVEN
  with a control: an ordinary document link, whose `a:hover` rule exists since 021, changes 0
  px under the same posted moves, so posted moves produce no hover on the hidden desktop. The
  look on hover is a person's check. COPY-0 (Czech + emoji, CR LF, no last line break, block
  top 37 -> 37), NOTICE (ink 0 -> 2083), GONE (0 after 5.2 s), AGAIN (block 2, notice again),
  NOSCROLL (wheel scrolled: tops 360,523 -> 360,523 after a copy of block 1), FORGED-MD,
  FORGED-HTML (no seam file, no window), LINK (foo.txt box unchanged), KEY, SOURCE (no
  copy), FAILCOPY (seam = a folder: notice ink 0).

## Translations (stop-rules §2.13, module `mdview`)

- Step 0: new ids `IDS_CODE_COPY` 2197, `IDS_CODE_COPY_TIP` 2198, `IDS_CODE_COPIED` 2199;
  no changed id. Leftover `english_fallback` rows before: 0 in every language.
- Export `src\vcxproj\build_langs.cmd --export-templates --module mdview` -> 1/1.
- Dry run (`--formality prefer_more`): 3 unique gaps, ~40 chars in each of the 8 enabled
  languages (cs, de, fr, nl, hu, ro, sk, es) = the 3 new texts.
- Merge `--budget 2640`: 3/3 translated per language, **320 DeepL characters**, 0 validation
  failures, 0 duplicate accelerators, "controls widened to fit: 21" (the pipeline's refit; the
  committed `.slt` diff is 5 lines per language - the three rows and the section's count -
  so no dialog drift was written).
- Read-back: cs Kopírovat / Zkopírujte kód do schránky / Zkopírováno; de Kopieren / Kopieren
  Sie den Code in die Zwischenablage / Kopiert; fr Copier / Copier le code dans le
  presse-papiers / Copié; nl Kopiëren / Kopieer de code naar het klembord / Gekopieerd; hu
  Másolás / Másolja a kódot a vágólapra / Másolva; ro Copiere / Copiați codul în clipboard /
  Copiat; sk Kopírovať / Skopírujte kód do schránky / Skopírované; es Copiar / Copie el código
  al portapapeles / Copiado. The labels are the module's own Copy verb (`2011` Edit > Copy:
  &Kopírovat, &Kopieren, &Copier, &Kopiëren, &Másolás, C&opiere, K&opírovať, &Copiar); formal
  register (Sie, usted; fr/nl infinitive / neutral imperative, no tu/je). **No pin needed.**
- `python -m translate.slt --verify` -> 298 files, 91535 entries, all byte-exact.
- `.\build.cmd full` -> BUILD SUCCEEDED (language modules import).

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd full` -> BUILD SUCCEEDED.
- `saltests.exe` -> `saltests: 282613 checks, 0 failed` (no core / src/common file changed;
  run as a sanity check).
- Harness -> 98 passed, 0 failed.
- T016 manual: `help/` has no Markdown Viewer page (only a one-line mention in
  `configuration_gener.htm` and the upstream `introduction_news.htm`, untouched since 007) -
  nothing to update.
- T017 person check -> the release checklist at closing.

## Review

### Review 1 (refute-first agent) - 2 MUST, 2 SHOULD, NOTEs

- **M1** a document restyles the genuine control (raw `<style>`, `unsafe-inline`):
  stretched over the page, invisible, the block hidden -> a click on "a link" copied
  `HIDDEN PAYLOAD` silently (its row HIJACK). In-page defences cannot win (ancestors'
  opacity/transform cannot be overridden from the control). **Fixed**: the in-page notice
  (`#tc-copied-k`, `:target`) is gone; the viewer shows a **native** notice - a tracking
  tooltip of its own window at the bottom right, *Copied* + the first non-blank copied
  line (at most 60 characters, cut at a whole character, `MdCopyNoticeText`) for 2.5 s. A
  copy is never silent and names what it copied. Recorded as an assumption in the spec
  (the restyled click still copies the document's own block; a confirmation step or
  scripts would be the maintainer's).
- **M2** `[n](tc-copy-notes.md)` resolved into the consumed family `https://mdview.invalid/tc-copy-`
  and did nothing (before 408: opens the file). **Fixed**: the family is a host of its own,
  `https://mdcopy.invalid/`, which no document-relative link can reach. Harness rows
  (`tc-copy-notes.md`, an in-host address with the token -> NONE), probe row LINK-TCCOPY.
- **S1** the fragment jump took the keyboard focus off the control (second Enter copied
  nothing; Tab restarted). **Fixed** by M1's change (no navigation any more); probe row
  KEY-AGAIN (second Enter copies again, the control still shown).
- **S2** md4c repeats a NUL in its next text run; the copy gave two U+FFFD while the page
  shows nothing. **Fixed**: NULs are dropped; harness row through a real md4c render.
- NOTE invisible but clickable: first tried `pointer-events:none` until hover/focus -
  measured: probe COPY-0 then FAILED (a first click / tap hit-tests before any hover and
  fell through to the block). Reverted: the transparent control takes a click; with the
  native notice such a click is never silent. Harness row checks there is no
  `pointer-events` rule.
- NOTE probe header KEY text - fixed (block 1, and why).
- NOTE select-all + copy of the page leaving out the label (`user-select:none`) - a
  person's check (release checklist).

Fix work: the first native-notice run found the tooltip at 1154,862-1227,897, partly
outside the 0,0-1200,900 viewer (TTM_GETBUBBLESIZE stale before the first display);
now the tip is shown, its real size read, then placed. `TOOLINFOW` size = 
`TTTOOLINFOW_V2_SIZE` (valid for every common-controls version). The CR LF of
`viewer.cpp` was lost once by a `sed -i` of Git Bash and restored (1219 CRLF, 0 LF).

After the fixes: harness **105 passed, 0 failed**; `.\build.cmd` BUILD SUCCEEDED; probe
`result_after.txt` **18 PASS, 0 FAIL, 1 NOT DRIVEN** (SHOWN, hover - environment, with its
control). New rows: NOTICE (tooltip 1095,833-1168,868 inside the viewer's bottom-right
quarter, text `Copied\nalpha line 1`), GONE (hidden 4 s later), AGAIN, LINK-TCCOPY (a viewer
for tc-copy-notes.md opens), KEY-AGAIN, FAILCOPY (no tooltip), HIJACK (copies the hidden
block, tooltip visible, text `Copied\nHIDDEN PAYLOAD`). Negative controls for these rows
are the reviewer's measurements on the previous build (SEQ-2 copied nothing, LINK-TCCOPY
no window, HIJACK no visible sign).

### Review 2 (refute-first agent) - 1 MUST, 1 SHOULD, 5 NOTEs

The reviewer reproduced harness 105/0 and the probe 18/0/1 on its own run.

- **M1** a tab in a code line's indentation was copied as spaces (md4c writes a line's
  indentation from a static string of spaces, `md4c.c` `md_process_verbatim_block_contents`;
  a Makefile pasted from the copy fails). **Fixed**: the generator keeps a copy buffer of
  its own (`Gen::copyBuf`); an indentation run whose pointer lies outside the document is
  held, and when the line's text (a pointer into the document) follows, `RecoverIndent`
  walks back over the whitespace within the announced columns (tab stops of 4) and copies
  it as written; a tab straddling the container / block indentation gives its share as
  spaces (CommonMark). Anything that does not add up keeps md4c's spaces. The page is
  unchanged (it still renders `codeBuf`). Harness rows: fenced Makefile (tabs kept, page
  still spaces), indented block `\t\tbar` -> `\tbar`, list, straddling tab in a list item
  (`  code`), quote `>\t\tq` (`  q`, CommonMark example 6), spaces stay spaces, an
  indented fence, a whitespace-only line. Negative control: `RecoverIndent` forced to
  return spaces -> **4 rows fail** (112/4); restored -> 116/0.
- **S1** the notice named only the first line, so a hidden block starting `# Welcome`
  still hid `curl evil | sh`; a bidi override passed into the notice. **Fixed**:
  `MdCopyNoticeText(..., 60, 3)` shows up to three non-blank lines and a last line `…`
  when more follow; C0/C1 controls and bidi formatting characters (U+202A-202E,
  U+2066-2069, U+200E/F, U+061C) are shown as spaces. The spec states the remaining risk
  (a click on a disguised element overwrites the clipboard - new with 408 - but never
  silently). Harness rows; probe HIJACK now uses the reviewer's multi-line payload:
  notice `Copied\n# Welcome\nline 2\nline 3\n…`.
- **N1** the notice tooltip is not dark-themed (readable; noted, not changed - native
  tooltips of the product are not themed either).
- **N2** **fixed**: the notice is kept inside the work area of the viewer's monitor
  (`MonitorFromWindow` / `GetMonitorInfoW`), coordinates passed as signed words.
- **N3** **fixed**: the tooltip text of the control was an imperative addressed to the
  reader in cs/sk/de/es/hu/ro/nl; pinned to the action form in
  `translations/ui-overrides.json` (`mdview` / `_feature_408`, `IDS_CODE_COPY_TIP`): cs
  Zkopírovat kód do schránky, sk Skopírovať kód do schránky, de Code in die Zwischenablage
  kopieren, es Copiar el código al portapapeles, hu Kód másolása a vágólapra, ro Copierea
  codului în clipboard, nl De code naar het klembord kopiëren (fr already infinitive). The
  merge applied them: only row 2198 changed in each `.slt` / `.origin`; `slt --verify`
  298 files byte-exact.
- **N4** Release build: `.\build.cmd full release` (result below).
- **N5** checks without defect - recorded.

After the fixes: harness **116 passed, 0 failed**; `.\build.cmd full` BUILD SUCCEEDED;
probe **18 PASS, 0 FAIL, 1 NOT DRIVEN** (NOTICE text `Copied\nalpha line 1\nbeta
čeština 😀`, HIJACK as above).
- N4: `.\build.cmd full release` -> **BUILD SUCCEEDED** (LTO); Release `mdview.spl` (320,000
  bytes) holds the family `https://mdcopy.invalid/` (UTF-16) and **not** the seam name
  `TC_MDVIEW_PROBE_COPY_LOG`; the Debug `mdview.spl` holds it (the seam is Debug-only).

### Review 3 (refute-first agent) - no MUST, 2 SHOULD, 7 NOTEs

The reviewer reproduced the harness 116/0, ran five mutations of its own (each caught),
fuzzed the tab recovery (about 352,000 blocks, 0 failures), and confirmed pages without
the control byte-identical to `main`.

- **S1** FORGED-MD / FORGED-HTML could not see a fall-through to the browser (another
  process). **Fixed**: the Debug seam also records what `ActivateLink` would hand to the
  shell (`<seam>.shell`, contracts/probe-seam.md) instead of starting a browser; the
  FORGED rows assert nothing was handed over, and a new row **LINK-HTTP** (an https link)
  is their positive control (`handed to the shell: https://example.invalid/tc408`). Probe
  traps met: my colour search took the orange emoji of block 0 for the orange link box
  (now a match must hold 100 px to the right too); the second viewer window of
  LINK-TCCOPY took the activation and later posted clicks were lost (that row now runs
  last; it leaves View Source first).
- **S2** a document can make a click overwrite the clipboard (the restyled genuine
  control) - a trade-off for the maintainer: **decision item**
  `markdown-viewer-copy-control-may-a-document-make-a-click` (Inbox; options A accept /
  B undo in the notice / C ask before copying / D, E not possible or the 021 question;
  recommendation A).
- **N1** slower renders with the control (per-line allocation in the tab recovery):
  **fixed** - `AppendIndent` appends straight into the copy buffer, no vector, no
  temporaries. The reviewer's own timing program on the HEAD sources (19 MB documents,
  without / with the control): 1103 / 1460 ms, 320 / 452 ms, 1220 / 1654 ms (before the
  fix 1119 / 2457, 314 / 741, 1237 / 3056). Its fuzz on the new code: 117,660 blocks,
  47,371 with tabs, **0 bad**.
- **N2** the block was copied into the table: **fixed** (`std::move`).
- **N3** invisible / blank-looking characters (U+00AD, U+200B, U+2060, U+FEFF, U+2028/9,
  U+2800, U+3164, U+115F/1160, U+FFA0, U+3000, U+2000-200A, U+00A0, U+202F, U+205F)
  now count as spaces in the notice, so a line of them is not a shown line; the 60-character
  cut never separates a letter from a following combining mark. Harness rows.
- **N4** the control could be dragged (dropping the address): **fixed**
  (`-webkit-user-drag:none`), harness row.
- **N5** past the 40 MB output cap a skipped code block was emitted again with the
  previous block's text (before 408 too): **fixed** (`LeaveBlock` emits only a block
  `EnterBlock` opened), harness row; negative control: the guard removed -> that row
  fails (119/1).
- **N6** each block is now wrapped in `div.tc-code`, so a document's own CSS selectors
  like `li > pre` stop matching - accepted, a limit named in the changelog.
- **N7** closing work - done at closing.

After the fixes: harness **120 passed, 0 failed**; `.\build.cmd full` BUILD SUCCEEDED;
probe **19 PASS, 0 FAIL, 1 NOT DRIVEN**.

### Review 4 (refute-first agent, focused on the changes after review 2) - no MUST, 1 SHOULD, 4 NOTEs

The reviewer compared `AppendIndent` with the review-2 `RecoverIndent` on 600,000 random
documents (about 424,000 blocks with tabs): copy buffers and page bodies identical; its
own mutation (`col >= target` -> `col > target`) made 32,575 of 150,000 differ. The cap
guard and the `.shell` seam held.

- **S1** the review-3 change cut the notice line inside an emoji: the surrogate check ran
  before stepping back over combining marks, joiners and variation selectors (e.g. 🗑️ =
  U+1F5D1 U+FE0F at column 59-60). **Fixed**: marks first, then the pair. Harness row
  (astral letter + mark, ZWJ sequence, emoji + U+FE0F, 58 letters + an emoji at the real
  60); negative control: the old order -> that row fails (122/1).
- **N1** a comment above the wrong function - fixed.
- **N2** combining marks of other scripts: `IsCombiningMark` now asks the system's
  character types (`GetStringTypeW` CT_CTYPE3: nonspacing, diacritic, vowel mark) plus
  ZWJ and variation selectors; harness row with Devanagari and Hebrew marks.
- **N3** a guard in `AppendIndent` unreachable from md4c (a mutant survived) - harmless,
  kept as a fail-safe.
- **N4** past the output cap the text of skipped blocks still reached the page as plain
  text (before 408): **fixed** (`Text` returns once the cap is reached); harness row.

After the fixes: harness **123 passed, 0 failed**; `.\build.cmd full` BUILD SUCCEEDED;
probe **19 PASS, 0 FAIL, 1 NOT DRIVEN**; saltests 282613 / 0. No further review: review 4
had no MUST and its fixes each have a failing negative control.

## Closing

- Release checklist (`manual-checks-owed-before-the-next-release`): 3 lines added (real
  clipboard and look in light/dark with Tab+Enter and a Makefile; select-all copy without
  the labels; touch / pen tap).
- Decision item: `markdown-viewer-copy-control-may-a-document-make-a-click` (review 3 S2).
- No `## [Unreleased]` section in `CHANGELOG.md`: the entry text is in `closing-report.md`.
- GitHub #20: draft answer in `specs/408-mdview-code-copy/reply.md`.
