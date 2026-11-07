<!--
SPDX-FileCopyrightText: 2026 Pavel Stupka
SPDX-License-Identifier: GPL-2.0-or-later
-->

# Implementation Plan: FTP per-server encoding flag

## Design

### Data flow

```text
server dialog ──▶ server list ──▶ connection
      │                               │
      └────── encoding flag ─────────▶ name conversion
```
