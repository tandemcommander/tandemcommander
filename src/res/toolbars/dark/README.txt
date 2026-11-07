Hand-tuned Dark-theme toolbar icon overrides (feature 029)
==========================================================

Files placed in this directory override the automatic dark adaptation of
the standard toolbar glyphs while the Dark theme is active:

  toolbars\dark\<Name>.svg

- <Name> must exactly match the standard glyph's file name in toolbars\
  (the SVGName column of ToolBarButtons[] in src\toolbar4.cpp), e.g.
  Copy.svg, Back.svg, ClipboardCut.svg.
- The override is used VERBATIM (no automatic recoloring) and only while
  the Dark theme is active; the Default theme never reads this directory.
- If an override is missing or unreadable, the app silently falls back to
  the standard SVG with automatic dark adaptation, then to the legacy
  raster glyph. A button can never end up empty because of an override.
- Design against the dark toolbar background RGB(45,45,45)
  (COLOR_BTNFACE in src\common\themes_palette.h); dominant strokes should
  reach at least 3:1 contrast. Keep the motif of the light icon.
- Supported SVG subset = nanosvg (paths, solid fills/strokes; no scripts,
  no external references). Same canvas/viewBox as the standard glyph.

Full contract: specs\029-dark-toolbar-icons\contracts\dark-icon-override.md

Feature 416: this folder belongs to the "Classic" icon set. The default set,
"Fluent 2", has its own standard and dark files in iconsets\fluent\ and
iconsets\fluent\dark\ (source: src\res\iconsets\fluent\, generator
tools\brand\fluent-icons\). An override that cannot be parsed or draws no
shape now really falls back to the standard file. Contract of both sets:
specs\416-fluent-icon-set\contracts\icon-set-files.md
