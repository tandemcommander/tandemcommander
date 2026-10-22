# Data model - 314

## Page width level

| Value | Name (menu) | Article class | Column limit | Command id | String id |
|---|---|---|---|---|---|
| 0 | Normal (default) | `markdown-body` | 46rem | 220 | 2028 |
| 1 | Wide | `markdown-body wide` | 64rem | 221 | 2029 |
| 2 | Wider | `markdown-body wider` | 90rem | 222 | 2016 |
| 3 | Full Window | `markdown-body full` | none | 223 | 2017 |

Submenu title: string 2027 "Page &Width".

- Stored: `PageWidth` (REG_DWORD) in the plug-in's configuration key, beside `ZoomPercent`.
- Reading: missing -> 0; not 0-3 -> 0 (`MdPageWidthFromStored`).
- State: `g_pageWidth` (stored, used by windows opened later); `CViewerWindow::PageWidth`
  (the page of that window; checked item of its menu).
- Transition: menu choice `i` != current -> both set to `i`, the window's page rebuilt;
  `i` == current -> nothing.
