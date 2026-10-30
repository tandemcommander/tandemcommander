// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Applies the colour theme before the first paint (research R3).
 *
 * It runs synchronously in `<head>`, before the stylesheet and the application load, so the page
 * never flashes in the wrong theme. The choice (`system`, `light`, `dark`) is kept in the
 * browser's storage by `src/lib/theme.ts`; `system` follows the operating system's setting, also
 * when it changes while the page is open. Storage can be unavailable (private window, blocked
 * site data): then the system setting applies.
 */

(function applyStoredTheme() {
  /** The stored choice, or `system`. */
  var choice = "system";
  try {
    choice = window.localStorage.getItem("backlog-app.theme") || "system";
  } catch {
    choice = "system";
  }
  /** The system's dark-mode query. */
  var query = window.matchMedia("(prefers-color-scheme: dark)");
  /**
   * Sets or clears the `dark` class on the root element.
   */
  function apply() {
    var dark = choice === "dark" || (choice === "system" && query.matches);
    document.documentElement.classList.toggle("dark", dark);
    document.documentElement.style.colorScheme = dark ? "dark" : "light";
  }
  apply();
  query.addEventListener("change", function onSystemThemeChange() {
    try {
      choice = window.localStorage.getItem("backlog-app.theme") || "system";
    } catch {
      choice = "system";
    }
    apply();
  });
})();
