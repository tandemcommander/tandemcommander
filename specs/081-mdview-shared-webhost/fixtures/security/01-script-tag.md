# 01 — Script tags must not run

**PASS looks like**: you can read the line below, and the document still has
its heading, this paragraph and the table. **FAIL** is a page showing only the
word `PWNED`, or a page that goes blank.

> MARKER-01: scripts did not run.

An inline script that would replace the whole document if scripts were on:

<script>document.body.innerHTML = '<h1>PWNED</h1>';</script>

An external script (also a network request the interceptor must refuse):

<script src="https://example.invalid/evil.js"></script>

A module script, which takes a different loader path inside the engine:

<script type="module">document.body.textContent = 'PWNED';</script>

A deferred script:

<script defer src="https://example.invalid/late.js"></script>

| Still here? | Yes |
|---|---|
| Heading | yes |
| Marker | yes |
| Table | this one |
