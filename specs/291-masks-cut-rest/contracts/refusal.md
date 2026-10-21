# Contract - the refusal of a text that does not fit (291)

Internal behaviour contract (no plug-in interface).

1. A field whose whole UTF-8 (WTF-8) form does not fit its buffer is refused with
   `IDS_TOOLONGPATH` ("The path specified is too long."), before any syntax check, before any use
   and before anything is stored; one message.
2. A dialog / page stays open, the field keeps the whole text and is marked (`ErrorOn`, or
   `WM_NEXTDLGCTL` with the text selected for a command outside `Validate`).
3. A refused Find command (Add Current, Manage, Ignore) does nothing else.
4. A refused view name edit stores nothing; the row keeps its earlier name.
5. No memory to measure = does not fit (fail closed); no memory to keep the Find field whole = the
   option is not loaded.
6. A text that fits behaves exactly as before.
