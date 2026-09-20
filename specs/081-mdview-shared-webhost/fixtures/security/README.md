# Security fixture corpus — feature 081

One hostile construct per file, so a failing row names its own cause, plus one
legitimate control document that must render completely. Feature 021's
quickstart described such a corpus under `specs/021-mdview-html-renderer/fixtures/security/`
but it was never committed (research R8); this is it.

**How to run**: copy this folder somewhere ordinary (the probes use
`%TEMP%\md081\`) so relative links and `assets\dot.png` resolve exactly as a
user's folder would, point a panel at it and press F3 on each file in turn.
Rows B1–B9 of [`../../quickstart.md`](../../quickstart.md) are this list.
Every file carries a `MARKER-nn` line: **if you can read the marker and the
document still looks like a document, the file passed.**

| File | Construct | Must happen | Checklist row |
|---|---|---|---|
| `01-script-tag.md` | inline, external, module and deferred `<script>` | the document keeps its heading, marker and table; nothing says `PWNED`; no request for `evil.js` | B1 |
| `02-event-handlers.md` | `onerror` on a broken image, `onclick`, `onmouseover`, `<svg onload>`, `onfocus` | nothing fires, hovering and clicking change nothing | B2 |
| `03-javascript-link.md` | `javascript:` in Markdown and raw HTML, plus `ftp:`, `file:`, `vbscript:`, `data:text/html` | each click → the viewer's *link blocked* message; the document is unchanged | B3 |
| `04-remote-image.md` | remote `<img>`, `srcset`, `<picture>`, protocol-relative source, `url()` in a style, `@font-face` | placeholders only and **zero network** before consent | B4 |
| `05-iframe.md` | `<iframe>` (remote and own origin), `<object>`, `<embed>`, `<video>`, `<audio>`, `<link rel=prefetch/stylesheet>` | nothing loads, zero network | B5 |
| `06-meta-refresh.md` | immediate, delayed and own-origin meta refresh, plus a hostile `<base>` | after 10 s you are still on the document; the local image below the `<base>` never becomes a remote fetch | B6 |
| `07-form.md` | forms posting remote, to the own origin, and to self | clicking submits does nothing — **silently** since 0.1.8 (before: *link blocked*); zero network | B7 |
| `08-path-traversal-image.md` | `../`, deep traversal, absolute path, UNC, percent-encoded and backslash traversal | six placeholders; the seventh image (inside the folder) renders | B8 |
| `09-download-link.md` | `<a download>` for a `data:` blob, the own document, a refused path, a remote file, and an executable `data:` URI | **no download bubble, no file saved** — the one hardening of 081 you can see | B9 |
| `10-legit-control.md` | inline `<style>` + `style=`, a local image, a `data:` image, an image title, an aligned table, a highlighted `c` block, `<kbd>/<sub>/<sup>/<mark>/<abbr>/<del>/<ins>/<details>`, lists, tasks, a quote, all six link kinds, accented text | **everything renders**; this is also the pixel-comparison document | A1, A6, D1 |
| `10b-linked.md` | the target of the `.md` link | opens in a **new** viewer window | A6 |
| `notes.txt` | the target of the non-Markdown local link | the viewer shows its path and launches nothing | A6 |
| `hello.cpp` | a source file for the Code Viewer | used by row C8 to warm the shared engine from the *other* plugin | C8 |
| `assets/dot.png` | 32×32 green square | the local image of the control document | A1 |
| `assets/datauri.txt` | the `data:` URI of a 32×32 magenta square | already substituted into `10-legit-control.md`; kept so the corpus can be regenerated | — |
| `gen_assets.py` | regenerates both assets (stdlib `zlib` + `struct`, no Pillow) | `python gen_assets.py` | — |

## What "zero network" means here

`example.invalid` cannot resolve by design (RFC 2606), so a request that *is*
attempted fails quietly — the absence of a picture proves nothing. The
network monitor is what proves the refusal: with a capture running you must
see **no DNS query and no connection attempt** for `example.invalid` while
the hostile files are open. That is why rows B1–B9 have a monitor column.

## Regenerating

```bat
python gen_assets.py
python -c "import pathlib;u=pathlib.Path('assets/datauri.txt').read_text().strip();p=pathlib.Path('10-legit-control.md');p.write_text(p.read_text(encoding='utf-8').replace('@@DATAURI@@',u),encoding='utf-8')"
```

(the second line only matters if the placeholder is reintroduced; the
committed document already carries the URI).
