# 08 — Images outside the document's folder must be refused

The viewer serves images only from the numbered table it built for **this**
document, and the generator puts a reference in that table only for a path
that resolves inside the document's own directory (feature 021). Everything
below therefore has to end as a placeholder.

**PASS looks like**: five placeholders (the source text as the tooltip) and
one real green square at the bottom. **FAIL** is any of the five rendering an
image, or the viewer reading a file outside this folder (visible in Process
Monitor if you have it running).

> MARKER-08: nothing outside the folder was read.

Parent-directory traversal:

![traversal](../../secret.png)

Deep traversal to a real system file:

![deep traversal](../../../../../../Windows/win.ini)

An absolute local path:

![absolute](C:\Windows\System32\drivers\etc\hosts)

A UNC path:

![unc](//localhost/C$/Windows/win.ini)

A percent-encoded traversal, which a naive check misses:

![encoded traversal](..%2F..%2Fsecret.png)

A backslash traversal:

![backslash traversal](..\..\secret.png)

And the control — this one **must** render, because it is inside the folder:

![the local dot, which must render](assets/dot.png)
