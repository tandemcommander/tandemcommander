# Feature Specification: FTP anonymous login — a placeholder that belongs to nobody

**Feature Branch**: `090-ftp-anonymous-default`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 7, defect **F9** left open by feature 085: the FTP plug-in's default e-mail for anonymous logins, `name@someserver.com`, is sent to every anonymous server; nobody asked for it.

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision.

- Q: What is wrong with the placeholder, given that it is not the user's data? → A: **`someserver.com` is an ordinary registrable domain** — the program hands a third party's address to every anonymous FTP server on the user's behalf. A placeholder must use a name reserved for that purpose.
- Q: What replaces it? → A: **`anonymous@example.com`** — `example.com` is reserved for documentation (RFC 2606) and can never be anybody's mailbox. Sending *something* stays: anonymous FTP servers conventionally ask for an e-mail address as the password and some refuse an empty one.
- Q: What happens to the stored old placeholder? → A: **It is replaced once it is read**, but only when it is exactly the old placeholder — an address the user typed is never touched.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — An anonymous login no longer names a third party (Priority: P1)

A user connects to a public FTP server anonymously without ever having opened the FTP configuration. The server receives `anonymous@example.com` as the password, not an address at a real domain.

**Independent Test**: on a configuration that never had the value set, and on one that stores the old placeholder, the value the plug-in uses and shows in *Configuration ▸ FTP ▸ Password for anonymous connections* is `anonymous@example.com`.

**Acceptance Scenarios**:

1. **Given** a new installation, **When** the FTP configuration is opened, **Then** the anonymous password field shows `anonymous@example.com`.
2. **Given** a configuration that stores `name@someserver.com`, **When** the plug-in loads it, **Then** the value becomes `anonymous@example.com` and is stored so at the next save.
3. **Given** a configuration that stores an address the user typed, **When** the plug-in loads it, **Then** it is unchanged.
4. **Given** the user empties the field, **Then** it stays empty (their choice).

### Edge Cases

- The stored value differs from the old placeholder only in case (`Name@SomeServer.com`): treated as the old placeholder (nobody types that as their own address).
- A value with surrounding spaces or any other difference: kept as the user's own.
- Bookmarks that store their own password for the `anonymous` user are not affected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The default e-mail address sent as the password of an anonymous FTP login MUST use a domain reserved for documentation; it MUST be `anonymous@example.com`.
- **FR-002**: A stored value equal to the old placeholder (ignoring case) MUST be replaced by the new default when the configuration is read; any other stored value MUST be kept exactly.
- **FR-003**: `PRIVACY.md` MUST name the new placeholder in the same change; the changelog MUST record it.
- **FR-004**: Nothing else in the FTP plug-in's behaviour changes; the plug-in interface and the product version stay.

## Success Criteria *(mandatory)*

- **SC-001**: With no user-set value, **100 %** of anonymous logins send `anonymous@example.com`.
- **SC-002**: **0** user-typed addresses are changed by the update.
- **SC-003**: The old placeholder is **never sent and never shown as a default**; it remains in the program only as the constant by which a stored old value is recognised, and in the documents that describe the change.

## Assumptions

- Anonymous FTP servers accept any syntactically plausible address (the convention of RFC 1635); `example.com` addresses are widely used for this (for example by curl).
