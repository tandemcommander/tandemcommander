# Research - 298-mask-group-long-mask

## R1 Refuse or size the storage?

- **Decision**: size the work storage to the group text (heap, `strlen(group) + 1` per buffer).
- **Rationale**: the item allows both; sizing keeps every mask whole (never cut), keeps a configuration that
  worked working, refuses nothing new, adds no UI string. A refusal would turn a plug-in's thumbnail masks or a
  tab filter that a settings import delivered into a silently empty or `*.*` group (the callers' fallbacks).
- **Alternatives**: refuse a mask > 259 bytes with an error position (rejected: changes behaviour for valid
  input; callers such as `CPlugins::Load` and `CPanelTab` activation then fall back to an empty / `*.*` group).

## R2 Is `strlen + 1` always enough?

- **Decision**: yes, for both steps.
- **Rationale**: the cut copies bytes of the group text and drops one `;` of each `;;` - never more bytes than
  the rest of the text. `PrepareMask` skips leading spaces, drops a `*` that follows `*`, rewrites `*?` as `?*`
  (one output byte per consumed `?`: the previous `*` becomes `?`, then `*` is appended) and trims trailing
  spaces - output length <= input length. saltests assert both bounds with guard bytes.

## R3 Where does the rule live?

- **Decision**: header-only `src/common/salmaskgroup.h`, used by `src/masks.cpp`; saltests include it.
- **Rationale**: standing rule "pure decisions into a header under `src/common/` with saltests"; feature 283
  did the same for the classification (`salmaskopt.h`).

## R4 Character signedness

- **Decision**: the rule compares bytes as `unsigned char`.
- **Rationale**: the core is compiled with `/J` (`src/vcxproj/sal_base.props`), so `*s > 31` and `*mask <= ' '`
  are unsigned comparisons today - UTF-8 bytes (>= 0x80) are mask characters, not separators or spaces. The
  explicit cast gives the same result in any project, including saltests.

## R5 Callers (enumerated)

70 call sites of `PrepareMasks` / `PrepareMask` (Grep). None depends on the stack buffers; all go through
`CMaskGroup::PrepareMasks` or `::PrepareMask`. Plug-ins call `SalamanderGeneral->PrepareMask(buf, src)` with
their own buffers - the contract (buffer holds `strlen(src) + 1`) is unchanged. `CSalamanderMaskGroup`
(`src/zip.cpp`) forwards to `CMaskGroup::PrepareMasks`.
