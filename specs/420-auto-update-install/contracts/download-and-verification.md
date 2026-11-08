# Contract - download and verification (feature 420)

## D1 When a download starts

`SalUpdAfterCheck` returns *download* only when all hold:
level 1 or 2; the check option on or test mode; the installation is eligible (R5); the connection
is not metered; the record has `HasAsset`, `HasDigest` and `0 < AssetSize <= 64 MiB`.
Otherwise *notify* (123's notification). A verified installer of that version already in the
updates folder is reused (no download) - except in test mode, whose start deletes all installers.

## D2 The requests

- First request: `GET https://api.github.com/repos/tandemcommander/tandemcommander/releases/assets/<id>`;
  headers `Accept: application/octet-stream` and the fixed `User-Agent: TandemCommander-update`;
  WinHTTP async, TLS 1.2+, no cookies, no authentication, **redirects not followed by WinHTTP**.
- 301 / 302 / 303 / 307 / 308 with a `Location` header (at most 4096 characters): the target must
  pass `SalUpdRedirectAllowed` - scheme `https`, host exactly `release-assets.githubusercontent.com`
  or `objects.githubusercontent.com` (ASCII, case-insensitive), no user info, no explicit port other
  than 443, no fragment; the next request is a GET of that address with the same restrictions and
  no `Accept` override. At most 3 redirects.
- 200: the body is the installer. `Content-Length`, when present, must equal the record's size.
  Bytes beyond the record's size fail the download. Any other status fails it.
- Bounds: 30 s without progress on any step, 15 minutes in total; cancel (program exit) abandons it
  within milliseconds; the exit waits at most 1.5 s for the worker (123's rule).

## D3 Writing

`.part` created new (`CREATE_ALWAYS`, no sharing), hashed (SHA-256) as written; complete when the
byte count equals the record's size and the hash equals the digest; then closed, flushed and
renamed (replace) to the installer's name. Any failure deletes the `.part`.

## D4 Verification (`UpdInstall_VerifyInstaller`) - before offering, arming and running

Open the file `GENERIC_READ`, share `FILE_SHARE_READ` only (no writer, no delete while held), then:

1. size <= 64 MiB, SHA-256 == expected digest;
2. `WinVerifyTrust` on that handle: `WINTRUST_ACTION_GENERIC_VERIFY_V2`, `WTD_UI_NONE`,
   `WTD_REVOKE_NONE`, `WTD_CACHE_ONLY_URL_RETRIEVAL`, `WTD_STATEACTION_VERIFY` -> 0;
3. the signer certificate (`WTHelperProvDataFromStateData` -> signer 0 -> its certificate) SHA-1
   thumbprint == `SALUPD_SIGNER_THUMBPRINT` (20 bytes; guarded by `tools/check_update_pin.py`
   against `tools/codesign/codesign.cfg` on every build);
4. version resource: first translation; `ProductName` (trailing spaces removed) == `Tandem Commander`,
   `ProductVersion` (trailing spaces removed) parses as `<a>.<b>.<c>` and equals the announced
   version.

Result `suvOk` or the first failure (`suvIo`, `suvSize`, `suvHash`, `suvUnsigned`, `suvSigner`,
`suvVersion`); a failure deletes the file (after the handle is closed). For a launch the handle stays
open until the process is created.
