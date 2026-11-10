# Contract - the panel tab style (feature 423)

## Stored value

`<configuration root>\Configuration`, value `Panel Tab Style`, REG_DWORD.

- 0 = Square (default), 1 = Rounded. Missing, of another type or another number = Square.
- A number this version does not know is kept in memory and written back unchanged; the value
  changes only when the user picks a style on *Configuration > Appearance*.

## Painted shapes (`CTabWindow::PaintTabBack`)

With tab rectangle `r` (`GetDrawnTabRect`: `r.left .. r.right` inclusive), `T = TextTop()`, `H` the
strip height:

| Shape | Square | Rounded (404, unchanged) |
|---|---|---|
| active tab | the rectangle `x r.left .. r.right`, `y T .. H - 1`, colour `CapBk`; nothing outside it | nanosvg path with top corners and outward feet of radius 6 x scale |
| hover (inactive tab, dragged tab) | the same rectangle, colour `HoverBk` | the pill: inset 3 / 4 / 5 / 7 x scale, radius 5 x scale |
| separators, icon, title, close glyph (with its round hover circle), + (with its circle), list button | unchanged | unchanged |
| tab positions (`TABSTRIP_LEFT`, widths) | unchanged | unchanged |

## Strip colours

Light theme: `DimText` (inactive titles, the + glyph) = `SalTabMix(text, StripBk, 0.20)`
(default colours: 2C2C2C on DEDEDE, 10.38:1). Dark and High Contrast unchanged.

## The page

*Configuration > Appearance*: group *Tab style* directly below *Icon style*, two auto radio
buttons side by side: *Square* (`IDC_TABSTYLE_SQUARE`) and *Rounded* (`IDC_TABSTYLE_ROUNDED`),
group box `IDC_TABSTYLE_GROUP`. OK applies it to both strips without a restart; Cancel changes
nothing. The *Thumbnails* group sits beside *Panel Font* so the page keeps its 299 x 231 du.
