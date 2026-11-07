// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Tests of the reading of shell commands (feature 415, reviews 2 and 3): the Bash and
 * PowerShell forms the runs really use start a build, saltests, a probe, tests or the encoding
 * guard; a mention in a pattern, a heredoc, a commit message or the arguments of a search does
 * not. The cases are the third review's adversarial set.
 */

import { describe, expect, it } from "vitest";
import { checkSubjects, programsOf } from "../src/runs/command-parse.ts";
import { classifyCommand } from "../src/runs/run-story.ts";

/** Expected label and command. */
const cases: [string, string][] = [
  // [expected label, command]
  ["BUILD", `$o = .\\build.cmd 2>&1; $o | Select-String "BUILD (SUCCEEDED|FAILED)"`],
  ["BUILD", `$o = & E:\\Projects\\tandemcommander\\build.cmd 2>&1`],
  ["BUILD", `& "E:\\Projects\\tandem commander\\build.cmd" full`],
  ["BUILD", `.\\build.cmd`],
  ["BUILD", `cmd /c build.cmd full`],
  ["BUILD", `cmd //c "build.cmd full" 2>&1 | tail -5`],
  ["BUILD", `cmd.exe /c "E:\\Projects\\tandemcommander\\build.cmd"`],
  ["BUILD", `Start-Process -Wait -NoNewWindow -FilePath .\\build.cmd`],
  ["BUILD", `cd /e/Projects/tandemcommander && \\\n  ./build.cmd 2>&1 | tail -3`],
  ["BUILD", `if ($true) { .\\build.cmd }`],
  ["BUILD", `foreach ($m in 'a','b') { .\\build.cmd *> x.txt }`],
  ["BUILD", `(.\\build.cmd 2>&1) | Select-Object -Last 3`],
  ["BUILD", `Measure-Command { .\\build.cmd }`],
  ["BUILD", `powershell -NoProfile -Command ".\\build.cmd; exit $LASTEXITCODE"`],
  ["BUILD", `./build.cmd & echo done`],
  [
    "TEST",
    `$o = & "build\\tandemcommander\\Debug_x64\\saltests\\saltests.exe" 2>&1; $o | Select-Object -Last 1`,
  ],
  ["TEST", `"$OPENSAL_BUILD_DIR/tandemcommander/Debug_x64/saltests/saltests"`],
  ["TEST", `build/tandemcommander/Debug_x64/saltests/saltests | tail -1`],
  [
    "TEST",
    `Start-Process -FilePath "build\\tandemcommander\\Debug_x64\\saltests\\saltests.exe" -NoNewWindow -Wait`,
  ],
  [
    "PROBE",
    `foreach ($l in 'czech','english') { powershell -File tools\\run_on_hidden_desktop.ps1 -Log x -CommandLine "y" }`,
  ],
  [
    "PROBE",
    `$r = powershell -File tools\\run_on_hidden_desktop.ps1 -Log x.txt -CommandLine "powershell -File p.ps1"`,
  ],
  ["PROBE", `& .\\tools\\run_on_hidden_desktop.ps1 -Log x.txt -CommandLine "powershell -File p.ps1"`],
  ["PROBE", `.\\tools\\run_on_hidden_desktop.ps1 -Log x.txt -CommandLine "pwsh -File p.ps1"`],
  [
    "PROBE",
    `pwsh -NoProfile -File "E:\\Projects\\tandem commander\\tools\\run_on_hidden_desktop.ps1" -Log x`,
  ],
  ["TEST", `npm --prefix tools/backlog-app run check`],
  ["TEST", `npm -w packages/shared test`],
  ["TEST", `cd tools/backlog-app; npx vitest run packages/shared/test/run-story.test.ts`],
  ["TEST", `timeout 600 npx vitest run`],
  ["TEST", `python -m pytest tools/backlog -q`],
  ["TEST", `python -I tools/test_bin_help.py`],
  ["TEST", `py -3 -m unittest discover tools/backlog`],
  ["CHECK", `python tools/check_encoding.py --strict | tail -1`],
  ["CHECK", `python -I "E:\\Projects\\tandemcommander\\tools\\check_encoding.py" --strict`],
  // Must NOT be build/test/probe:
  ["SHELL", `tasklist | grep -i -E "powershell|msbuild|cl.exe" | head`],
  ["SHELL", `grep -E "build.cmd|saltests.exe" specs/x/fix-log.md`],
  ["SHELL", `Select-String -Path x.txt -Pattern "error C|BUILD (SUCCEEDED|FAILED)|msbuild"`],
  ["SHELL", `git log --oneline | grep "; build.cmd"`],
  ["SHELL", `echo "run: ./build.cmd; saltests.exe" >> fix-log.md`],
  ["SHELL", `python -c "import subprocess; print('x | build.cmd')"`],
  ["SHELL", `sed -i 's/a/b/' file.md; echo "x || ./build.cmd full"`],
  ["SHELL", `cat > notes.md <<'EOF'\nbuild.cmd full\nsaltests.exe\nEOF\necho ok`],
  ["SHELL", `git commit -m "fix; ./build.cmd passes"`],
];

describe("command reading", () => {
  for (const [want, command] of cases) {
    it(`${want}: ${command.replace(/\n/g, " / ").slice(0, 80)}`, () => {
      const label = classifyCommand(command).label;
      if (want === "SHELL" && command.startsWith("git commit")) expect(label).toBe("COMMIT");
      else expect(label).toBe(want);
    });
  }

  it("names the checks of combined and launched commands", () => {
    expect(checkSubjects('$o = .\\build.cmd 2>&1; & "build\\saltests.exe"')).toEqual(["build", "saltests"]);
    expect(checkSubjects("cmd /c build.cmd full")).toEqual(["build"]);
    expect(
      checkSubjects(
        'foreach ($l in "a") { powershell -File tools\\run_on_hidden_desktop.ps1 -CommandLine "powershell -File specs\\x\\probe\\find_probe.ps1" }',
      ),
    ).toEqual(["probe:find_probe"]);
    expect(checkSubjects("npm --prefix tools/backlog-app run check")).toEqual(["tests:npm check"]);
    expect(checkSubjects('git commit -m "fix; ./build.cmd passes"')).toEqual([]);
  });

  it("reads launchers and nested commands", () => {
    expect(programsOf('powershell -NoProfile -Command ".\\build.cmd; exit $LASTEXITCODE"')).toContain(
      "build.cmd",
    );
    expect(programsOf('bash -c "npx vitest run"')).toContain("npx vitest");
    expect(programsOf("Start-Process -Wait -FilePath .\\build.cmd")).toEqual(["build.cmd"]);
    // A heredoc cut short (the command is clipped) has no end: its body is never read.
    expect(programsOf("cat > a <<'EOF'\nbuild.cmd\n")).toEqual(["cat"]);
  });
});
