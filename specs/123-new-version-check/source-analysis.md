# Source of the "latest version" information — measured comparison

**Feature**: 123-new-version-check · **Measured**: 2026-10-06, from the
maintainer's machine, unauthenticated, with `curl` · **Status**: input for
`/speckit-plan` (the plan makes the final choice)

Everything below marked *measured* was observed on that day; anything else is
labelled as documentation or reasoning.

## State of the release publication (measured)

- Nine releases, `v0.1.0` … `v0.1.8`; none is a draft or a pre-release.
- Every release has exactly one asset, `tandemcommander-<version>-x64-setup.exe`.
- Tag form is `v<major>.<minor>.<patch>`; release name equals the tag.
- Release body is Markdown (0.1.8: 3,549 characters, headings `## New`, bold,
  inline code, an em dash and middle dots outside ASCII).
- The API record carries a `digest` for the asset
  (`sha256:5d3759be…` for 0.1.8).
- **The program itself has no HTTP client today.** The core imports no
  `winhttp` / `wininet` / `urlmon` (grep over `src/*.cpp`, `src/common/`);
  only `mdview.spl` uses WinHTTP (`remotefetch.*`, feature 085). The core gains
  its first outbound connection with this feature.

## Candidates

### A. REST API, latest release — `api.github.com/repos/tandemcommander/tandemcommander/releases/latest`

Measured:

- `200`, **7,115 bytes**, 0.28 s. JSON with `tag_name`, `name`, `draft`,
  `prerelease`, `published_at`, `html_url`, `body`, and
  `assets[].browser_download_url` / `size` / `digest`.
- "Latest" already means the newest non-draft, non-pre-release release
  (GitHub documentation), so no filtering of a list is needed.
- **A `User-Agent` header is mandatory**: a request without one gets `403`.
- **Rate limit: 60 requests per hour per public IP address** for
  unauthenticated callers (`X-RateLimit-Limit: 60`, resource `core`), shared
  with every other unauthenticated GitHub API user behind the same address.
- `ETag` and `Last-Modified` are returned and a conditional request
  (`If-None-Match`) is answered `304 Not Modified` — **but it still counts
  against the limit** (`X-RateLimit-Used` went 6 → 7 → 8 over two `304` and one
  `200`). GitHub's documentation exempts `304` only for authenticated requests.
  Conditional requests therefore save bytes, not quota.
- `Cache-Control: public, max-age=60`.
- TLS 1.2 accepted, certificate verifies against the system store.

For: one small answer has everything the notification and the About dialog
need, including the direct installer address and the release text.
Against: the per-address limit (a company behind one address, with many
developers' tools using the same quota, can be at 0); JSON has to be parsed
(no JSON parser in the core today — a small, strict extractor of a few string
fields, or a vendored parser; planning decides); the API's shape is GitHub's.

### B. REST API, list — `…/releases?per_page=100`

Measured: `200`, **77,301 bytes**, 0.30 s; same limit and headers as A.

Only needed if the program had to choose among releases itself (channels,
"newest that has an installer"). Eleven times the data for no benefit now.
**Not recommended** as the primary source.

### C. Web redirect — `github.com/tandemcommander/tandemcommander/releases/latest`

Measured: `302 Found`, **no body** (5 KB of headers), 0.06 s,
`Location: …/releases/tag/v0.1.8`. Not served by the API, so the API rate
limit does not apply (the web front end has its own, undocumented, abuse
limits).

For: the cheapest possible request; the version is in the `Location` header;
nothing to parse but a tag. The installer address can be *derived*
(`…/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe` — the same
pattern the winget template already relies on,
`tools/winget/templates/installer.yaml.in`).
Against: no release date, no release text, no confirmation that the installer
asset exists; it is a web page's behaviour, not a documented contract; the
client must not follow the redirect.

Related, measured: `…/releases/latest/download/<file>` redirects to
`…/releases/download/v0.1.8/<file>`. A fixed-name asset published with every
release (for example a small `latest.json` written by the release workflow)
would make a stable, limit-free, project-defined answer available at a
constant address. It needs a new step in the release procedure and a second
redirect hop to the asset host.

### D. Atom feed — `github.com/…/releases.atom`

Measured: `200`, **65,087 bytes**, 0.50 s, XML with every release's title,
date and HTML-rendered notes; `Cache-Control: private, must-revalidate`.

Largest answer, needs an XML reader, cannot tell pre-releases apart, gives no
asset address. **Not recommended.**

### E. A file on the project's own site — `tandemcommander.org`

Measured: the site answers `200` behind Cloudflare. A static
`version.json` there would be fully under the project's control (format,
caching, no third-party limit, could carry localized highlights).

