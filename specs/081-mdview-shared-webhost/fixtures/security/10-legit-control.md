# 10 — The legitimate control document

Everything on this page **must render**. It is the counter-test to the nine
hostile files: the content policy the Markdown Viewer gained in feature 081
must not cost a single legitimate element. This is also the document used for
the pixel comparison against the pre-migration build, so please do not edit it
without re-running that check.

> MARKER-10: if you can read this with a green square, a magenta square, a
> table, coloured code and styled boxes below, the policy blocks nothing.

## Inline styles (the policy allows `style-src 'self' 'unsafe-inline'`)

<style>
.tc081-box { border: 2px solid #2ea043; padding: 10px; border-radius: 6px; }
.tc081-em  { color: #c02ea0; font-weight: bold; }
</style>

<div class="tc081-box">A box styled by an inline <code>&lt;style&gt;</code> element — it must have a green border and rounded corners.</div>

<p style="background:#f0f0f0;padding:6px;border-left:4px solid #888">A paragraph styled by a <code>style=</code> attribute — grey background, left bar.</p>

<span class="tc081-em">Magenta bold text from the stylesheet class.</span>

## Images

A local image from this folder — a **green** 32×32 square:

![green dot](assets/dot.png)

The same kind of image as a `data:` URI — a **magenta** 32×32 square
(the policy allows `img-src 'self' data:`):

![magenta dot](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKklEQVR42u3NQQkAAAgEsEtkZqMYzRQ+hMH+y1SfikAgEAgEAoFAIPgSLEHKOFuOA+zCAAAAAElFTkSuQmCC)

An image with a title, which renders as a tooltip:

![green dot with title](assets/dot.png "The tooltip of the green dot")

## A table with column alignment

| Left | Centre | Right |
|:-----|:------:|------:|
| a | b | c |
| longer cell | mid | 42 |
| x | y | 3.14159 |

## A fenced code block with a language

```c
#include <stdio.h>

/* Highlighting must colour the keyword, the string and the comment. */
int main(void)
{
    const char* greeting = "Tandem Commander";
    for (int i = 0; i < 3; i++)
        printf("%s %d\n", greeting, i);
    return 0;
}
```

An indented code block, and inline `code` in a sentence.

    plain indented code
    second line

## Embedded HTML that Markdown has no syntax for

Press <kbd>Ctrl</kbd>+<kbd>F</kbd> to search. Water is H<sub>2</sub>O and the
area is r<sup>2</sup>π. <mark>Marked text.</mark> <abbr title="Tandem
Commander">TC</abbr> and <del>struck</del> <ins>inserted</ins>.

<details>
<summary>A collapsed section — click to open it</summary>

Hidden content that appears when the summary is clicked. This works without
any script, so it must work here too.

</details>

## Lists, quotes and rules

1. First
2. Second
   - nested bullet
   - another, with **bold** and *italic*
3. Third

- [x] a checked task
- [ ] an unchecked task

> A block quote,
> over two lines.

---

## Links of every kind (row A6 of the checklist)

- [An anchor inside this document](#images) — must scroll to *Images*
- [A local Markdown file](10b-linked.md) — must open a **new viewer window**
- [A local text file](notes.txt) — must show its resolved path only, and launch nothing
- [A remote page](https://example.org/) — must open in the system browser
- [A mail address](mailto:someone@example.org) — must open the mail handler
- [An FTP link](ftp://example.invalid/pub/) — must be refused with *link blocked*

## A long paragraph, for the reading measure

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

Accented text for the encoding check: příliš žluťoučký kůň úpěl ďábelské ódy —
Ärger, Grüße, œuvre, ñandú, Ω≈ç√∫.
