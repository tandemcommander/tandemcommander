# 06 — The view must not navigate away by itself

**PASS looks like**: after ten seconds you are still looking at this document.
**FAIL** is the viewer showing another page, going blank, or showing the
engine's error page.

> MARKER-06: still on the document.

An immediate meta refresh to a remote page:

<meta http-equiv="refresh" content="0;url=https://example.invalid/gone.html">

A delayed one (fires at ~3 s, after the first paint — a different code path
inside the engine):

<meta http-equiv="refresh" content="3;url=https://example.invalid/late.html">

A refresh onto our own origin with a path the interceptor does not serve:

<meta http-equiv="refresh" content="1;url=/img/9999">

A `<base>` element, which would silently re-point every relative URL in the
document (the policy's `base-uri 'none'` must refuse it):

<base href="https://example.invalid/">

Because of the `<base>` above, this local image would resolve to
`https://example.invalid/assets/dot.png` if the base were honoured — it must
stay a local reference or a placeholder, never a remote fetch:

![local image under a hostile base](assets/dot.png)
