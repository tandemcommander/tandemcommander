# Contract: `PrivacyUrl` in the winget manifests

Source requirements: spec FR-002, FR-010; research R1–R3.

## W1 — Field and value

`tools/winget/templates/locale.en-US.yaml.in` gains, directly after
`PublisherSupportUrl` (the field order of the schema's defaultLocale
documentation, 1.10.0):

```yaml
PrivacyUrl: https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md
```

- Literal value, no placeholder: the address must not change between releases
  (same pattern as `LicenseUrl` and the Changelog `DocumentUrl`).
- The template's authoring comment block records why the field exists
  (moderator requests for credential-storing packages, 072 REMAINING-WORK § P0
  item 3; this feature) and that the target must stay truthful (C8 of the
  statement contract).

## W2 — Generation

- `publish.ps1` needs no change: the value has no `{{…}}` placeholder and the
  line is not a comment, so rendering copies it unchanged.
- The rendered locale manifest for a released version passes
  `winget validate`.

## W3 — Reachability

Before the field is used in any submission, an unauthenticated
`GET https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md`
returns HTTP 200. This is only true after the feature is merged to `main` and
pushed; the template change and the document therefore land in the same
merge.

## W4 — Out of scope

This feature does not push to microsoft/winget-pkgs#426090 and does not
submit a new version. `tools/winget/manifests/<version>/` directories that
are committed as records of past submissions are not regenerated.
