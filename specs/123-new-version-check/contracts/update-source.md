# Contract: the version request

**Feature**: 123-new-version-check. This is the program's side of the exchange
with GitHub: what it sends and the only things it accepts. `PRIVACY.md` quotes
the host and the identification from here — change them together.

## Request

```text
GET /repos/tandemcommander/tandemcommander/releases/latest HTTP/1.1
Host: api.github.com                      (TLS, port 443)
User-Agent: TandemCommander-updatecheck
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
```

| Rule | Value |
|---|---|
| Scheme | HTTPS only; certificate and host name verified by Windows, no error ignored |
| Identification | the fixed `User-Agent` above; **no version, no identifier of the user, computer or installation** |
| Cookies | none stored, none sent |
| Authentication | never attempted (no answer to a 401/407 challenge with Windows credentials) |
| Redirects | not followed (a redirect is an unexpected answer) |
| Proxy | the system's settings (incl. automatic detection); a proxy that needs sign-in fails the check: its `407` is never answered, the result is `surUnexpected` and the attempt counts as answered |
| Body, query, referrer | none |
| Timeouts | the whole request - from the first step to the last byte of the answer - 12 s, enforced by the program itself; inside it WinHTTP's own phase timeouts (resolve 4 s · connect 4 s · send 2 s · receive 8 s) |
| Cancelling | WinHTTP runs in its asynchronous mode; the worker abandons the request by closing the request handle itself (the documented way). A cancel is announced at once and nothing waits for the worker |
| Frequency | automatic: data-model.md § Limits; manual: on the user's command |

A `User-Agent` is mandatory for this API (a request without one is answered
`403` — measured 2026-10-06).

## Answer → result

| Observed | Result |
|---|---|
| No HTTP status (DNS, connection, TLS, timeout) | `surUnreachable` |
| `403` or `429` | `surRefused` |
| Any other status than `200` (incl. `3xx`, `404`, `5xx`) | `surUnexpected` |
| `200`, body over 256 KB | `surUnexpected` |
| `200`, body shorter than the announced `Content-Length` | `surUnexpected` |
| `200`, the body does not arrive within the deadline, or the connection breaks | `surUnreachable` (the attempt still counts as answered) |
| `200`, body not well-formed JSON object | `surUnexpected` |
| `200`, record fails a rule below | `surUnexpected` |
| `200`, valid record, version > installed | `surNewer` |
| `200`, valid record, version ≤ installed | `surUpToDate` |

The body of a non-`200` answer is not read.

## Fields read

Only these; every other member is skipped (correctly, by the grammar) and
never stored or shown.

| Field | Required value |
|---|---|
| `draft` | `false` |
| `prerelease` | `false` |
| `tag_name` | `v<major>.<minor>.<patch>`, 1–5 digits each, nothing more |
| `published_at` | `YYYY-MM-DDThh:mm:ssZ`, a real date and time |
| `html_url` | exactly `https://github.com/tandemcommander/tandemcommander/releases/tag/v<ver>` |
| `assets[]` | at least one element with `name` = `tandemcommander-<ver>-x64-setup.exe`, `state` = `"uploaded"`, `browser_download_url` = `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe` |

`<ver>` is `<major>.<minor>.<patch>` re-printed from the parsed numbers (so
`v0.01.9` cannot match its own addresses).

Duplicate members: the first occurrence at the top level counts; a second
`tag_name` fails the record.

## What the program opens

Never a string from the answer. From the validated numbers it builds:

- installer: `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe`
- release notes: `https://github.com/tandemcommander/tandemcommander/releases/tag/v<ver>`

and hands them to the default browser (`ShellExecute`, verb `open`).

## Obligations on the release procedure

- The installer asset keeps the name `tandemcommander-<version>-x64-setup.exe`
  (already required by `tools/winget/templates/installer.yaml.in`).
- The tag keeps the form `v<major>.<minor>.<patch>`.
- A release is published with its installer attached. Until the asset is
  there, the release is not offered to anyone.
- A release marked *pre-release* is never offered.

## Debug-only seam

`TC_UPDATECHECK_URL=http://127.0.0.1:<port>/<path>` replaces scheme, host and
path of the request in Debug builds (loopback and plain HTTP only; any other
value is ignored). `TC_UPDATECHECK_PRETEND_VERSION=x.y.z` replaces the
installed version. Neither exists in Release builds. The seam cannot change
the addresses the program opens.
