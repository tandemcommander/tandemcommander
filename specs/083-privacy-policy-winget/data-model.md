# Data Model: Privacy Statement for the winget Catalogue

The "data" of this feature is documentation; the entities below structure the
evidence and the document so that every claim can be traced.

## Data surface

One place where the shipped product stores data on the user's computer or
transmits data over a network.

| Field | Description | Rules |
|---|---|---|
| id | short slug, e.g. `sftp-saved-password` | unique |
| component | main app / installer / plugin name / vendor component | one of the scope items |
| kind | `stored` or `transmitted` | |
| data | what exactly (e.g. host, user name, password; directory history) | concrete, no "etc." |
| location_or_recipient | registry key / folder (stored) or who receives it (transmitted) | user-meaningful form + technical form |
| trigger | `always`, `on user action: <action>`, `only if enabled: <setting>` | |
| protection | e.g. AES with master password; obfuscation; none; TLS/SSH | only what evidence shows |
| removal | removed by uninstaller? manual step? | |
| evidence | list of `file:line` / `.iss` section / observation | at least one item |
| statement_section | C2 section number(s) where it is disclosed | at least one |

## Evidence

A reference that establishes one field of a data surface: source location,
installer section, repository setting, or a recorded observation with date.
Evidence is re-checked when the surface's component changes (contract C8).

## Claim

One sentence (or bullet) of `PRIVACY.md` that asserts a fact about the product.

| Field | Rules |
|---|---|
| text | as published |
| surfaces | ≥ 1 data-surface id, **or** marked `attribution` (C6) or `scope` (C5) |
| verdict | `supported` / `overstated` / `false` — set by the independent reviewer |

Validation: publishable only when every claim is `supported` (SC-002, SC-003).

## Privacy statement

| Field | Rules |
|---|---|
| product_version | the released version it describes (e.g. 0.1.8) |
| last_updated | ISO date |
| sections | C2 §1–§11 in order |
| contact | issue tracker; private reporting only when enabled (C7) |

State transitions: `draft` → `reviewed` (all claims supported) → `published`
(on `main`, URL returns 200) → `stale` (a C8 trigger occurred without an
update — must not persist past the triggering change).

## Manifest field

`PrivacyUrl` in the locale template: literal stable URL (W1), valid only once
the statement is `published` (W3).
