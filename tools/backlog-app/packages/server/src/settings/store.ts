// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The maintainer's settings and saved views (data-model *Settings*, *Saved view*), kept in
 * the app's state folder outside the tracked tree.
 *
 * Built-in views are named filters every maintainer needs (analysis A4 §2.3); they cannot be
 * deleted. User views are stored in `views.json`.
 */

import { z } from "zod";
import {
  ApiError,
  SavedViewSchema,
  SettingsSchema,
  type SavedView,
  type Settings,
} from "@backlog-app/shared";
import type { StateDir } from "./state-dir.ts";

/** The built-in views (not deletable). */
export const BUILT_IN_VIEWS: readonly SavedView[] = [
  { name: "Next up", url: "/backlog/next", pinned: true, builtIn: true },
  { name: "Blocked", url: "/backlog/all?q=is%3Ablocked", pinned: true, builtIn: true },
  {
    name: "Agent-doable small",
    url: "/backlog/next?q=who%3Aagent%2Cboth+effort%3AS",
    pinned: true,
    builtIn: true,
  },
  { name: "Severity 7+", url: "/backlog/all?q=sev%3E%3D7", pinned: true, builtIn: true },
  { name: "GitHub items", url: "/backlog/all?q=is%3Agithub", pinned: false, builtIn: true },
  { name: "Not verified", url: "/backlog/next?q=verified%3Anone", pinned: false, builtIn: true },
];

/** The stored list of user views. */
const ViewsFileSchema = z.array(SavedViewSchema);

/** Access to settings and views. */
export class SettingsStore {
  /** The state folder. */
  private readonly state: StateDir;

  /**
   * Creates the store.
   *
   * @param state - The app's state folder.
   */
  constructor(state: StateDir) {
    this.state = state;
  }

  /**
   * The settings (defaults for anything missing).
   *
   * @returns The settings.
   */
  settings(): Settings {
    return this.state.readJson("settings.json", SettingsSchema, SettingsSchema.parse({}));
  }

  /**
   * Replaces the settings.
   *
   * @param next - The new settings (validated by the caller).
   * @returns The stored settings.
   */
  saveSettings(next: Settings): Settings {
    const valid = SettingsSchema.parse(next);
    this.state.writeJson("settings.json", valid);
    return valid;
  }

  /**
   * Changes some settings.
   *
   * @param patch - The fields to change.
   * @returns The stored settings.
   */
  updateSettings(patch: Partial<Settings>): Settings {
    return this.saveSettings({ ...this.settings(), ...patch });
  }

  /**
   * Every view: the built-in ones, then the user's.
   *
   * @returns The views.
   */
  views(): SavedView[] {
    return [...BUILT_IN_VIEWS, ...this.state.readJson("views.json", ViewsFileSchema, [])];
  }

  /**
   * Adds or replaces a user view.
   *
   * @param view - The view.
   * @returns All views.
   * @throws ApiError `refused` when the name is a built-in view's.
   */
  saveView(view: SavedView): SavedView[] {
    if (BUILT_IN_VIEWS.some((v) => v.name === view.name)) {
      throw new ApiError("refused", `'${view.name}' is a built-in view`);
    }
    const own = this.state.readJson("views.json", ViewsFileSchema, []).filter((v) => v.name !== view.name);
    own.push({ ...view, builtIn: false });
    this.state.writeJson("views.json", own);
    return this.views();
  }

  /**
   * Deletes a user view.
   *
   * @param name - Its name.
   * @returns All views.
   * @throws ApiError `refused` for a built-in view, `not-found` for an unknown one.
   */
  deleteView(name: string): SavedView[] {
    if (BUILT_IN_VIEWS.some((v) => v.name === name))
      throw new ApiError("refused", `'${name}' is a built-in view`);
    const own = this.state.readJson("views.json", ViewsFileSchema, []);
    if (!own.some((v) => v.name === name)) throw new ApiError("not-found", `no view '${name}'`);
    this.state.writeJson(
      "views.json",
      own.filter((v) => v.name !== name),
    );
    return this.views();
  }
}
