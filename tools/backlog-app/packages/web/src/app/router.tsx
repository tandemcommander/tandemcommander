// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The routes of the app (analysis A4 §2.2): every view, filter, tab and selection is in the
 * address, so the back button, bookmarks and "copy link" work (FR-009).
 *
 * Code-based TanStack Router routes; pages read their parameters through `getRouteApi`, so this
 * file is the only one that imports every page.
 */

import { createRootRoute, createRoute, createRouter } from "@tanstack/react-router";
import { Layout } from "./layout.tsx";
import { HomePage } from "@/features/home/home-page.tsx";
import { BacklogPage } from "@/features/backlog/backlog-page.tsx";
import { ItemPage } from "@/features/item/item-page.tsx";
import { ClosedPage, ClosedItemPage } from "@/features/closed/closed-page.tsx";
import { CheckPage } from "@/features/check/check-page.tsx";
import { LoopPage } from "@/features/loop/loop-page.tsx";
import { SettingsPage } from "@/features/settings/settings-page.tsx";
import { LivePage } from "@/features/live/live-page.tsx";
import { RunsPage } from "@/features/runs/runs-page.tsx";
import { RunPage } from "@/features/runs/run-page.tsx";
import { TriagePage } from "@/features/triage/triage-page.tsx";
import { NewItemPage } from "@/features/new-item/new-item-page.tsx";
import { FeaturesPage, FeaturePage } from "@/features/features/feature-page.tsx";
import { ReleasePage } from "@/features/release/release-page.tsx";
import { AskPage } from "@/features/ask/ask-page.tsx";

/**
 * Reads a string search parameter.
 *
 * @param value - The raw value.
 * @returns The string, or empty.
 */
function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

/** The root: the layout around every page. */
const rootRoute = createRootRoute({ component: Layout });

/** Home (dashboard). */
const homeRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: HomePage });

/** A backlog section (or `all`) with filter, sort and selection in the search parameters. */
const backlogRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/backlog/$section",
  validateSearch: (search: Record<string, unknown>) => ({ q: text(search["q"]), sel: text(search["sel"]) }),
  component: BacklogPage,
});

/** One item, full page, with its tab. */
const itemRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/items/$slug",
  validateSearch: (search: Record<string, unknown>) => ({ tab: text(search["tab"]) }),
  component: ItemPage,
});

/** The closed-items archive. */
const closedRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/closed",
  validateSearch: (search: Record<string, unknown>) => ({ q: text(search["q"]) }),
  component: ClosedPage,
});

/** One closed item. */
const closedItemRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/closed/$slug",
  component: ClosedItemPage,
});

/** The consistency check. */
const checkRoute = createRoute({ getParentRoute: () => rootRoute, path: "/check", component: CheckPage });

/** The loop: state, control, its log. */
const loopRoute = createRoute({ getParentRoute: () => rootRoute, path: "/loop", component: LoopPage });

/** The live run. */
const liveRoute = createRoute({ getParentRoute: () => rootRoute, path: "/live", component: LivePage });

/** Run history. */
const runsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/runs",
  validateSearch: (search: Record<string, unknown>) => ({
    outcome: text(search["outcome"]),
    q: text(search["q"]),
  }),
  component: RunsPage,
});

/** One run with its transcript. */
const runRoute = createRoute({ getParentRoute: () => rootRoute, path: "/runs/$id", component: RunPage });

/** Inbox triage, optionally at one item. */
const triageRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/triage",
  validateSearch: (search: Record<string, unknown>) => ({ at: text(search["at"]) }),
  component: TriagePage,
});

/** The new-item form, optionally prefilled. */
const newItemRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/new",
  validateSearch: (search: Record<string, unknown>) => ({
    type: text(search["type"]),
    from: text(search["from"]),
  }),
  component: NewItemPage,
});

/** Feature records. */
const featuresRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/features",
  component: FeaturesPage,
});

/** One feature's records. */
const featureRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/features/$nnn",
  validateSearch: (search: Record<string, unknown>) => ({ file: text(search["file"]) }),
  component: FeaturePage,
});

/** Release readiness. */
const releaseRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/release",
  component: ReleasePage,
});

/** Questions about the backlog. */
const askRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/ask",
  validateSearch: (search: Record<string, unknown>) => ({ q: text(search["q"]) }),
  component: AskPage,
});

/** Settings. */
const settingsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/settings",
  component: SettingsPage,
});

/** The route tree. */
const routeTree = rootRoute.addChildren([
  homeRoute,
  backlogRoute,
  itemRoute,
  closedRoute,
  closedItemRoute,
  checkRoute,
  loopRoute,
  liveRoute,
  runsRoute,
  runRoute,
  triageRoute,
  newItemRoute,
  featuresRoute,
  featureRoute,
  releaseRoute,
  askRoute,
  settingsRoute,
]);

/** The router. */
export const router = createRouter({ routeTree, defaultPreload: "intent", scrollRestoration: true });

declare module "@tanstack/react-router" {
  /** Registers the router's types for typed links and parameters. */
  interface Register {
    /** The app's router. */
    router: typeof router;
  }
}
