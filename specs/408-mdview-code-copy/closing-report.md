# Closing report - 408-mdview-code-copy
Backlog item: drobna-uprava-markdown-preview - Markdown Viewer: a button to copy a code block to the clipboard
Outcome: closed

## What changed

- `src/plugins/mdview/htmlgen.{h,cpp}`: every fenced or indented code block is wrapped in
  `div.tc-code` with an `a.tc-copy` control linking to
  `https://mdcopy.invalid/<token>-<serial>/<n>`; the copy CSS (transparent until the block
  is hovered or the control focused, theme variables, not draggable) only on pages with a
  control; `MdHtmlResult::codeBlocks` holds each block's source with the line indentation
  taken back from the document (tabs kept); pure rules `MdCodeClipboardText` (CR LF, no
  last line break, no NUL), `MdParseCopyLink` (exact address only; the whole family is
  consumed), `MdCopyNoticeText` (*Copied* + up to three lines + `…`, controls / bidi /
  blank-looking characters as spaces, whole-character cut). Found on the way: past the 40 MB
  output cap a skipped code block was emitted again and skipped text still reached the page
  (before 408 too) - fixed.
- `src/plugins/mdview/viewer.{h,cpp}`: per-window token (`SalGenRandom`), per-render serial,
  `ActivateLink` asks the copy rule first, `CopyCodeBlock` (`CopyTextToClipboardW`, explicit
  length), the native notice (tracking tooltip, bottom right, kept on the work area, 2.5 s);
  Debug-only seam `TC_MDVIEW_PROBE_COPY_LOG` (copy text, notice text, links handed to the
  shell).
- Strings `IDS_CODE_COPY` / `_TIP` / `IDS_CODE_COPIED` (2197-2199, free slots of bundle 137),
  translated in 8 languages, the tooltip pinned to the action form.
- The shared WebView2 host is unchanged; scripts and web messages stay off.

## Measurements (before / after, commands)

- Before (HEAD 924e7c82): `tests\mdview_htmlgen_test\build_and_run.cmd dump` of a fenced block
  -> a bare `<pre><code>`; harness 53 / 0. Feasibility `probe/feas408_probe.ps1` on the HEAD
  build: 4 / 0 (a posted click is a user activation that reaches the viewer; a fragment jump
  to a fixed element does not scroll).
- After: harness 123 passed, 0 failed; `probe/copy408_probe.ps1` (hidden desktop) 19 PASS,
  0 FAIL, 1 NOT DRIVEN (`result_after.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd full` -> BUILD SUCCEEDED; `.\build.cmd full release` -> BUILD SUCCEEDED (seam
  absent from the Release `mdview.spl`).
- `saltests.exe` -> 282613 checks, 0 failed (no core change).
- Translations: 3 strings x 8 languages, 320 DeepL characters, 7 pins (`_feature_408`),
  `slt --verify` 298 files byte-exact.
- Probe rows: OPEN, COPY-0, NOTICE, GONE, AGAIN, NOSCROLL, FORGED-MD, FORGED-HTML, LINK,
  LINK-HTTP, KEY, KEY-AGAIN, SOURCE, LINK-TCCOPY, FAILCOPY, HIJACK PASS (+ end rows);
  SHOWN NOT DRIVEN (posted moves give no hover; an ordinary link does not hover either).

## Reviews (findings and what was done)

- Review 1: M1 a restyled genuine control copied a hidden block silently -> native notice;
  M2 `tc-copy-notes.md` swallowed -> host of its own; S1 focus lost -> no navigation; S2 NUL
  doubled -> dropped.
- Review 2: M1 tabs copied as spaces -> indentation taken back from the document; S1 one
  line in the notice -> three lines + `…`, bidi hidden; N2, N3 (pins), N4 (Release) done.
- Review 3: no MUST; S1 forged rows blind to a browser -> shell seam + LINK-HTTP; S2
  clipboard trade-off -> decision item; N1 speed, N2 move, N3 invisible characters, N4 drag,
  N5 stale block past the cap - fixed; N6 limit recorded.
- Review 4: no MUST; S1 half emoji in the notice -> fixed; N1, N2, N4 fixed; N3 harmless.
- Details: `fix-log.md`, section *Review*.

## Owed to a person (the lines added to the release checklist)

`manual-checks-owed-before-the-next-release`, 3 lines (feature 408): the real clipboard and
the look in light and dark schemes (hover, notice, Tab + Enter, a Makefile with tabs);
select-all copy without the labels; a touch / pen tap.

## CHANGELOG entry (no `## [Unreleased]` section in CHANGELOG.md - for the maintainer)

- **Markdown Viewer: no way to copy a code block but selecting it** (feature 408) - every
  code block now has a *Copy* control in its top-right corner (on hover, or Tab); a click or
  Enter puts the block's code on the clipboard exactly as written (tabs and line breaks
  kept, no highlighting), and a small notice at the viewer's bottom right shows what was
  copied. The viewer still runs no script. Limits: not on raw-HTML `<pre>` elements or in
  View Source; a document's own CSS rules such as `li > pre` no longer match code blocks.
  (GitHub #20)

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- Past the 40 MB output cap a skipped code block was emitted again with the previous
  block's text, and the text of skipped blocks still reached the page (both before 408);
  harness rows, negative control.

## New Inbox items (slug - title)

- markdown-viewer-copy-control-may-a-document-make-a-click - Markdown Viewer copy control:
  may a document make a click overwrite the clipboard
