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
