// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Control of the backlog loop through its own commands (research R13).
 *
 * The application drives the loop and never hosts it:
 * - *start* runs `loop.py start --new-window`: the loop re-launches itself in its own console
 *   window and the command returns; the loop then lives independently of this server (closing the
 *   app changes nothing), Ctrl+C in its window keeps its meaning, and claude gets no extra windows;
 * - *pause*, *resume*, *stop* and *kill* are the loop's own commands - the server never creates or
 *   deletes the loop's flag files, so there is one source of truth;
 * - *kill* is the loop's hard stop, handled by the loop exactly like Ctrl+Break in its window: the
 *   run is recorded as killed, the lock stays, the next start continues the run. The application
 *   never kills a run's claude process itself (the loop would misread that as an error, analysis
 *   A2 §2.2 scenario C).
 */

import { ApiError, type LoopStartOptions } from "@backlog-app/shared";
import { LOOP_PY, type ServerContext } from "../context.ts";
import { pythonExecutable, runProcess } from "../proc/spawn.ts";
import type { LoopMonitor } from "./monitor.ts";

/** The answer of a loop command. */
export interface LoopCommandResult {
  /** The loop's exit code. */
  code: number | null;
  /** What the loop printed (shown to the maintainer). */
  output: string;
}

/**
 * Runs one loop command.
 *
 * @param ctx - The server context.
 * @param args - The command and its options (validated values only - never user text).
 * @param timeoutMs - Limit for the command.
 * @returns Exit code and output.
 */
async function loopCommand(
  ctx: ServerContext,
  args: string[],
  timeoutMs = 30_000,
): Promise<LoopCommandResult> {
  const result = await runProcess(
    pythonExecutable(),
    ["-X", "utf8", "-u", LOOP_PY, ...args, "--root", ctx.repo.root],
    {
      cwd: ctx.repo.root,
      timeoutMs,
    },
  );
  return { code: result.code, output: `${result.stdout}${result.stderr}`.trim() };
}

/**
 * Builds the arguments of `start` from validated options.
 *
 * @param options - The options from the start dialog.
 * @returns The arguments after `start`.
 */
export function startArguments(options: LoopStartOptions & { item?: string }): string[] {
  const args: string[] = [];
  if (options.maxItems) args.push("--max-items", String(options.maxItems));
  if (options.maxBlocked) args.push("--max-blocked", String(options.maxBlocked));
  if (options.poll) args.push("--poll", String(options.poll));
  if (options.model) args.push("--model", options.model);
  if (options.untilIdle) args.push("--until-idle");
  if (options.autoTriage) args.push("--auto-triage");
  if (options.forgetRun) args.push("--forget-run");
  if (options.item) args.push("--item", options.item);
  return args;
}

/** Control commands of the loop. */
export class LoopControl {
  /** The server context. */
  private readonly ctx: ServerContext;

  /** The status poller (refreshed after every command). */
  private readonly monitor: LoopMonitor;

  /**
   * Creates the controller.
   *
   * @param ctx - The server context.
   * @param monitor - The status poller.
   */
  constructor(ctx: ServerContext, monitor: LoopMonitor) {
    this.ctx = ctx;
    this.monitor = monitor;
  }

  /**
   * Starts the loop in its own console window.
   *
   * @param options - Validated start options; `item` runs one chosen item.
   * @returns The loop's answer.
   * @throws ApiError `busy` when a loop lives, `refused` when the loop refused.
   */
  async start(options: LoopStartOptions & { item?: string }): Promise<LoopCommandResult> {
    const view = await this.monitor.refresh();
    if (view?.live) throw new ApiError("busy", "a loop is already running - pause, stop or attach to it");
    const result = await loopCommand(
      this.ctx,
      ["start", "--new-window", ...startArguments(options), ...this.ctx.loopTestArgs],
      40_000,
    );
    await this.monitor.refresh();
    if (result.code !== 0) throw new ApiError("refused", result.output || "the loop did not start");
    return result;
  }

  /**
   * Pauses: the running item finishes, then the loop waits.
   *
   * @returns The loop's answer.
   */
  async pause(): Promise<LoopCommandResult> {
    return this.simple("pause");
  }

  /**
   * Resumes after a pause; also cancels a pending stop.
   *
   * @returns The loop's answer.
   */
  async resume(): Promise<LoopCommandResult> {
    return this.simple("resume");
  }

  /**
   * Stops: the running item finishes, then the loop ends.
   *
   * @returns The loop's answer.
   */
  async stop(): Promise<LoopCommandResult> {
    return this.simple("stop");
  }

  /**
   * Hard stop through the loop's own `kill` command, after the typed confirmation.
   *
   * @param confirm - What the maintainer typed: the running item's slug, or `triage`.
   * @returns The loop's answer.
   * @throws ApiError `refused` when no loop lives or the confirmation does not match.
   */
  async kill(confirm: string): Promise<LoopCommandResult> {
    const view = await this.monitor.refresh();
    if (!view?.live) throw new ApiError("refused", "no loop is running");
    const expected = view.shown === "triage" ? "triage" : (view.slug ?? "loop");
    if (confirm !== expected) {
      throw new ApiError("refused", `type '${expected}' to confirm the hard stop`);
    }
    return this.simple("kill");
  }

  /**
   * Runs a command without options and refreshes the view.
   *
   * @param command - `pause`, `resume`, `stop` or `kill`.
   * @returns The loop's answer.
   */
  private async simple(command: "pause" | "resume" | "stop" | "kill"): Promise<LoopCommandResult> {
    const result = await loopCommand(this.ctx, [command]);
    await this.monitor.refresh();
    if (result.code !== 0) throw new ApiError("refused", result.output || `${command} failed`);
    return result;
  }
}
