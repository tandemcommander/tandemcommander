# Data model - 359-uniso-udf-vat-cut

## VAT search window (in `CUDF::ReadSupportingTables`, case `mapVirtual`)

| Field | Meaning |
|---|---|
| `vatLoc` | the partition sector read next (32-bit) |
| `lastVatLoc` | the window's end (exclusive) |
| `fallbackTaken` (new) | the fallback to the file's last sectors was taken |

States: *claimed-end window* `[PD.Length - ExtentOffset - 7, + 14)` -> on a failed read either *fallback
window* `[max(n - 7, 0), n)` (once, by `SalIsoUdfVatFallback`) or *read error* (end, `VatMissing`). From the
fallback window a failed read always ends in *read error*. A found VAT ends the search (`ERR_OK`); a window
read to its end without a VAT ends with "Missing virtual allocation table." (358).
