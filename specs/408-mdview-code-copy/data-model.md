# Data model - 408-mdview-code-copy

## MdCopyUi (input of `MdRenderHtml`)

| Field | Meaning |
|---|---|
| `base` (UTF-8) | `https://mdcopy.invalid/<token>-<serial>/`; empty = no controls |
| `label` (UTF-8) | the control's text (*Copy*) |
| `tooltip` (UTF-8) | the control's `title` |

All texts are HTML-escaped by the generator.

## MdHtmlResult.codeBlocks

`std::vector<std::string>`: entry *n* = the UTF-8 source of the *n*-th code block in
document order (md4c code text, unchanged). Filled only when `base` is not empty;
cleared by every render and by `MdBuildSourceHtml`.

## Viewer window state

| Member | Meaning |
|---|---|
| `CopyToken` | 32 lowercase hex digits, made once at window creation; empty when the random generator failed (no controls) |
| `CopySerial` | incremented by every rendered (non-source) rebuild |
| `CopyBase` | the base of the current `Html` (wide), empty when no controls |
| `CopyTip` | the native notice (tracking tooltip), made on the first copy, destroyed with the window |

## Copy address states (`MdParseCopyLink`)

| Result | When | Viewer does |
|---|---|---|
| `MDCOPY_NONE` | not in the `https://mdcopy.invalid/` family | the old link handling |
| `MDCOPY_REFUSED` | in the family, but not `base` + canonical decimal `< count` | nothing |
| `MDCOPY_OK` | exact | copy entry *n*, show the notice on success |
