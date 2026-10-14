# Plan: 152 - PictView's print preview

**Spec**: [spec.md](spec.md) · **Log**: [fix-log.md](fix-log.md)

## Technical context

- `src/plugins/pictview/print.cpp` `CreatePreview` (the preview bitmap), `CPreviewWnd` (its cache,
  `WM_PRINTCLIENT`), `CPrintParams` (`dialogs.h`), the viewer's `CMD_PRINT` (`render1.cpp`).
- The WIC engine (`wicengine.cpp`, feature 006) offers raw output only at the natural size;
  `PVSetStretchParameters` + `PVDrawImage` are what the viewer and the print use.

## Constitution check

I build reproducibility - no new dependency. II backward compatibility - no interface, string,
registry value. III incremental - one function rewritten, two members added. IV Windows - GDI
only. V plugin architecture - inside the plug-in. VI UI consistency - the dialog unchanged. PASS.

## Design

The preview reuses the print's arithmetic: the full picture's size from the preview size and the
selection, the offset of the selection's corner, the stretch signed by the mirror flags XOR a
negative size; drawn into a 32-bit DIB through the engine; the viewer's stretch is handed in
(`DisplayStretchX/Y`, the values the print restores) and set back right after drawing.
