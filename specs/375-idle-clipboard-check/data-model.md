# Data model - 375-idle-clipboard-check

In-memory state of the main window's idle clipboard check (nothing stored).

| Name | Meaning | Changes |
|---|---|---|
| `IdleCheckClipboard` (existing) | the next idle runs the clipboard check | set by 19 triggers and by the retry timer; cleared by the check |
| `IdleClipCheckIsRetry` (new) | the pending request came from the retry timer | set by the timer handler; read and cleared by the check |
| `IdleClipCheckRetries` (new) | looks done in the current series | `SalClipCheckNextLook`: reset to 0 by a free clipboard or a non-retry check; +1 per scheduled look; max `SAL_CLIPCHECK_MAX_RETRIES` (10) |
| `IdleClipCheckRetryPending` (new) | the timer `IDT_CLIPCHECKRETRY` is set | set when a look is scheduled; cleared when it fires or a check ends the series |

State transitions: see [contracts/idle-clipboard-check.md](contracts/idle-clipboard-check.md).
