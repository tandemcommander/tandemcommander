// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the feature records and the release page against fixture repositories:
 * - the feature list (closed by `FEATURE-HISTORY.md`, items naming the feature), one feature
 *   (files, task progress, `[NNN]` commits, history entry) and one file of it;
 * - a file outside the feature's listing - path traversal in any spelling - is `404`;
 * - while a run holds the run lock everything is read from `main`'s git objects;
 * - the release page: the unreleased changelog section, release blockers, local tags, ahead and
 *   behind as last fetched (an unreachable remote is never contacted), the release records.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { Hono } from "hono";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { featureRoutes } from "../src/api/features.ts";
import { errorAnswer } from "../src/api/common.ts";
import {
  featureMentions,
  historyEntries,
  taskProgress,
  type FeatureRecord,
  type FeatureSummary,
} from "../src/features/records.ts";
import { markdownSection, type ReleaseView } from "../src/features/release.ts";
import { fixtureRepo, gitIn } from "./helpers/fixture-repo.ts";
import { testApp, type TestApp } from "./helpers/services.ts";

/**
 * Writes a file of the fixture repository, creating its folders.
 *
 * @param root - The repository root.
 * @param path - Path relative to the root, `/`-separated.
 * @param text - The content.
 */
function put(root: string, path: string, text: string): void {
  const target = join(root, ...path.split("/"));
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, text, "utf8");
}

/**
 * The API with only the routes under test (the security gate has its own tests).
 *
 * @param app - The test app.
 * @returns The Hono application.
 */
function featureApi(app: TestApp): Hono {
  const api = new Hono().basePath("/api");
  api.onError((error, c) => errorAnswer(error, c));
  api.route("/", featureRoutes(app.services));
  return api;
}

/**
 * Calls a route with GET.
 *
 * @param api - The application.
 * @param path - The address.
 * @returns Status and parsed body.
 */
async function get(api: Hono, path: string): Promise<{ status: number; json: unknown }> {
  const response = await api.request(path);
  const text = await response.text();
  return { status: response.status, json: text ? (JSON.parse(text) as unknown) : null };
}

describe("pure helpers", () => {
  it("splits FEATURE-HISTORY.md into entries", () => {
    const entries = historyEntries(
      "﻿# History\n\n## Feature notes\n\n- 100-old: first\n  continued\n  - a nested point\n- 243-example: second\n\nA paragraph.\n",
    );
    expect(entries.get("100")).toBe("- 100-old: first\n  continued\n  - a nested point");
    expect(entries.get("243")).toBe("- 243-example: second");
  });

  it("finds the features an item names, and not dates", () => {
    const mentions = featureMentions([
      {
        kind: "item",
        slug: "a",
        title: "A",
        type: "bug",
        status: "open",
        severity: 1,
        area: "x",
        source: "review:101",
        who: "agent",
        created: "2026-10-01",
        updated: "2026-10-02",
        verified: null,
        effort: "-",
        feature: "102",
        related: [],
        dependsOn: [],
        reason: null,
        position: 1,
        body: "See specs/103-thing/, feature 104, [105] and 106-some-name; dated 2026-10-17.",
      },
    ]);
    expect([...mentions.keys()].sort()).toEqual(["101", "102", "103", "104", "105", "106"]);
  });

  it("counts task checkboxes", () => {
    expect(taskProgress("- [x] a\n- [ ] b\n  - [X] c\n")).toEqual({ done: 2, total: 3 });
    expect(taskProgress("no tasks")).toBeNull();
  });

  it("cuts a Markdown section at the next heading of its level, ignoring fenced headings", () => {
    const section = markdownSection(
      "# T\n\n## [Unreleased]\n\n### Added\n\n```\n## not\n```\n\n## [1.0]\n",
      (h) => /unreleased/i.test(h),
    );
    expect(section?.heading).toBe("[Unreleased]");
    expect(section?.body).toBe("### Added\n\n```\n## not\n```");
  });
});

