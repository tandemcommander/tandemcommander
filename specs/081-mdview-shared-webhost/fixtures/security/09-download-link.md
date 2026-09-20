# 09 — A document must not be able to start a download

This is the one hardening of feature 081 that is visible on screen. On the
**reference** (pre-081) build the engine's default download handling applied,
so clicking a link below could show the download bubble in the corner of the
viewer, or drop a file in the Downloads folder. From 0.1.8 the host cancels
every download before it starts.

**PASS looks like**: clicking each link does nothing — no bubble, no file in
`%USERPROFILE%\Downloads`, no dialog. **FAIL** is any of those appearing.

> MARKER-09: nothing was downloaded.

A `data:` download, which needs no network at all and is the one most likely
to succeed on the reference build:

<a href="data:application/octet-stream;base64,VGFuZGVtIENvbW1hbmRlciAwODEgZG93bmxvYWQgcHJvYmU=" download="tc081-probe.bin">Download a data: blob (must do nothing)</a>

A download of the document's own origin:

<a href="doc.html" download="doc.html">Download the document itself (must do nothing)</a>

A download of a path the interceptor refuses:

<a href="img/9999" download="nothing.bin">Download a refused path (must do nothing)</a>

A remote download:

<a href="https://example.invalid/payload.exe" download="payload.exe">Download from a remote host (must do nothing)</a>

A download with no `download` attribute but a content type the engine would
not display inline — the other route into the download path:

<a href="data:application/x-msdownload;base64,TVqQAAMAAAAEAAAA">Open an executable data: URI (must do nothing)</a>
