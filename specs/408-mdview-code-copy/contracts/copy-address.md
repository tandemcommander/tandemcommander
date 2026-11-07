# Contract - the code block copy address (feature 408)

Owner: `src/plugins/mdview` (htmlgen + viewer). Not a plug-in ABI; no other module
relies on it.

## Address

`https://mdview.invalid/tc-copy-<token>-<serial>/<n>`

- `<token>`: 32 lowercase hex digits, `SalGenRandom` (16 bytes), one per viewer window.
- `<serial>`: decimal, the window's render counter at the time the page was generated.
- `<n>`: canonical decimal (no sign, no leading zero unless `0`, at most 9 digits),
  the index into `MdHtmlResult::codeBlocks` of the page.

## Generation (`MdRenderHtml`, `MdCopyUi::base` not empty)

Each Markdown code block (fenced or indented) is emitted as

```html
<div class="tc-code"><a class="tc-copy" href="BASE<n>" title="TOOLTIP">LABEL</a><pre><code …>…</code></pre></div>
```

and, once per document that has at least one block, the copy CSS is appended to the
inline stylesheet and two notices are appended to the article:

```html
<div id="tc-copied-0" class="tc-toast">COPIED</div><div id="tc-copied-1" class="tc-toast">COPIED</div>
```

A document without code blocks, an empty `base`, and `MdBuildSourceHtml` produce the
document of before 408, byte for byte.

## Activation (`CViewerWindow::ActivateLink`, before any other branch)

`MdParseCopyLink(uri, CopyBase, codeBlocks.size(), &n)`:

- `MDCOPY_NONE` - not in the family `https://mdview.invalid/tc-copy-` -> the previous link rules;
- `MDCOPY_REFUSED` - in the family, anything but an exact match -> nothing happens;
- `MDCOPY_OK` -> `MdCodeClipboardText(codeBlocks[n])` to the clipboard
  (`CopyTextToClipboardW`, explicit length, no echo); on success
  `Navigate(DocVersion, "tc-copied-<k>")`, `k` alternating 0/1.

Only user-initiated navigations reach `ActivateLink` (shared host, 085 F3).

## Copied text (`MdCodeClipboardText`)

UTF-8 -> UTF-16; one trailing LF removed; U+0000 -> U+FFFD; every LF not preceded by CR
becomes CR LF.
