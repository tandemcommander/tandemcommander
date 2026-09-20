# 03 — `javascript:` links must be refused

**PASS looks like**: clicking either link shows the viewer's *link blocked*
message box and the document stays as it is. **FAIL** is the document turning
into `PWNED`, or the link opening anything.

> MARKER-03: the document is unchanged.

A Markdown link with a script scheme:

[Markdown javascript link](javascript:document.body.innerHTML='<h1>PWNED</h1>')

The same as raw HTML:

<a href="javascript:document.body.innerHTML='&lt;h1&gt;PWNED&lt;/h1&gt;'">Raw HTML javascript link</a>

A scheme the viewer must also refuse (feature 021 FR-034 allows only
http, https and mailto):

[ftp link](ftp://example.invalid/pub/file.bin)

[file link](file:///C:/Windows/win.ini)

[vbscript link](vbscript:MsgBox"PWNED")

[data link](data:text/html,<h1>PWNED</h1>)
