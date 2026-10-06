# Contract: user interface

**Feature**: 123-new-version-check. English texts are the source; the eight
enabled languages follow through the translation pipeline. `%s` placeholders
are versions or dates produced by the program, never text from the network.

## 1. Notification window (`IDD_UPDATENOTICE`)

Modeless, owned by the main window, caption + close button, not resizable,
centred on the main window. `DIALOGEX`, `DS_SHELLFONT`, `FONT 8, "MS Shell
Dlg"`; standard themed buttons and check box; `CHyperLink` for the link.

```text
┌─ Tandem Commander ────────────────────────────────────────────── ✕ ─┐
│                                                         ┌──────────┐│
│   TANDEM COMMANDER  (wordmark, as in About)             │  brand   ││
│                                                         │ artwork  ││
│   A new version is available                            │          ││
│                                                         └──────────┘│
│▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂ accent line blue → orange ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂│
│                                                                     │
│        0.1.8      →      0.1.9                                      │
│      installed          available                                   │
│                                                                     │
│   Released 14 October 2026                                          │
│   Release notes                                                     │
│                                                                     │
│   The download opens in your web browser. Run the installer to      │
│   update; your settings are kept.                                   │
│                                                                     │
│ ☑ Check for a new version at start-up                               │
│                                                                     │
│        [ Download ]   [ Remind Me Later ]   [ Skip This Version ]   │
└─────────────────────────────────────────────────────────────────────┘
```

**Visual rules**

- Header band: painted background as in the About dialog (white, or navy in
  the dark theme), the GDI wordmark, the brand artwork at the right edge, the
  accent line below. Same helpers, same colours (`TC_COLOR_*`).
- "A new version is available": bold, about 1.4× the dialog font.
- The two version numbers: bold, about 2× the dialog font; the available one
  in the brand orange, the installed one in the muted text colour; captions
  under them in the muted colour. The arrow is drawn, not a character that
  depends on the font.
- Body area uses the normal dialog background and text colours, light and
  dark as the rest of the program's dialogs.
- Sizes derive from the dialog font and the window's DPI; nothing is a fixed
  pixel value. Texts may be up to 40 % longer than English without clipping
  (measured against the longest translation in the probe).

**Controls and keyboard**

| Control | Text | Access key | Action |
|---|---|---|---|
| Default button | Download | D | open the installer address; close |
| Button | Remind Me Later | L | close |
| Button | Skip This Version | S | store the skipped version; close |
| Link | Release notes | (Tab stop, Enter/Space) | open the release-notes address |
| Check box | Check for a new version at start-up | C | write the option at once |

- Enter = Download; Esc and the close button = Remind Me Later.
- Tab order: Download, Remind Me Later, Skip This Version, check box, link.
- Every control has a readable name for screen readers; the two version
  numbers are real static texts, each directly preceded by its label static
  ("Installed version", "0.1.8", "Available version", "0.1.9"), not painted
  pixels. A version too long for its place in the large face is shown in a
  smaller one, never cut.
- Enter on the focused *Release notes* link opens the release notes (not the
  default button).
- If the browser cannot be started: a message with the address asks whether
  to copy it to the clipboard (Yes / No); the notification stays open.
- The date is written in the user's regional format, without the day of the
  week, whatever the language of the user interface.
- A check on demand that finds another version than the open notification
  announces replaces that window.

**Showing (start-up result)**

1. Never while the main window is disabled (another modal window), while any
   other dialog or message box of the main thread is on screen, or while a
   menu, a drag or a move/size of a window is in progress — retry every
   second until it can be shown or the program closes.
2. Never if another instance already shows a notification.
3. Activated only when the main window is the foreground window, the command
   line is empty and there was no keyboard or mouse input for 2 seconds;
   otherwise shown without activation, above the main window: it then takes
   neither the activation nor the keyboard focus (the dialog's initialisation
   declines the default focus).
4. A manual check always activates it (or brings an existing one, also
   another instance's, to the front).
5. Closing the main window, or an installer's close request, destroys it
   without a question.

## 2. Help menu

```text
Help
  Check for New Version
  About Tandem Commander
```

`CM_HELP_CHECKVERSION`; shown at every skill level (as About). Czech:
*Zkontrolovat novou verzi*.

## 3. Manual check: wait and answers

- Wait dialog `IDD_UPDATECHECKING` (modal, appears only if the check takes
  longer than 500 ms): "Checking for a new version..." + **Cancel**. Esc
  cancels. The dialog gives up by itself after 15 s (the request's own limit
  is 12 s).
- Answers (house message box, title "Check for New Version"):

| Result | Icon | Text |
|---|---|---|
| up to date | information | "Tandem Commander %s is the latest version." |
| not reached | warning | "Could not check for a new version: the release server could not be reached." + a second paragraph "Check your internet connection and try again." |
| refused | warning | "Could not check for a new version: the release server refused the request." + a second paragraph "Too many requests may have come from your network. Try again in an hour." |
| unexpected | warning | "Could not check for a new version: the release server gave an unexpected answer. Try again later, or visit tandemcommander.org." |
| newer | — | the notification window |

A cancelled check shows nothing.

## 4. About dialog

One line under the version (`IDC_ABOUT_UPDATE`), with an inline link:

| Known state | Line |
|---|---|
| newer | "Version %s is available. **Download**" |
| up to date | "This is the latest version (checked %s)." |
| not checked | "Not checked for a new version. **Check now**" |

- *Download* opens the installer address. *Check now* runs the manual check
  (the About dialog stays open and its line updates with the result).
- The line uses the About dialog's text colours; the link uses the house
  hyperlink colour.
- Opening the dialog sends nothing.

## 5. Configuration → General

Check box below *Keep environment variables updated to system values*:

`[x] Check for a new version of Tandem Commander at start-up`

Applied on OK, written to the stored state at once. No restart needed.

## 6. Strings that must not be translated or altered

The product name, version numbers, and the two addresses. The Czech name of
the menu command is fixed by the specification (FR-028).
