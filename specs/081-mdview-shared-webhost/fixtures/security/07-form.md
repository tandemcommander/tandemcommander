# 07 — Forms must not be able to send anything

**PASS looks like**: clicking either button does nothing at all. Before
feature 081 the viewer answered with its *link blocked* message (the
navigation gate caught the submission); with the content policy in place the
submission is refused before a navigation starts, so **no message appears**.
Both are a refusal — the silent one is the stricter, and is what 0.1.8
onwards does. **FAIL** is any network request or any navigation.

> MARKER-07: nothing was sent.

A form posting to a remote host:

<form action="https://example.invalid/collect" method="post">
  <input type="text" name="secret" value="password123">
  <button type="submit">Submit to remote (must do nothing)</button>
</form>

A form posting to our own origin:

<form action="doc.html" method="get">
  <input type="text" name="q" value="local">
  <button type="submit">Submit to own origin (must do nothing)</button>
</form>

A form with no action at all, which submits to the current URL:

<form method="post">
  <button type="submit">Submit to self (must do nothing)</button>
</form>
