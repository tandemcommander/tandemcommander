// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the story of a run (feature 415, `contracts/story-rules.md`): every row of the
 * rules table, groups, subagents, attempts, limits, unreadable lines, criticals and their
 * resolution, decisions, and the digest of the chat snapshot.
 */

import { describe, expect, it } from "vitest";
import {
  classifyCommand,
  componentOf,
  firstSentence,
  judgeResult,
  mustFinding,
  relativePath,
  RunStory,
  type StoryEntry,
} from "../src/runs/run-story.ts";
import { attempt, call, eventsOf, result, say, turnEnd } from "./helpers/trace.ts";

/**
 * Folds lines into a story.
 *
 * @param lines - Trace lines.
 * @param kind - Run kind.
 * @returns The story.
 */
function story(lines: object[], kind: "item" | "triage" = "item"): RunStory {
  const s = new RunStory(kind);
  for (const e of eventsOf(lines)) s.apply(e);
  return s;
}

/**
 * The entries without phase lines.
 *
 * @param s - A story.
 * @returns The entries.
 */
function actions(s: RunStory): StoryEntry[] {
  return s.view().filter((e) => e.kind !== "phase");
}

describe("commands", () => {
  it("classifies the commands of a run", () => {
    expect(classifyCommand(".\\build.cmd full").label).toBe("BUILD");
    expect(classifyCommand('& "build\\saltests.exe"').label).toBe("TEST");
    expect(classifyCommand("npm run check").label).toBe("TEST");
    expect(classifyCommand("npx playwright test e2e/x.spec.ts").label).toBe("TEST");
    expect(classifyCommand("powershell -File tools\\run_on_hidden_desktop.ps1 -Log x").label).toBe("PROBE");
    expect(classifyCommand("python tools/check_encoding.py --strict").label).toBe("CHECK");
    expect(classifyCommand("python -m translate.merge --module x").label).toBe("TRANSLATE");
    expect(classifyCommand("git commit -m '[415] tasks' -m 'body'").title).toBe("Commits: [415] tasks");
    expect(classifyCommand("git merge --ff-only 415-x").label).toBe("GIT");
    expect(classifyCommand("bin/backlog.sh verify slug --note 'x'").title).toBe(
      "Records the measurement in the backlog",
    );
    expect(classifyCommand("bin/backlog.sh lock acquire --slug x").title).toBe("Takes the run lock");
    expect(classifyCommand("bin/backlog.sh block x --reason 'y'").label).toBe("STOP");
    const added = classifyCommand("bin/backlog.sh new --title 'A new bug' --type bug");
    expect(added.title).toBe("Adds an item to the backlog: A new bug");
    expect(added.criticalOnOk).toContain("triage");
    expect(classifyCommand("bin/backlog.sh new --title 'Check X' --type person-step").title).toContain(
      "person step",
    );
    expect(classifyCommand("ls -la").title).toBe("Runs `ls -la`");
  });

  it("judges results", () => {
    expect(judgeResult("build", "...\nBUILD SUCCEEDED", false)).toEqual({
      outcome: "ok",
      note: "build succeeded",
    });
    expect(judgeResult("build", "a.cpp(3): error C2065: x", true).outcome).toBe("fail");
    expect(judgeResult("saltests", "saltests: 21,794 checks, 0 failed", false).note).toBe(
      "21,794 checks, 0 failed",
    );
    expect(judgeResult("saltests", "saltests: 10 checks, 2 failed", true).outcome).toBe("fail");
    expect(judgeResult("tests", "Tests  366 passed | 2 skipped", false)).toEqual({
      outcome: "ok",
      note: "366 passed",
    });
    expect(judgeResult("tests", "Tests  1 failed | 365 passed", true).note).toBe("1 failed, 365 passed");
    expect(judgeResult("probe", "Rows: PASS 29, FAIL 0, NOT DRIVEN 1", false)).toEqual({
      outcome: "ok",
      note: "29 PASS",
    });
    expect(judgeResult("probe", "row 1 PASS\nrow 2 FAIL", false).outcome).toBe("fail");
    expect(judgeResult("encoding", "TOTAL: 0 finding(s)", false).outcome).toBe("ok");
    expect(judgeResult("encoding", "TOTAL: 3 finding(s)", true).note).toBe("3 findings");
    expect(judgeResult("commit", "[415-x abc1234] subject", false).note).toBe("abc1234 on 415-x");
    expect(judgeResult("plain", "x", true).outcome).toBe("warn");
  });
});

