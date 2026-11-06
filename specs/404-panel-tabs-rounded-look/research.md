# Research - 404 panel tabs, variant F

## R1 Anti-aliased shapes without GDI+

- **Decision**: rasterize each shape with the vendored nanosvg (`nsvgParse` of a one-path SVG
  string, `nsvgRasterize` with a translation to the shape's bounding box) into one reusable 32-bit
  top-down DIB section owned by the strip, using a white fill so that every channel is the
  coverage; convert the box to premultiplied BGRA of the wanted colour and `AlphaBlend` it onto
  `ItemBitmap`.
- **Rationale**: nanosvg is already linked into the core (`svg.cpp`); its rasterizer writes
  premultiplied RGBA (the unpremultiply step is commented out in the vendored copy - JRYFIXME at
  `nanosvgrast.h`), and its byte order is R,G,B,A, which `AlphaBlend` would read as B,G,R,A - a
  white fill makes the order irrelevant and the colour is applied by our own code.
- **Alternatives**: GDI+ (not in the core, the item forbids it); hand-written coverage rasterizer
  (more code, no gain); `CSVGSprite` resources (fixed glyphs only, no runtime shapes like the
  active tab whose width changes).
- Coordinates: GDI+ with `PixelOffsetMode.HighQuality` and nanosvg both treat pixel *i* as the
  square [i, i+1], so the mockup's float coordinates are used unchanged. Expected difference: the
  sampling (nanosvg: 5 vertical sub-samples, exact horizontal coverage) - edge pixels may differ by
  a shade (spec clarification: at most 64 per channel, edges only).

## R2 Icons without blocking

- **Decision**: the icon is chosen by a location kind (drive root, UNC root, folder, archive,
  plug-in FS). The kind of a tab that was shown is taken from the panel's own type at capture time
  (`Is(ptDisk)`, `Is(ptZIPArchive)`, `Is(ptPluginFS)`); a restored, never-shown tab derives it from
  the text once (`SalTabLocationKind`: `X:\` -> drive root, `\\server\share` -> UNC root,
  `fsname:...` with a known plug-in FS name -> plug-in FS, else folder - an archive inside a
  not-yet-shown tab shows the folder icon until the tab is first shown; no disk access).
- Icons: folder = `SimpleIconLists[ICONSIZE_16]->GetIcon(symbolsDirectory)` (the panel's own folder
  icon); archive = `LoadArchiveIcon` (the directory line's); drive = `GetDriveIcon(root, type,
  TRUE)` (the directory line's / drive bar's) with the drive type from `GetDriveType` of the letter
  root only (a local lookup, no I/O on the share); removable -> the generic removable id (no shell
  call on the medium); UNC root -> the network drive icon; plug-in FS -> the plug-in's Change Drive
  menu icon (`PluginIcons`, `ChDrvMenuFSItemIconIndex`, kept by the core, no plug-in call), else
  `IDI_PLUGINFS`.
- Cached as HICONs in the strip (per kind, per drive type, per plug-in index); dropped on colour,
  font and DPI changes.
- **Alternatives**: `SHGetFileInfo` per tab (may block on network paths); the icon reader thread
  (panel items only, needs a listing).

## R3 Esc during a drag

- **Decision**: `GetAsyncKeyState(VK_ESCAPE) & 0x8000` checked on every tick of the drag timer
  (spec clarification 2).
- **Alternatives**: hooking the panel's key handling while `Dragging` (the strip captures the mouse
  but the focus stays in the list box; a hook touches `filesbox.cpp`'s key path for one gesture).

## R4 Animation

- **Decision**: `SetTimer` 16 ms on the strip; ease-out `1 - (1 - t)^3` over 150 ms per offset
  change; the timer stops when no offset moves and no drag is live; `SystemParametersInfo
  (SPI_GETCLIENTAREAANIMATION)` FALSE -> offsets are set to their targets at once.

## R5 Capture for the probe

- **Decision**: the probe calls `PrintWindow(strip, dc, PW_CLIENTONLY)`; the strip handles
  `WM_PRINTCLIENT` by painting into the given DC (harmless for the product, makes the capture
  independent of the desktop composition on the hidden desktop).

## R6 Free ids

- `CM_` 2885-2888 (2885-2889 unused by any id kind in `src/*.rh2`, `*.rh`, `*.h`); strings 14192 and
  14193 (bundle 14192-14207 holds 14195-14207, so no other bundle changes its ordinal - rule 084).
