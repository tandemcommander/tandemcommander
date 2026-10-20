# Data model - 270-mask-filter-label-fits

No stored value changes size or place. The limits the fields are measured against:

| Value | Buffer | Field limit | Refused when |
|---|---|---|---|
| Selection mask (`MainWindow->SelectionMask`, Select history) | 260 bytes | combo 259 units | UTF-8 > 259 bytes |
| Convert mask (`CConvertFilesDlg::Mask`, Convert history) | 260 bytes | combo 259 units | UTF-8 > 259 bytes |
| Panel filter (`CMaskGroup::MasksString` read with 260, filter history) | 260 bytes read | combo 259 units | UTF-8 > 259 bytes, either radio |
| Volume label (`newName`) | 260 bytes | none (30,000 units) | UTF-8 > 259 bytes |
| Hot path slot name (heap, loaded with `MAX_PATH`) | 260 bytes at load | label edit | slot name >= 260 bytes, at the page's `Validate` |
