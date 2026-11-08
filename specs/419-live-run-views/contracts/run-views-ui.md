# Contract: the views of the run dashboard (419)

The end-to-end tests (`us7-live-dashboard`, `us8-live-layout`) and axe read these names. They are the
dashboard's interface. Keep them, or change the tests in the same change.

## Page layout (the live page and the page of a run with a trace)

```
<page root: flex column, fills main, overflow hidden>
  title row:   h1 "Live run" | "Run <id>"   +  section "Run in short" (compact line)
  tablist "Views of the run":  Overview · Story · Critical · Decisions · Gallery · Architecture ·
                               Files · Documents · Raw trace · Chat (live item run only)
  tabpanel of the chosen view: flex-1, min-h-0  (exactly one is visible)
```

## Views

| Tab (accessible name starts with) | `?view=` | Content and names kept from 415 | The view's one vertical scroll area |
|---|---|---|---|
| Overview | `overview` (default) | section *Run progress* (progressbar *Progress of the run (estimate)*, list *Steps of the run*), section *What happens now*, region *Live figures* | the view's box |
| Story | `story` | search *Search the story*, log *The story of the run* | the story list |
| Critical (count) | `critical` | regions *Open*, *Resolved* | the view's box |
| Decisions (count) | `decisions` | regions *Recorded in the specification*, *Said by the agent* | the view's box |
| Gallery (count) | `gallery` | buttons *Open <name>*; the viewer dialog is an overlay | the view's box |
| Architecture | `architecture` | img *The flow of the run*, list *Files by component*, region *Diagrams of the plan* | the view's box |
| Files (count) | `files` | as 415 | the view's box |
| Documents (count) | `documents` | buttons per document, article *<name>* | the view's box |
| Raw trace | `trace` | filter *Filter the transcript*; the event dialog is an overlay | the transcript list |
| Chat (mark *new answer*) | `chat` | region *Chat about the run* (the tab panel), log *The conversation*, group *Ready questions*, textbox *Your message* | the conversation log |

## Rules

- The page root and `main` have nothing to scroll at 1920x1200, 1280x800, 1024x700 and 820x640.
- A visible view holds at most one element that scrolls vertically, and no such element sits inside
  another.
- A chat update changes only the conversation log's `scrollTop`.
- An unknown or unavailable `?view=` opens Overview. A tab change replaces the address (no history entry).