Against: a second publication to keep in step with every release — exactly the
drift the release procedure tries to avoid — and a second host in the privacy
statement. Worth reconsidering only if GitHub's limits prove to be a problem
in practice.

### F. Windows Package Manager catalogue

Not a source the program can ask cheaply, lags behind the release by the
catalogue's review time, and says nothing to users of the plain installer.
**Not a candidate**; mentioned because winget users are affected (see spec,
Assumptions).

## Comparison

| | A. API latest | B. API list | C. Web redirect | D. Atom | E. Own site |
|---|---|---|---|---|---|
| Answer size | 7 KB | 77 KB | 0 (headers) | 65 KB | tiny |
| Version | yes | yes | yes (tag in header) | yes | yes |
| Release date | yes | yes | no | yes | if written |
| Release text | yes (Markdown) | yes | no | yes (HTML) | if written |
| Installer address | yes (+ SHA-256) | yes | derivable | no | if written |
| Excludes drafts / pre-releases | yes | client must | yes | no | by procedure |
| Request limit | 60 / h per address | same | none documented | none documented | none |
| Parsing | JSON fields | JSON array | one header | XML | own format |
| Extra release step | none | none | none | none | **yes** |
| Documented contract | yes | yes | no | partly | own |

## Recommendation

1. **Primary: A (API, latest release).** It is the only source that fills the
   whole notification — version, date, what is new, installer — from one
   documented request with no extra work at release time.
2. **Stay far inside the limit by design**: the automatic check asks at most
   once in 24 hours per user (spec FR-008), so one user costs one request a
   day; 60 per hour per address then covers a very large shared network. A
   refused request (`403` / `429` with the limit headers) is "could not check",
   silent at start-up.
3. **Fallback worth planning: C (web redirect)** when A is refused or
   unreachable — it still yields the version and a derivable download address,
   enough for a reduced notification ("version X is available", link to the
   release page) without date or summary. Whether the fallback is worth its
   code is a planning decision; the spec does not require it.
4. **Validate rather than trust** (spec FR-004): version must match the tag
   pattern; the addresses offered to the user must start with
   `https://github.com/tandemcommander/tandemcommander/releases/`; the answer
   is size-bounded (the 0.1.8 record is 7 KB — a bound of a few hundred KB is
   generous).
5. **Send as little as possible** (spec FR-006): a fixed `User-Agent` naming
   the product is required by the API. Whether it also carries the installed
   version is a privacy decision — it is not needed for the check and the
   recommendation is **not** to send it. No cookies, no automatic
   authentication (the lesson of feature 085: the old Markdown-viewer fetch
   sent a Windows logon `Authorization` header on a `401` challenge).

## After clarification (2026-10-06)

The clarified spec shows **no release text** in the program (version, release
date, a *Release notes* link and a download of the **installer file**), checks
**once in 24 hours at start-up only**, and makes the first check silently.
Effect on this comparison:

- The `body` field of A is no longer needed, which removes the Markdown
  question entirely; A is still the only source of the **release date** and the
  only one that **confirms the installer asset exists** and gives its exact
  address (the download action now opens that file directly, so a derived
  address that turns out not to exist would be a dead download).
- C (redirect) as a fallback can still drive a reduced notification, but
  without a date and with a derived installer address; if it is used, the
  notification should then lead to the release page instead of the file.
- The release-notes link is the record's `html_url` (validated against the
  official prefix).

## Consequences outside the code (for the plan)

- `PRIVACY.md` — its claim that the program uses the network only as a result
  of something the user does becomes untrue for the default configuration; the
  section *When the program uses the network* gains an entry (host
  `api.github.com`, what is revealed: IP address and the fixed `User-Agent`;
  what is stored: last-check time, last known version, skipped version; how to
  turn it off). Validity line updated. Mandatory in the same change (CLAUDE.md,
  *Key Facts → Privacy statement*).
- Antivirus heuristics (feature 076/077 history): a file manager that makes an
  outbound request seconds after start is a new behaviour for the signed
  binary; worth one scan of the release build before publishing.
- The release procedure gains a rule: **publish the release only when its
  installer asset is attached**, because from this feature on publication is
  what users are notified about (spec FR-002 guards the gap, but the order
  should still be right).
- Translations: new strings in the eight enabled languages through the
  two-stage `.slt` refresh; expect register pins for de/fr/nl/es.