describe("paths and sentences", () => {
  it("cuts paths to the repository and names components", () => {
    expect(relativePath("E:\\Projects\\tc\\tools\\backlog-app\\packages\\web\\src\\a.tsx")).toBe(
      "tools/backlog-app/packages/web/src/a.tsx",
    );
    expect(relativePath("C:\\Users\\p\\AppData\\Local\\Temp\\rv407\\x.png")).toBe("%TEMP%/rv407/x.png");
    expect(componentOf("tools/backlog-app/packages/web/src/a.tsx")).toBe("backlog-app/web");
    expect(componentOf("src/plugins/ftp/ftp.cpp")).toBe("plugins/ftp");
    expect(componentOf("src/common/salnameorder.h")).toBe("src/common");
    expect(componentOf("specs/415-x/spec.md")).toBe("feature records");
    expect(componentOf("%TEMP%/x.png")).toBe("temporary files");
  });

  it("takes the first sentence of prose, not a heading", () => {
    expect(firstSentence("## Extension Hooks\n\nThe hook ran. Then more.")).toBe("The hook ran.");
    expect(firstSentence("**Done**: all green")).toBe("Done: all green");
  });

  it("finds a reported MUST count only", () => {
    expect(mustFinding("Review 3 has 1 MUST and 1 SHOULD")).toBe(true);
    expect(mustFinding("Review 2 found one MUST: x")).toBe(true);
    expect(mustFinding("Review 6: 0 MUST, 2 SHOULD")).toBe(false);
    expect(mustFinding("The review found no MUST.")).toBe(false);
    expect(mustFinding("Review 2's MUST is fixed.")).toBe(false);
  });
});

