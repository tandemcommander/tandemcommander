<!--
SPDX-FileCopyrightText: 2026 Pavel Stupka
SPDX-License-Identifier: GPL-2.0-or-later
-->

# Feature Specification: FTP per-server encoding flag

## Clarifications

### Session 2026-11-07

- Q: What is the default encoding of a server? → A: UTF-8, as today (autonomous run: conservative)
- Q: Where is the flag shown? → A: in the server's dialog, beside the code page (autonomous run: recommended)

## Assumptions

- Assumption (autonomous run): no new dependency; the flag is stored with the server.
