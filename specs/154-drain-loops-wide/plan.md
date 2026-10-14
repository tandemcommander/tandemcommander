# Plan: 154 - wide drain loops

**Spec**: [spec.md](spec.md) · **Log**: [fix-log.md](fix-log.md)

Nine loops (`dialogs.cpp`, `dialogs6.cpp`, `mainwnd2.cpp`, `mainwnd3.cpp` x2, `pack3.cpp`,
`regwork.cpp`, `zip.cpp`, `viewer2.cpp`) take `PeekMessageW` / `GetMessageW` /
`DispatchMessageW` / `IsDialogMessageW` / `TranslateAcceleratorW`, as 093 did for the thread main
loops. Not touched, each with its reason in fix-log.md: discard-only loops, single private
messages, help mode, the tooltip's modal loop, the wait-window thread, the menus.

Constitution I-VI: no dependency, no interface/string/registry change, a mechanical step of an
established pattern, Windows API only, plug-ins unchanged, UI unchanged. PASS.
