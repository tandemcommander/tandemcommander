# Data model - 311

No data changes. The values involved keep their sizes:

| Value | Buffer | Stored in |
|---|---|---|
| Find Containing text (`CFindOptionsItem::GrepText`) | `GREP_TEXT_LEN` = 201 bytes UTF-8 | Find history (`FindGrepHistory`), Find options (registry `Find Options\<n>`, value of `FINDOPTIONSITEM_GREP_REG`) |
| Viewer find text (`CFindSetDialog::Text`) | `FIND_TEXT_LEN` = 201 bytes UTF-8 | viewer history (`ViewerHistory`), registry `VIEWER_FINDTEXT_REG` |

Rule: a typed text is accepted only when its whole UTF-8 (WTF-8) form plus NUL fits the buffer;
otherwise it is refused and stays in its field whole.
