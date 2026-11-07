// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Regression tests of the fourth review of feature 415: a probe's "0 FAIL" is no failure;
 * a note saying "block" or a `git merge-base` moves no phase; the Bash `'\''` escape, a PowerShell
 * string ending in a backslash, comments and assigned texts are read right; a commit chained with
 * backlog steps is a commit; MUST wording; planned-failure words.
 */

import { describe, expect, it } from "vitest";
import { checkSubjects, programsOf } from "../src/runs/command-parse.ts";
import { classifyCommand, judgeChecks, mustFinding, RunStory } from "../src/runs/run-story.ts";
import { call, eventsOf, result, say } from "./helpers/trace.ts";

/**
 * Folds lines into a story.
 *
 * @param lines - Trace lines.
 * @returns The story.
 */
function story(lines: object[]): RunStory {
  const s = new RunStory("item");
  for (const e of eventsOf(lines)) s.apply(e);
  return s;
}

/** Lines that bring a run into its implement phase. */
const IMPLEMENTING = [call("k0", "Skill", { skill: "speckit-implement" })];

describe("review 4 of 415", () => {
  it("M1: counts no failure in a probe's summary of 0 FAIL", () => {
    for (const out of [
      "SHORT DRIVE PASS\nLONG DRIVE PASS\nRESULT: 2 row(s), 0 FAIL",
      "row A PASS\nTOTAL: 42 PASS / 0 FAIL",
      "Rows: PASS 29, FAIL 0, NOT DRIVEN 1",
    ])
      expect(judgeChecks(["probe:x"], out, false).outcome, out).toBe("ok");
    expect(judgeChecks(["probe:x"], "row A PASS\nrow B FAIL\nrow C FAIL", true)).toMatchObject({
      outcome: "fail",
      note: "2 FAIL, 1 PASS",
    });
    expect(judgeChecks(["probe:x"], "RESULT: 3 row(s), 1 FAIL", true).note).toBe("1 FAIL, 0 PASS");
  });

  it("M2, M3: a note saying block or a git merge-base moves no phase", () => {
    const s = story([
      call("a", "Bash", { command: "bin/backlog.sh lock acquire --slug x" }),
      call("b", "Bash", { command: "bin/backlog.sh verify x --note 'a heap work block sized 64 KB'" }),
      call("c", "Bash", { command: "bin/backlog.sh log x 'defects block a strict scan'" }),
      call("d", "Bash", { command: "git merge-base main HEAD" }),
      call("e", "Bash", { command: 'git log --grep "git merge" -1' }),
    ]);
    expect(s.state.phase).toBe("measure");
    expect(s.critical()).toHaveLength(0);
    const stopped = story([call("a", "Bash", { command: "bin/backlog.sh block x --reason 'waits'" })]);
    expect(stopped.state.phase).toBe("stopped");
    const merged = story([...IMPLEMENTING, call("m", "Bash", { command: "git merge --ff-only 415-x" })]);
    expect(merged.state.phase).toBe("merge");
  });

  it("S1 - S4: reads escapes, PowerShell paths, comments and assigned texts", () => {
    expect(checkSubjects("git commit -m 'it'\\''s done; saltests 1 / 0'")).toEqual([]);
    expect(classifyCommand("git commit -m 'NRG image'\\''s tracks\nsaltests 28,304 / 0'").label).toBe(
      "COMMIT",
    );
    expect(programsOf('$env:OPENSAL_BUILD_DIR = "$env:TEMP\\x\\"; .\\build.cmd')).toContain("build.cmd");
    expect(
      programsOf('Copy-Item a "$sp\\probe\\"; powershell -File tools\\run_on_hidden_desktop.ps1 -Log x'),
    ).toContain("run_on_hidden_desktop.ps1");
    expect(programsOf("# don't forget\n./build.cmd")).toContain("build.cmd");
    expect(classifyCommand("ls # ; ./build.cmd").label).toBe("SHELL");
    expect(classifyCommand('$m = "a; .\\build.cmd"; Write-Output $m').label).toBe("SHELL");
    expect(classifyCommand('$o = & "build\\x\\saltests.exe"').label).toBe("TEST");
    // Bash keeps its escaped quotes inside double quotes.
    expect(programsOf('echo "say \\"hi\\"; ok" && ./build.cmd')).toEqual(["echo", "build.cmd"]);
  });

  it("S6: a commit chained with backlog steps is a commit; a new item stays a new item", () => {
    expect(
      classifyCommand("git add -A && git commit -q -m '[415] x' && bin/backlog.sh lock release --slug x")
        .label,
    ).toBe("COMMIT");
    expect(
      classifyCommand("bin/backlog.sh new --title 'A' --type bug && git commit -q -m 'backlog: add'").label,
    ).toBe("BACKLOG");
  });

  it("S7: MUST counts and fixed-at-once wording", () => {
    expect(mustFinding("Review 2: 1 MUST, 2 SHOULD.")).toBe(true);
    expect(mustFinding("the review 1 MUST is fixed")).toBe(false);
    expect(mustFinding("sectors 16 - 31 must be read")).toBe(false);
    const open = story([
      ...IMPLEMENTING,
      say("Review 2: 1 MUST, 2 SHOULD. S1 is now fixed; M1 next.", { message: "m1" }),
    ]);
    expect(open.critical()).toHaveLength(1);
    const fixed = story([
      ...IMPLEMENTING,
      say("Review 1 found one MUST, which is fixed now.", { message: "m2" }),
    ]);
    expect(fixed.critical()).toHaveLength(0);
  });

  it("review 5: the backlog tool through a variable moves the phases; a real block stops", () => {
    const s = story([
      call("a", "Bash", { command: 'BL="python tools/backlog/backlog.py"; $BL lock acquire --slug x' }),
      call("b", "Bash", { command: "BL='bin/backlog.sh'\n$BL verify x --note 'still there'" }),
      call("c", "Bash", { command: '$BL = "python tools/backlog/backlog.py"; & $BL block x --reason waits' }),
    ]);
    expect(s.state.timeline.map((t) => t.phase)).toEqual(["starting", "selection", "measure", "stopped"]);
    expect(s.critical().map((e) => e.critical)).toContain("The run took the stop path");
    expect(s.view().find((e) => e.tool === "Bash" && e.label === "STOP")).toBeDefined();
    const closed = story([
      call("a", "Bash", {
        command: 'BL="python tools/backlog/backlog.py"; $BL run-log --outcome closed --slug x',
      }),
      call("b", "Bash", { command: 'BL="python tools/backlog/backlog.py"; $BL lock release --slug x' }),
    ]);
    expect(closed.state.phase).toBe("done");
    expect(programsOf('OPENSAL_BUILD_DIR="D:/b" ./build.cmd')).toEqual(["build.cmd"]);
    expect(programsOf("n=${#files[@]}; ./build.cmd")).toEqual(["build.cmd"]);
  });

  it("review 5: a new item among other backlog steps is the new item; rows summaries count", () => {
    const kind = classifyCommand(
      "bin/backlog.sh check | tail -1 && bin/backlog.sh new --title 'A bug' --type bug",
    );
    expect(kind.title).toBe("Adds an item to the backlog: A bug");
    expect(judgeChecks(["probe:x"], "32 rows, 0 FAIL", false).outcome).toBe("ok");
    expect(judgeChecks(["probe:x"], "2 rows / 0 FAIL", false).outcome).toBe("ok");
  });

  it("S5: more planned-failure words", () => {
    for (const description of [
      "Run the probe with main's Release uniso as a control",
      "Run the final probe on main's build",
      "Run the extended probe on the pre-review build",
    ]) {
      const s = story([
        ...IMPLEMENTING,
        call("t1", "Bash", {
          command: "powershell -File tools\\run_on_hidden_desktop.ps1 -CommandLine p.ps1",
          description,
        }),
        result("t1", "Rows: PASS 1, FAIL 6", true),
      ]);
      expect(s.critical(), description).toHaveLength(0);
    }
  });
});
