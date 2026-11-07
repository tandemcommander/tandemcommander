state: not-sent

Thank you for the suggestion - it is implemented for the next release (feature 408).

Every code block in the Markdown Viewer now has a **Copy** control in its top-right
corner. It appears when you move the mouse over the block (or reach it with Tab), and a
click (or Enter) puts the block's code on the clipboard exactly as it is written in the
Markdown file - without the highlighting, with its line breaks and its tabs. A small
notice at the bottom right of the viewer shows "Copied" and the first lines that were
copied.

The viewer still runs no scripts (that is how it keeps Markdown files from the internet
harmless), so the control works without JavaScript: the viewer itself does the copying.

Limits: the control is on Markdown code blocks (fenced or indented), not on `<pre>`
elements written as raw HTML inside the document, and not in View Source mode.
