# Data model - 391-regedt-link-loop

## Walk chain (`CRegWalkChain`, regedt)

- Entries: identities (internal key names such as `\REGISTRY\USER\<SID>\Software\X`), heap copies, at
  most `SAL_REGKEYID_MAX` units each (never cut).
- The walk's starting key contributes all its identities (root identities, both HKCR halves, the opened
  handle's own), best effort; each key below it exactly one (its opened handle's).
- Lifecycle: pushed when a key is entered (after it is opened and found not to lead back), popped when
  the walk leaves the key (every return path). One chain per Copy of one selected key; one per Find
  starting key / root.

## Rule (`SalRegKeyIdLeadsBack`, salregkeyid.h)

- Input: the chain entries, a newly opened key's identity.
- TRUE when an entry lies within the identity (the identity is that entry or a key above it, whole
  elements, case ignored). Empty identity or entries never match.