describe("feature records", () => {
  let app: TestApp;
  let api: Hono;
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    put(root, "specs/243-example/spec.md", "# Spec 243\n");
    put(root, "specs/243-example/tasks.md", "- [x] T001 a\n- [ ] T002 b\n- [X] T003 c\n");
    put(root, "specs/243-example/contracts/api.md", "# Contract ěščř\n");
    put(root, "specs/243-example/probe/run.txt", "PASS\n");
    put(root, "specs/244-other/spec.md", "# Spec 244\n");
    put(root, "specs/FEATURE-HISTORY.md", "# History\n\n- 243-example: did the example.\n  Second line.\n");
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "[243] the example records"]);
    put(root, "specs/244-other/plan.md", "# Plan\n");
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "other work, mentions [243] in passing"]);
    app = await testApp(root);
    api = featureApi(app);
  });

  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
  });

  it("lists the features, newest first, closed by the history, with the items naming them", async () => {
    const { status, json } = await get(api, "/api/features");
    expect(status).toBe(200);
    const features = (json as { features: FeatureSummary[] }).features;
    expect(features.map((f) => f.number)).toEqual(["244", "243"]);
    expect(features[1]).toMatchObject({ number: "243", name: "example", closed: true });
    // The fixture's in-progress item carries `feature: 243`.
    expect(features[1]!.items).toContain("archive-pack-refuses-a-long-folder-silently");
    expect(features[0]).toMatchObject({ number: "244", closed: false, items: [] });
    const filtered = (await get(api, "/api/features?q=oth")).json as { features: FeatureSummary[] };
    expect(filtered.features.map((f) => f.number)).toEqual(["244"]);
  });

  it("shows one feature with files, task progress, its commits and its history entry", async () => {
    const { status, json } = await get(api, "/api/features/243");
    expect(status).toBe(200);
    const feature = json as FeatureRecord;
    expect(feature.ref).toBe("worktree");
    expect(feature.files.slice(0, 2)).toEqual(["spec.md", "tasks.md"]);
    expect(feature.files).toEqual(expect.arrayContaining(["README.md", "contracts/api.md", "probe/run.txt"]));
    expect(feature.tasks).toEqual({ done: 2, total: 3 });
    expect(feature.commits.map((c) => c.subject)).toEqual(["[243] the example records"]);
    expect(feature.history).toBe("- 243-example: did the example.\n  Second line.");
  });

  it("serves a file of the feature's listing", async () => {
    const { status, json } = await get(api, "/api/features/243/files/contracts/api.md");
    expect(status).toBe(200);
    expect(json).toMatchObject({ path: "contracts/api.md", text: "# Contract ěščř\n", binary: false });
  });

  it("refuses paths outside the listing and malformed numbers with 404", async () => {
    for (const path of [
      "/api/features/243/files/..%2F..%2Fbacklog%2FBACKLOG.md",
      "/api/features/243/files/..%5C..%5Cbacklog%5CBACKLOG.md",
      "/api/features/243/files/contracts%2F..%2F..%2F244-other%2Fspec.md",
      "/api/features/243/files/C:%5CWindows%5Cwin.ini",
      "/api/features/243/files/missing.md",
      "/api/features/243/files/CONTRACTS/API.MD",
      "/api/features/24x",
      "/api/features/999",
      "/api/features/999/files/spec.md",
    ]) {
      const { status, json } = await get(api, path);
      expect(status, path).toBe(404);
      if (json) expect((json as { error: { code: string } }).error.code, path).toBe("not-found");
    }
  });

  it("reads from main's git objects while a run holds the run lock", async () => {
    put(root, "specs/243-example/uncommitted.md", "# not on main\n");
    writeFileSync(
      join(root, ".git", "tandem-backlog-run.lock"),
      "started: 2026-10-30T10:00:00\nslug: some-item\nbranch: 345-some-item\nhost: test\n",
    );
    await app.refresh();
    expect(app.services.source()).toBe("main");
    const feature = (await get(api, "/api/features/243")).json as FeatureRecord;
    expect(feature.ref).toBe("main");
    expect(feature.files).not.toContain("uncommitted.md");
    expect(feature.tasks).toEqual({ done: 2, total: 3 });
    expect((await get(api, "/api/features/243/files/uncommitted.md")).status).toBe(404);
    expect((await get(api, "/api/features/243/files/tasks.md")).json).toMatchObject({ path: "tasks.md" });
  });
});

describe("release page", () => {
  let app: TestApp;
  let api: Hono;
  let root = "";
  let cleanup = (): void => undefined;

  beforeEach(async () => {
    ({ root, cleanup } = await fixtureRepo());
    put(
      root,
      "CHANGELOG.md",
      "﻿# Changelog\n\nIntro.\n\n## [Unreleased]\n\n### Added\n\n- A thing.\n\n## [0.1.0] — 2026-01-01\n\n- Old.\n",
    );
    put(
      root,
      "backlog/RELEASE.md",
      "# Release procedure\n\n## Release records\n\n| Record | What |\n|---|---|\n| `CHANGELOG.md` | the section |\n\n## Preparing the tree\n\n1. Build.\n",
    );
    await gitIn(root, ["add", "-A"]);
    await gitIn(root, ["commit", "-q", "-m", "changelog and release records"]);
    await gitIn(root, ["tag", "v0.1.0", "HEAD~1"]);
    await gitIn(root, ["tag", "v0.1.10"]);
    await gitIn(root, ["tag", "not-a-release"]);
    // A remote that cannot be reached: anything that fetched would fail or hang.
    await gitIn(root, ["remote", "add", "origin", "http://127.0.0.1:9/unreachable.git"]);
    await gitIn(root, ["update-ref", "refs/remotes/origin/main", "HEAD~1"]);
    app = await testApp(root);
    api = featureApi(app);
  });

  afterEach(async () => {
    await app.services.stopAndDrain();
    cleanup();
  });

  it("shows the unreleased section, blockers, tags, ahead/behind and the records from local data", async () => {
    const started = Date.now();
    const { status, json } = await get(api, "/api/release");
    expect(status).toBe(200);
    expect(Date.now() - started).toBeLessThan(20_000);
    const view = json as ReleaseView;
    expect(view.unreleasedHeading).toBe("[Unreleased]");
    expect(view.unreleased).toBe("### Added\n\n- A thing.");
    expect(view.tags).toEqual(["v0.1.10", "v0.1.0"]);
    expect(view).toMatchObject({ ahead: 1, behind: 0, ref: "worktree" });
    expect(view.records.startsWith("## Release records")).toBe(true);
    expect(view.records).toContain("`CHANGELOG.md`");
    expect(view.records).not.toContain("Preparing");
    expect(view.blockers.map((b) => b.slug)).toContain("release-0-1-10-person-checks");
    for (const blocker of view.blockers) {
      expect(["Person steps", "Decisions for the maintainer"]).toContain(blocker.section);
    }
  });

  it("answers without an unreleased section and without a remote branch", async () => {
    put(root, "CHANGELOG.md", "# Changelog\n\n## [0.1.0] — 2026-01-01\n\n- Old.\n");
    await gitIn(root, ["update-ref", "-d", "refs/remotes/origin/main"]);
    const view = (await get(api, "/api/release")).json as ReleaseView;
    expect(view).toMatchObject({ unreleasedHeading: null, unreleased: "", ahead: null, behind: null });
  });
});
