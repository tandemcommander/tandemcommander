# 02 — Inline event handlers must never fire

**PASS looks like**: the marker line is readable and nothing changes when you
move the mouse over the document or click in it. **FAIL** is any text turning
into `PWNED`.

> MARKER-02: no handler fired.

An image whose `onerror` fires as soon as the source fails to load — the most
reliable script trigger there is, because the source is guaranteed to fail:

<img src="x-does-not-exist" onerror="document.body.innerHTML='<h1>PWNED</h1>'" alt="broken image">

A click handler (click the box):

<div onclick="document.body.innerHTML='<h1>PWNED</h1>'" style="border:1px solid #888;padding:8px">Click me — nothing must happen.</div>

A mouse-over handler (hover the text):

<span onmouseover="document.body.innerHTML='<h1>PWNED</h1>'">Hover me — nothing must happen.</span>

A load handler on the body-level element:

<svg onload="document.body.innerHTML='<h1>PWNED</h1>'" width="10" height="10"></svg>

A handler that runs on focus, reached by pressing Tab:

<input type="text" onfocus="document.body.innerHTML='<h1>PWNED</h1>'" value="press Tab">
