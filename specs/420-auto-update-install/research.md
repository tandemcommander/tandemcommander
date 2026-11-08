# Research - 420-auto-update-install

Measurements M1-M10 are in `fix-log.md`. Decisions:

## R1 Where the installer comes from

- **Decision**: the GitHub API asset address
  `https://api.github.com/repos/tandemcommander/tandemcommander/releases/assets/<id>` with
  `Accept: application/octet-stream`; `<id>` is the decimal `id` of the asset 123 already validates
  (name, state `uploaded`, `browser_download_url`), and that asset's own `url` must equal the
  constructed address. Redirects are followed by the program itself, only to
  `release-assets.githubusercontent.com` or `objects.githubusercontent.com`, HTTPS, port 443, at
  most 3 hops.
- **Rationale**: M4/M5 - on 2026-11-08 `browser_download_url` answered 504 to every client while
  the API address answered 302 -> `release-assets.githubusercontent.com` -> 200 with the exact
  asset. The API host is the one 123 already talks to; the address is constructed from a validated
  number (123's rule 1).
- **Alternatives**: `browser_download_url` (failed when measured; also redirects to the same
  hosts); following redirects automatically in WinHTTP (no control over the target host).

## R2 Proving the file

- **Decision**: (1) SHA-256 equal to the record's `digest` (`sha256:` + 64 hex digits; a record
  without it is not installed automatically); (2) `WinVerifyTrust` (`WINTRUST_ACTION_GENERIC_VERIFY_V2`,
  no UI, `WTD_REVOKE_NONE`, `WTD_CACHE_ONLY_URL_RETRIEVAL` - no network); (3) the signer
  certificate's SHA-1 thumbprint equal to the pinned `A3D05CCF5CA13EAFF49CC7F64D1832F0E6EF6733`
  (`codesign.cfg`); (4) version resource strings ProductName `Tandem Commander` and ProductVersion
  = the announced version, trailing spaces ignored (M7: Inno pads them; the fixed version is 0.0.0.0).
  The file is opened once without write / delete sharing for the whole verification and kept open
  until the installer process is created.
- **Rationale**: the digest binds the file to the release GitHub serves; the signature and the pin
  bind it to the project's key even if the release itself were tampered with; the version check
  stops a downgrade with an older signed installer. No revocation lookup: it would be new network
  traffic to the CA, and the pin already limits the accepted certificate to one.
- **Certificate rotation**: a program pinned to the old thumbprint offers the browser download
  (today's notification) for an installer signed with a new certificate. Recorded for the
  maintainer: sign one release with the old certificate that already carries the new thumbprint,
  or accept one manual update. The pin is guarded by a build check that compares it with
  `codesign.cfg` (`tools/check_update_pin.py`, run by `saltests`' companion step - see tasks).
- **Alternatives**: subject-name pinning (weaker - any certificate with that name); trusting any
  valid signature (the item forbids it).

## R3 Starting the installer

- **Decision**: `CreateProcessW` (the installer's manifest is `asInvoker` - measured; Inno's loader
  elevates itself for `/ALLUSERS`, which shows the UAC prompt) with
  `/SP- /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG="<updates>\setup-<ver>.log"` + the
  mode switch + `/SILENT /RESTARTAPPLICATIONS` (*Install Now*, start-up completion) or
  `/VERYSILENT /NORESTARTAPPLICATIONS` (exit).
- **Rationale**: Inno documentation (M9): silent setup closes and restarts applications by default;
  at an exit the user closed the program on purpose, so no restart. The update close of 080 / 088 /
  118 is the tested way to close a running program; a declined close gives exit 5 with rollback.
- **At exit**: started as the last statement of `WinMainBody` (M10: the tail of the exit waits more
  than a second for windows and threads; an installer started earlier would find the process alive
  and fail with exit 5). Only when this is the last instance in the session (an exit must not close
  other windows the user still has open).

## R4 Completing at the next start

- **Decision**: an arm stays in the registry until the running version reaches it (cleanup), the
  user skips it, the level stops honouring it, or 3 launches did not get there (dropped, offered
  instead). At start-up an honoured arm that is still newer is installed at once through the
  *Install Now* route. A test-mode arm is completed only in a test-mode session and only when it
  was never launched (a launched same-version install cannot be told from a failed one by version).
- **Rationale**: covers every way the exit can miss the install: no normal exit (crash, kill,
  power loss), sign-out / shutdown / installer close (skipped on purpose), another instance still
  running, the installer failing or being declined.

## R5 Which installation

- **Decision**: read `Software\Microsoft\Windows\CurrentVersion\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1`
  in HKLM (64-bit view) and HKCU; the one whose `InstallLocation` (Inno: trailing backslash) is the
  running program's folder (`SalPathEqualOrdinalCI`) gives `/ALLUSERS` resp. `/CURRENTUSER`. None ->
  not eligible.
- **Rationale**: M8 - a build tree on a machine with an installed copy must not update that copy.

## R6 Metered connections

- **Decision**: `INetworkCostManager::GetCost`; `NLM_CONNECTION_COST_UNRESTRICTED` (or unknown /
  failure) = not metered; anything else = metered -> notify only for the session.

## R7 Test mode

- **Decision**: `--updatetest` in `ParseCommandLineParameters` (global flag, not in the shared
  `CCommandLineParams`); 123's claim and stored state are skipped, classification forced to newer.
  The restart command line is built by `SalRestartCommandLine` from identity values only, so the
  flag cannot travel into a restart.
