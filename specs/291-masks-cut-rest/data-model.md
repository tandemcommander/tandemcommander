# Data model - 291-masks-cut-rest

No stored value changes size or place.

| Value | Buffer | Stored in | Fits when |
|---|---|---|---|
| Recycle Bin masks | `Configuration.RecycleMasks` (read `MAX_PATH`) | registry `Configuration` | UTF-8 <= 259 bytes |
| Viewer text / hex masks | `Configuration.TextModeMasks` / `HexModeMasks` | registry | <= 259 bytes |
| Compare ignore files / dirs masks | `Configuration.CompareIgnoreFilesMasks` / `...DirsMasks` | registry | <= 259 bytes |
| Find Named | `CFindOptionsItem::NamedText[NAMED_TEXT_LEN = 260]`, Named history | registry (options, history) | <= 259 bytes |
| View name | `CViewTemplate::Name[VIEW_NAME_MAX = 30]` | registry `Views` | <= 29 bytes (after trimming spaces) |
