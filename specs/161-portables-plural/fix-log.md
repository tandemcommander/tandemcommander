# Fix log: 161 - Portables "N selected devices" takes its plural

Backlog: `specs/NEXT-WORK.md` 10c (found by 159's review, upstream).

## Cause (by reading, reproduced with a port)

`IDS_SELECTEDDEVICEFMT` "{!}%d selected device{2:s|0||1|s}": the group names parameter 2, the
call (`wpdfsdevicelevel.cpp`) passes one - `ExpandPluralString` (`salamdr4.cpp`) traces "index out
of range" and ends the text at the brace: always "N selected device". Every translation copied the
English pattern. `probe/plural161.py` is a port of `ExpandPluralString` (the `{n:...}` index is
1-based, a group without one takes the next parameter): the old pattern stops; `probe/result.txt`
lists every language for 0, 1, 2, 5, 21 devices.

## Work

- `src/plugins/portables/lang/lang.rc`: `{s|0||1|s}`.
- `translations/ui-overrides.json` (portables): a pattern per language following its own "N
  selected files" (salamand.slt 12840): cs, sk four forms; de, nl the adjective's ending; fr, ro, es
  two groups (`{1:...}` for the second); hu no plural after a number (an empty group takes the
  parameter, as 12840 does).
- `translate.merge --module portables`: 0 gaps (the pins), only entry 128 changed per language,
  no control re-laid out; `build.cmd full` BUILD SUCCEEDED.

## Review

Independent refute-first review (after the commit): no blocking finding. The port follows
`ExpandPluralString` for everything these patterns use (`{!}`, `N:` index, stop on out of range,
`arg <= num`, the last option as default); it does not unescape or model the 200-byte buffer -
unused here. Grammar of cs, sk, de, nl, es, hu right; the .slt files change entry 128 (and the
VERSION line of a re-export) only; one caller with one parameter.
- Low, accepted: Romanian wants "de" from 20 on ("21 de dispozitive"); the interval syntax cannot
  say 101-119 again and the corpus (10695) does not either.
- Info: 0 is never shown (the caller expands only for a selection), so the French 0 form is moot.

## After

- Owed to a person: Portables in Czech with 1, 2 and 5 devices selected (the information line
  exposes no text to a probe).
