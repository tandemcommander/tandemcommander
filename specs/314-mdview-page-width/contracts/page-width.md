# Contract - MDView page width (feature 314)

Plug-in internal; no plug-in interface, no shared-host change.

## Generator (`src/plugins/mdview/htmlgen.h`)

- `enum MdPageWidth { MDPW_NORMAL = 0, MDPW_WIDE = 1, MDPW_WIDER = 2, MDPW_FULL = 3, MDPW_COUNT = 4 };`
- `int MdPageWidthFromStored(unsigned v)` - `v` if `v < MDPW_COUNT`, else `MDPW_NORMAL`.
- `MdRenderHtml(..., bool allowRemote = false, int pageWidth = MDPW_NORMAL, const MdRenderLimits& lim = ...)`
  and `MdBuildSourceHtml(..., const std::wstring& findTerm = L"", int pageWidth = MDPW_NORMAL)`:
  the article tag is `<article class="markdown-body">` for Normal (byte-identical to before) and
  `<article class="markdown-body wide|wider|full">` for the other levels; an out-of-range
  `pageWidth` is treated as Normal.
- `MdBuildThemeCss` keeps `.markdown-body{max-width:46rem;margin:0 auto;padding:24px 28px 64px;}`
  and carries `.markdown-body.wide{max-width:64rem;}.markdown-body.wider{max-width:90rem;}`
  `.markdown-body.full{max-width:none;}`.

## Viewer

- View menu: `Color Scheme >`, `Page Width >` (radio items 220-223), separator, zoom items, ...
- The checked item is the window's `PageWidth`.
- `WM_COMMAND` 220-223: as data-model.md *Transition*.

## Configuration

- `PageWidth` REG_DWORD written by `SaveConfiguration`, read by `LoadConfiguration` through
  `MdPageWidthFromStored`.
