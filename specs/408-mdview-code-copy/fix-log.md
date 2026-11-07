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
