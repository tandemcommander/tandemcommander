# Data model: 087

No new persisted data except the plugin configuration version.

| Entity | Fields that matter | Rules |
|---|---|---|
| Engine | version 26.03; formats {7z, Rar, Rar5}; codecs as `contracts/engine-build.md` E2 | format list asserted = 3 |
| Archive item (from the engine) | `kpidPath` (UTF-16), `kpidIsDir`, `kpidSize`, `kpidPackSize`, `kpidAttrib`, `kpidMTime/CTime/ATime`, `kpidEncrypted`, `kpidMethod`, `kpidIsAltStream`, `kpidSymLink`, `kpidHardLink` | alt-stream items not listed; links extracted as data, never created |
| Cleaned name | UTF-8 relative path, components without `..`, `:`, forbidden characters, reserved device names | `contracts/item-names.md` N1; idempotent |
| Volume set | first part + siblings named by the handler (`x.partN.rar`, `x.rar` + `x.rNN`) | located in the first part's folder only |
| Plugin configuration | `ConfigVersion` 3 → 4 (registry, plugin key) | migration step `< 4` adds RAR registration once |
| Password (session) | UTF-16, per opened archive | never persisted; wiped on close |
