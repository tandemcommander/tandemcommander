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
