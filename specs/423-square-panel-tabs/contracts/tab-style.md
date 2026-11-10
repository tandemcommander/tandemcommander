# Contract - the panel tab style (feature 423)

## Stored value

`<configuration root>\Configuration`, value `Panel Tab Style`, REG_DWORD.

- 0 = Square (default), 1 = Rounded. Missing, of another type or another number = Square.
- A number this version does not know is kept in memory and written back unchanged; the value
  changes only when the user picks a style on *Configuration > Appearance*.

## Painted shapes (`CTabWindow::PaintTabBack`)

With tab rectangle `r` (`GetDrawnTabRect`: `r.left .. r.right` inclusive), `T = TextTop()`, `H` the
strip height:

| Shape | Square | Rounded (404; the hover pill 1 px taller) |
|---|---|---|
| active tab | the rectangle `x r.left .. r.right`, `y T .. H - 1`, colour `CapBk`; nothing outside it | nanosvg path with top corners and outward feet of radius 6 x scale |
| hover (inactive tab, dragged tab) | the rounded pill's box without its corners: `x r.left + 3 .. r.right - 3`, `y 4 .. H - 3` (scaled insets 3 left, 2 right, 4 top, 2 bottom; it never joins the directory line, review 2; the maintainer asked for Rounded's insets and 1 px more at the bottom, 2026-11-10), colour `HoverBk` | the pill: x inset 3 / 2, y from 4 to H - 2 (404 ended at H - 3; 1 px taller since the maintainer's follow-up, 2026-11-10), radius 5 x scale |
| separators, icon, title, close glyph (with its round hover circle), + (with its circle), list button | unchanged | unchanged |
| tab positions (`TABSTRIP_LEFT`, widths) | unchanged | unchanged |

## Strip colours

Light theme: `DimText` (inactive titles, the + glyph) = `SalTabMix(text, StripBk, 0.20)`
(default colours: 2C2C2C on DEDEDE, 10.38:1). Dark and High Contrast unchanged.

## The page

*Configuration > Appearance*: group *Tab style* directly below *Icon style*, two auto radio
buttons side by side: *Square* (`IDC_TABSTYLE_SQUARE`) and *Rounded* (`IDC_TABSTYLE_ROUNDED`),
group box `IDC_TABSTYLE_GROUP`. OK applies it to both strips without a restart; Cancel changes
nothing. *Icon style* moves up into the old *Thumbnails* row; the bottom row holds *Tab style* (left)
and *Thumbnails* (right), so the page keeps its 299 x 231 du; *Panel Font* is unchanged.
