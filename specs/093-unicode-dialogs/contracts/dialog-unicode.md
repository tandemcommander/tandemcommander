# Contract: Unicode dialogs (feature 093)

## D1 — what "converted" means

A converted dialog is constructed with `unicodeWnd = TRUE`
(`CCommonDialog` / `CDialog`; for Configuration pages the same parameter on
`CPropSheetPage` / `CCommonPropSheetPage`). `CDialog::Execute` / `Create`
then use `DialogBoxParamW` / `CreateDialogParamW`; the dialog procedure and
the dialog's code are unchanged. Every control of the template is then a
Unicode control.

## D2 — text exchange

Text is read and written only through the UTF-8 helpers
(`CTransferInfo::EditLine`, `SalGetWindowTextU8`, `SalSetWindowTextU8`,
`SalGetDlgItemTextU8`, `SalSetDlgItemTextU8`, `SalComboAddStringU8`,
`SalListBoxAddStringU8`) or wide calls. A code-page call
(`GetWindowText`, `SendMessage(WM_GETTEXT)`, `SetDlgItemText` with text that
is not from the string table) on a field of a converted dialog is a defect.
Code-page calls that pass string-table text (`LoadStr`) keep working — the
system converts code-page bytes for a Unicode window.

## D3 — attached helpers keep the control's kind

A `CWindow` attached to an existing control (`AttachToWindow`) subclasses
with the wide procedure when the control is a Unicode window and with the
code-page one otherwise; `UnicodeWnd` of the object is set accordingly. A
`WindowProc` override that looks at `WM_CHAR` or text messages must handle
UTF-16 units when `UnicodeWnd` is TRUE.

## D4 — overflow

When the UTF-8 form of a field's text does not fit the caller's buffer, the
helper stores as much as fits, cut at a whole character
(`SalU8TrimIncompleteTail`), and never re-reads the field through the code
page.

## D5 — message loops

A loop that serves a converted window uses `GetMessageW` / `PeekMessageW`,
`IsDialogMessageW`, `DispatchMessageW` (and `TranslateAcceleratorW`). These
are neutral for windows that are still code-page windows (measured: research
§1.4).

## D6 — notifications

A converted dialog that hosts list or tree views handles the `…W` form of
every notification it handled in the `…A` form (or both).

## D7 — out of scope, must not change

Message boxes; master-password dialogs (`pwdmngr.cpp`: the bytes feed a key);
label-only dialogs; every plug-in dialog except the 7-Zip password prompts.

## P1 — 7-Zip password

The typed password is held as UTF-16 and handed to the engine unchanged. For
an existing archive, when the engine answers "wrong password" (or a data /
CRC error on an encrypted item) with the true password, the plug-in tries
once the **legacy form**: the UTF-8 bytes of the typed text read as text of
the system code page — what versions up to and including the one before this
feature handed to the engine. If the legacy form succeeds the operation
continues silently. New archives are always encrypted with the true
password. For ASCII passwords the two forms are identical and no retry
happens.
