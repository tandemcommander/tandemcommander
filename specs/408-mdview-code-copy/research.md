# Research - 408-mdview-code-copy

## R1. How the page reaches the viewer without script

- Decision: a plain `<a href>` to an address in the viewer's own origin that is not
  `doc.html`; the shared host's NavigationStarting cancels it and calls
  `Callbacks::OnActivateLink` when the engine reports it user-initiated (085 F3);
  NewWindowRequested (Ctrl/Shift/middle click) does the same.
- Rationale: the hook exists and is already the link route of mdview; no host change,
  no web message (FR-006). Measured: `probe/feas408_probe.ps1`, a posted click is a
  user activation.
- Alternatives: enabling scripts + `navigator.clipboard` (maintainer's decision, item
  Notes); a new web-message channel (forbidden by the lockdown); a host change (not
  needed).

## R2. Forged copy addresses

- Decision: `https://mdview.invalid/tc-copy-<token>-<serial>/<n>`; `<token>` = 32 hex
  digits of `SalGenRandom` per window; `<serial>` counts the window's renders. Every
  address in the family `https://mdview.invalid/tc-copy-` is consumed by the copy branch:
  an exact match copies, anything else does nothing (no fall-through to the message box
  of local targets). Generator failure: no token, no controls.
- Rationale: the document cannot read the token (no script), so its own links cannot
  copy; the serial makes a click on a page that is being replaced copy nothing rather
  than a block of another file (OpenFile in the same window).
- Alternatives: a fixed `copy/<n>` (any document link `copy/3` would copy; a legitimate
  relative link to a folder `copy` would be swallowed).

## R3. Feedback without script

- Decision: two fixed-position notices `#tc-copied-0` / `#tc-copied-1` emitted once per
  document with code blocks; CSS `:target` runs a fade-out animation; after a copy the
  viewer calls `CTcWebHost::Navigate(DocVersion, L"tc-copied-<k>")`, alternating `k` so
  the target changes on every copy.
- Rationale: measured on HEAD, a fragment jump to a fixed element does not scroll; Find
  already uses same-document fragment navigation (`mdfind-N`); `mark:target` is a
  precedent.
- Alternatives: re-rendering the page with the control reading *Copied* (reloads and
  jumps to the top, the 314 trap); `:focus` styling (no feedback for Enter, shows on Tab).

## R4. Where the pure rules live

- Decision: `MdCodeClipboardText` and `MdParseCopyLink` in `htmlgen.{h,cpp}`, tested by
  the mdview harness.
- Rationale: they are mdview's own (its address, its generator's source table); the
  harness is how mdview's pure rules are tested (314 `MdPageWidthFromStored`);
  `saltests` does not link mdview sources.

## R5. The copied text

- Decision: md4c's code text (`Gen::codeBuf`) as stored; one final LF removed; NUL ->
  U+FFFD; LF not preceded by CR -> CR LF; explicit length to `CopyTextToClipboardW`.
- Rationale: md4c delivers each code line followed by LF and strips container prefixes
  and the four-space indentation (the code as Markdown defines it); the page shows no
  empty last line; the Code Viewer's copy uses CR LF and an explicit length.

## R6. Strings

- Decision: three strings in the free slots 2197-2199 of the existing bundle 137
  (2192-2207, the runtime messages): "Copy", "Copy the code to the clipboard", "Copied".
- Rationale: rule 084 (free slots of an existing bundle). Loaded with `LoadStrW`,
  converted to UTF-8 for the page (never `LoadStr`, which is code page).
