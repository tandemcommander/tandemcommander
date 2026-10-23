# Data model - 327-uniso-safe-names

- **Listed name**: one component of a path inside the image (a file, a folder, a volume label folder
  `ISO (<label>)`); UTF-8 bytes in a fixed buffer of its reader. Made safe by `SalArcCleanItemName`
  before it is listed and before it is appended to the reader's descent path.
- **Target name**: the extraction path a reader builds: target folder + the listed name made safe
  once more (`AppendSafeName`).

No stored data, no registry, no plug-in interface change.
