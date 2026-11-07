# Contract - the code block copy address (feature 408)

Owner: `src/plugins/mdview` (htmlgen + viewer). Not a plug-in ABI; no other module
relies on it. Revised after review 1 (M1, M2, S1, S2): a host of its own, a native
notice instead of an in-page one, NULs dropped.

## Address

`https://mdcopy.invalid/<token>-<serial>/<n>`

- The host `mdcopy.invalid` is not the document's origin (`mdview.invalid`), so no
  document-relative link can resolve to it (a sibling file `tc-copy-notes.md` stays a
  link - review 1 M2).
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
inline stylesheet (the control transparent until its block is hovered or it has focus;
it takes a click while transparent - a tap or first click hit-tests before any hover).
Nothing else is added to the page. A document without code blocks, an empty `base`,
and `MdBuildSourceHtml` produce the document of before 408, byte for byte.

## Activation (`CViewerWindow::ActivateLink`, before any other branch)

`MdParseCopyLink(uri, CopyBase, codeBlocks.size(), &n)`:

- `MDCOPY_NONE` - not in the family `https://mdcopy.invalid/` -> the previous link rules;
- `MDCOPY_REFUSED` - in the family, anything but an exact match -> nothing happens;
- `MDCOPY_OK` -> `MdCodeClipboardText(codeBlocks[n])` to the clipboard
  (`CopyTextToClipboardW`, explicit length, no echo); on success the native notice.

Only user-initiated navigations reach `ActivateLink` (shared host, 085 F3).

## The notice (review 1 M1, S1)

A tracking tooltip window owned by the viewer, placed inside the bottom-right corner of
the client area, text `MdCopyNoticeText(LoadStrW(IDS_CODE_COPIED), clip, 60)` - *Copied*
and the first non-blank line of what was copied, at most 60 characters (cut at a whole
character, ellipsis). Hidden after 2.5 s or when the window is destroyed. It is outside
the page: the document's CSS can restyle the control, but cannot hide or fake the
notice, so a copy is never silent and always names what it copied. No navigation
happens, so the keyboard focus stays on the control. A failed copy shows no notice.

## Copied text (`MdCodeClipboardText`)

UTF-8 -> UTF-16; one trailing LF removed; U+0000 removed (the page shows none; md4c
repeats a NUL in its next text run); every LF not preceded by CR becomes CR LF.