describe("RunStory", () => {
  it("tells a call by its description and its result's verdict", () => {
    const s = story([
      call("t1", "Bash", { command: ".\\build.cmd", description: "Build Debug x64" }),
      result("t1", "...\nBUILD SUCCEEDED"),
    ]);
    const [entry] = actions(s);
    expect(entry).toMatchObject({
      label: "BUILD",
      outcome: "ok",
      title: "Build Debug x64 - build succeeded",
    });
    expect(entry?.critical).toBeNull();
  });

  it("makes a failed build critical and resolves it when a later build succeeds", () => {
    let s = story([call("t1", "Bash", { command: "build.cmd" }), result("t1", "BUILD FAILED", true)]);
    expect(s.critical()).toHaveLength(1);
    expect(s.critical()[0]?.critical).toContain("The build failed");
    s = story([
      call("t1", "Bash", { command: "build.cmd" }),
      result("t1", "BUILD FAILED", true),
      call("t2", "Bash", { command: "build.cmd" }),
      result("t2", "BUILD SUCCEEDED"),
    ]);
    expect(s.critical()[0]?.resolved).toBe(true);
  });

  it("does not make a negative control's failure critical", () => {
    const s = story([
      call("t1", "Bash", { command: "npx vitest run x", description: "Run the negative control" }),
      result("t1", "Tests  1 failed", true),
    ]);
    expect(s.critical()).toHaveLength(0);
    expect(actions(s)[0]?.outcome).toBe("warn");
  });

  it("collapses consecutive reads and edits into one line each", () => {
    const s = story([
      call("r1", "Read", { file_path: "E:\\r\\src\\a.cpp" }),
      call("r2", "Grep", { pattern: "Foo" }),
      call("r3", "Read", { file_path: "E:\\r\\src\\b.cpp" }),
      result("r1", "x"),
      call("e1", "Edit", { file_path: "E:\\r\\src\\a.cpp" }),
      call("e2", "Edit", { file_path: "E:\\r\\src\\a.cpp" }),
      result("e1", "ok"),
      result("e2", "ok"),
    ]);
    const [reads, edits] = actions(s);
    expect(reads).toMatchObject({ kind: "group", label: "READ", childCount: 3 });
    expect(reads?.title).toBe("Reads 2 files and searches 1 times: a.cpp, b.cpp");
    expect(edits).toMatchObject({ kind: "group", label: "EDIT", childCount: 2, outcome: "ok" });
    expect(edits?.title).toBe("Edits `a.cpp` (src)");
    expect(s.files()).toEqual([{ path: "E:\\r\\src\\a.cpp", rel: "src/a.cpp", component: "src", edits: 2 }]);
  });

  it("shows a screenshot on its own line and lists it for the gallery", () => {
    const s = story([
      call("r1", "Read", { file_path: "E:\\r\\specs\\415-x\\probe\\shot.png" }),
      result("r1", ""),
    ]);
    const [shot] = actions(s);
    expect(shot).toMatchObject({ label: "SCREENSHOT", title: "Looks at the screenshot shot.png" });
    expect(s.images().map((i) => i.path)).toEqual(["E:\\r\\specs\\415-x\\probe\\shot.png"]);
  });

  it("folds a subagent's work under its agent with its status and report", () => {
    const s = story([
      call("a1", "Agent", {
        description: "Independent refute-first review",
        subagent_type: "general-purpose",
      }),
      call("s1", "Bash", { command: "git diff", description: "Show the diff" }, { parent: "a1" }),
      result("s1", "diff", false, "a1"),
      say("I found nothing wrong.", { parent: "a1" }),
      { type: "system", subtype: "task_progress", tool_use_id: "a1", description: "Running the tests" },
      result("a1", "MUST: none. SHOULD: one."),
    ]);
    const [agent] = actions(s);
    expect(agent).toMatchObject({
      kind: "agent",
      label: "REVIEW",
      outcome: "ok",
      status: "finished",
      childCount: 2,
    });
    expect(agent?.title).toBe("Review agent: Independent refute-first review");
    expect(agent?.children[0]).toMatchObject({ title: "Show the diff", outcome: "ok" });
    expect(agent?.children[1]?.title).toBe("says: I found nothing wrong.");
    expect(agent?.detail).toContain("SHOULD: one.");
    // Subagent calls never become entries of their own.
    expect(actions(s)).toHaveLength(1);
  });

  it("opens phase sections from the run's markers", () => {
    const s = story([
      call("k1", "Bash", { command: "bin/backlog.sh lock acquire --slug x" }),
      call("k2", "Skill", { skill: "speckit-specify" }),
      call("k3", "Skill", { skill: "speckit-plan" }),
    ]);
    const phases = s
      .view()
      .filter((e) => e.kind === "phase")
      .map((e) => e.title);
    expect(phases).toEqual([
      "Choosing and locking the item",
      "Writing the specification",
      "Designing the solution",
    ]);
    expect(actions(s).find((e) => e.tool === "Skill")?.title).toBe("Runs Spec Kit *specify*");
  });

  it("flags decisions, review findings, new items and the stop path", () => {
    const s = story([
      say("I chose the conservative option: keep the old behaviour.", { message: "m1" }),
      call("k1", "Skill", { skill: "speckit-implement" }),
      call("a1", "Agent", { description: "review" }),
      result("a1", "report"),
      say("Review 1 found one MUST: the price is wrong.", { message: "m2" }),
      call("b1", "Bash", { command: "bin/backlog.sh new --title 'Leftover' --type bug" }),
      result("b1", "leftover"),
      call("b2", "Bash", { command: "bin/backlog.sh block slug --reason 'x'" }),
      result("b2", "blocked"),
    ]);
    expect(s.decisions().map((e) => e.title)).toEqual([
      "I chose the conservative option: keep the old behaviour.",
    ]);
    const reasons = s.critical().map((e) => e.critical);
    expect(reasons).toContain("The review reports a MUST finding");
    expect(reasons).toContain("A new item waits for the maintainer's triage");
    expect(reasons).toContain("The run stopped and blocked the item");
    expect(reasons).toContain("The run took the stop path");
  });

  it("tells attempts, limits, error turns and unreadable lines", () => {
    const s = story([
      attempt(1),
      call("t1", "Bash", { command: "sleep 1" }),
      { type: "rate_limit_event", rate_limit_info: { status: "rejected" } },
      attempt(2, "usage-limit"),
      turnEnd(1, { input: 0, output: 0, read: 0, w5: 0, w1: 0 }, true),
    ]);
    const s2 = new RunStory("item");
    for (const e of eventsOf(["{not json"])) s2.apply(e);
    const entries = actions(s);
    expect(entries.find((e) => e.tool === "Bash")).toMatchObject({ outcome: "warn", status: "cut off" });
    expect(entries.find((e) => e.kind === "attempt")?.title).toBe(
      "The run continues after usage-limit (attempt 2)",
    );
    expect(entries.find((e) => e.kind === "limit")?.importance).toBe("critical");
    expect(entries.find((e) => e.kind === "turn")?.critical).toBe("A turn ended with an error");
    expect(actions(s2)[0]).toMatchObject({ kind: "unreadable", label: "ERROR" });
  });

  it("knows what happens now and gives a digest", () => {
    const s = story([
      say("Building now.", { message: "m1" }),
      call("t1", "Bash", { command: "build.cmd", description: "Build the core" }),
    ]);
    expect(s.now()).toMatchObject({ title: "Build the core", running: true, label: "BUILD" });
    expect(s.latestMessage()?.title).toBe("Building now.");
    const digest = s.digest(5);
    expect(digest.at(-1)).toMatch(/BUILD running - Build the core$/);
  });

  it("replaces changed entries instead of mutating them", () => {
    const s = new RunStory("item");
    const events = eventsOf([call("t1", "Bash", { command: "ls" }), result("t1", "x")]);
    s.apply(events[0]!);
    const before = s.view().find((e) => e.tool === "Bash")!;
    s.apply(events[1]!);
    const after = s.view().find((e) => e.tool === "Bash")!;
    expect(after).not.toBe(before);
    expect(before.outcome).toBe("running");
    expect(after.outcome).toBe("ok");
  });

  it("caps the children of a group", () => {
    const lines = Array.from({ length: 250 }, (_, i) =>
      call(`r${i}`, "Read", { file_path: `E:\\r\\src\\f${i}.cpp` }),
    );
    const [group] = actions(story(lines));
    expect(group?.children).toHaveLength(200);
    expect(group?.childCount).toBe(250);
    expect(group?.title).toContain("and 247 more");
  });
});
