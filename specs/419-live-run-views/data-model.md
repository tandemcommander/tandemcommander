# Data model: 419-live-run-views

No stored data changes. The state of the page:

| Name | Where | Values | Rule |
|---|---|---|---|
| View | the address, `?view=` on `/live` and `/runs/$id` | `overview`, `story`, `critical`, `decisions`, `gallery`, `architecture`, `files`, `documents`, `trace`, `chat` | empty, unknown or unavailable → `overview` (`viewFromAddress`); `chat` is available only for a live run of an item |
| Available views | computed in `RunDashboard` | the ten above, `chat` only when `live && run.slug !== null` | `availableViews(live, hasItem)` |
| Chat signature | reported by `ChatPanel` | `"<turns>:<last state>:<answered 0/1>"`, `""` before the conversation loads | `chatSignature(turns)` |
| Seen chat signature | `RunDashboard` state | a signature or `null` (nothing reported yet) | set to the current signature on the first report and whenever Chat is shown |
| Chat mark | computed | true / false | `chatMark(seen, current, chatShown)` = `!chatShown && seen !== null && current !== "" && current !== seen` |

Removed: the localStorage key `backlog-app.live.chat` (the chat column's open / closed state, 415). An old value
stays in the browser and is not read.
