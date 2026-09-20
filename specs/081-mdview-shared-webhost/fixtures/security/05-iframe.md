# 05 — Framed and embedded content must not load

**PASS looks like**: nothing but empty space (or a thin border) where each
element sits, and **no network request**. **FAIL** is any remote page, plugin
surface or media appearing.

> MARKER-05: nothing embedded loaded.

An iframe to a remote page:

<iframe src="https://example.invalid/frame.html" width="300" height="80" style="border:1px solid #888"></iframe>

An iframe to our own origin (the document itself — `frame-ancestors 'none'`
and the interceptor must both refuse it):

<iframe src="doc.html" width="300" height="80" style="border:1px solid #888"></iframe>

An object and an embed:

<object data="https://example.invalid/thing.swf" width="200" height="60"></object>

<embed src="https://example.invalid/thing.pdf" width="200" height="60">

Media elements, which fetch without any script:

<video src="https://example.invalid/clip.mp4" width="200" controls></video>

<audio src="https://example.invalid/sound.mp3" controls></audio>

A prefetch hint and a stylesheet link — both are network requests issued by
the parser before anything is displayed:

<link rel="prefetch" href="https://example.invalid/next.html">
<link rel="stylesheet" href="https://example.invalid/evil.css">
