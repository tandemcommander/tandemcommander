// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The loop page (user stories 2 and 6; FR-013, FR-015 - FR-018, FR-021): the loop's state in
 * words, starting it with every option, pause / resume / stop, the hard stop with a typed
 * confirmation, running one chosen item, an interrupted run and what the next start does, the run
 * lock (and the release of a stale one), and the loop's own log.
 *
 * The loop is started in its own console window and never hosted by the app (research R13): it
 * keeps running when the app or the browser is closed, and Ctrl+C in its window keeps its meaning.
 */

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { CirclePlayIcon, OctagonXIcon, PlayIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import type { ItemRowView } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import {
  Alert,
  Card,
  CardHeader,
  CardTitle,
  Input,
  Label,
  NativeSelect,
  Skeleton,
} from "@/components/ui/primitives.tsx";
import { Dialog, DialogContent, DialogFooter } from "@/components/ui/overlays.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { apiPost, ApiFailure } from "@/lib/api.ts";
import { useBoard, useLiveRun, useLoop } from "@/lib/queries.ts";
import { formatBytes, relativeTime } from "@/lib/utils.ts";
import { useAppStore } from "@/app/store.ts";
import { LOOP_STATE_TEXT, loopLine, useLoopCommand } from "./loop-status.tsx";

/**
 * A mutation of a loop route that reports its answer as a toast.
 *
 * @param path - The route.
 * @param onDone - Called after success.
 * @returns The mutation and the last problem.
 */
function useLoopAction(path: string, onDone?: () => void) {
  const queryClient = useQueryClient();
  const [problem, setProblem] = useState<{ code: string; message: string } | null>(null);
  const mutation = useMutation({
    mutationFn: (body: unknown) => apiPost<{ output: string }>(path, body),
    onMutate: () => setProblem(null),
    onSuccess: (answer) => {
      toast.success(answer.output || "Done");
      void queryClient.invalidateQueries();
      onDone?.();
    },
    onError: (error) =>
      setProblem(
        error instanceof ApiFailure
          ? { code: error.code, message: error.message }
          : { code: "network", message: String(error) },
      ),
  });
  return { mutation, problem };
}

/**
 * The start dialog with every option of `loop.py start`.
 *
 * @param props - Close handler, whether an interrupted run is waiting.
 * @returns The element.
 */
function StartDialog({
  onClose,
  interrupted,
}: {
  /** Closes it. */ onClose: () => void;
  /** An interrupted run needs a person. */ interrupted: boolean;
}) {
  const { mutation, problem } = useLoopAction("/api/loop/start", onClose);
  const pending = useAppStore((s) => s.state?.tray.pending ?? 0);
  const [maxItems, setMaxItems] = useState("");
  const [maxBlocked, setMaxBlocked] = useState("3");
  const [poll, setPoll] = useState("60");
  const [model, setModel] = useState("");
  const [untilIdle, setUntilIdle] = useState(false);
  const [autoTriage, setAutoTriage] = useState(false);
  const [forgetRun, setForgetRun] = useState(false);
  const [commitTray, setCommitTray] = useState(true);
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        title="Start the loop"
        description="It opens in its own console window and keeps running when the app is closed."
        wide
      >
        <form
          className="flex flex-col gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            mutation.mutate({
              ...(maxItems ? { maxItems: Number(maxItems) } : {}),
              ...(maxBlocked ? { maxBlocked: Number(maxBlocked) } : {}),
              ...(poll ? { poll: Number(poll) } : {}),
              ...(model.trim() ? { model: model.trim() } : {}),
              untilIdle,
              autoTriage,
              forgetRun,
              commitTray,
            });
          }}
        >
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <div>
              <Label htmlFor="max-items">Max items</Label>
              <Input
                id="max-items"
                type="number"
                min={0}
                placeholder="no limit"
                value={maxItems}
                onChange={(e) => setMaxItems(e.target.value)}
              />
            </div>
            <div>
              <Label htmlFor="max-blocked">Stop after blocked in a row</Label>
              <Input
                id="max-blocked"
                type="number"
                min={1}
                value={maxBlocked}
                onChange={(e) => setMaxBlocked(e.target.value)}
              />
            </div>
            <div>
              <Label htmlFor="poll">Poll (seconds)</Label>
              <Input id="poll" type="number" min={5} value={poll} onChange={(e) => setPoll(e.target.value)} />
            </div>
            <div>
              <Label htmlFor="model">Model</Label>
              <Input
                id="model"
                placeholder="claude's default"
                value={model}
                onChange={(e) => setModel(e.target.value)}
              />
            </div>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={untilIdle} onChange={(e) => setUntilIdle(e.target.checked)} /> End
            when nothing is eligible (instead of waiting)
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={autoTriage} onChange={(e) => setAutoTriage(e.target.checked)} />{" "}
            Auto-triage new Inbox items before each run
          </label>
          {pending > 0 ? (
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={commitTray} onChange={(e) => setCommitTray(e.target.checked)} />{" "}
              Commit the {pending} uncommitted change(s) first (otherwise the loop waits on the dirty tree)
            </label>
          ) : null}
          {interrupted ? (
            <label className="flex items-center gap-2 text-sm text-warn">
              <input type="checkbox" checked={forgetRun} onChange={(e) => setForgetRun(e.target.checked)} />{" "}
              Forget the interrupted run (only after you cleaned it up - its lock stays)
            </label>
          ) : null}
          <ChangeProblemBox problem={problem} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              <CirclePlayIcon /> {mutation.isPending ? "Starting…" : "Start"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The hard-stop dialog (FR-017): typed confirmation, warnings about a GUI probe and the
 * auto-triage.
 *
 * @param props - What to type, whether a probe or triage runs, the close handler.
 * @returns The element.
 */
function KillDialog({
  expected,
  probe,
  triage,
  onClose,
}: {
  /** What to type. */ expected: string;
  /** A GUI probe runs. */ probe: boolean;
  /** The auto-triage runs. */ triage: boolean;
  /** Closes it. */ onClose: () => void;
}) {
  const { mutation, problem } = useLoopAction("/api/loop/kill", onClose);
  const [typed, setTyped] = useState("");
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        title="Hard stop"
        description="Like Ctrl+C in the loop's window: the running claude is killed, the run keeps its lock and the next start continues it."
      >
        {probe ? (
          <Alert tone="bad">
            A GUI probe is running. Its registry backup must be restored before anything else (the continued
            run is told so).
          </Alert>
        ) : null}
        {triage ? (
          <Alert tone="warn">
            The auto-triage is running; a kill can leave uncommitted changes in backlog/, and the next start
            waits for a clean tree.
          </Alert>
        ) : null}
        <form
          className="flex flex-col gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            mutation.mutate({ confirm: typed.trim() });
          }}
        >
          <div>
            <Label htmlFor="kill-confirm">
              Type <code>{expected}</code> to confirm
            </Label>
            <Input id="kill-confirm" value={typed} onChange={(e) => setTyped(e.target.value)} autoFocus />
          </div>
          <ChangeProblemBox problem={problem} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button
              type="submit"
              variant="destructive"
              disabled={typed.trim() !== expected || mutation.isPending}
            >
              <OctagonXIcon /> Hard stop
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * Run one chosen item now (FR-018): a single loop run of that item; the backlog order is kept.
 *
 * @param props - Close handler.
 * @returns The element.
 */
function RunItemDialog({ onClose }: { /** Closes it. */ onClose: () => void }) {
  const { mutation, problem } = useLoopAction("/api/loop/run-item", onClose);
  const board = useBoard("");
  const next =
    board.data?.sections
      .find((s) => s.name === "Next")
      ?.rows.filter((r): r is ItemRowView => r.kind === "item") ?? [];
  const [slug, setSlug] = useState("");
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        title="Run one item now"
        description="One run of the chosen item in a new loop window; the backlog order does not change. The item must be eligible (open, agent-doable, no open dependency)."
        wide
      >
        <form
          className="flex flex-col gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (slug) mutation.mutate({ slug, commitTray: true });
          }}
        >
          <div>
            <Label htmlFor="run-item">Item of Next</Label>
            <NativeSelect id="run-item" value={slug} onChange={(e) => setSlug(e.target.value)}>
              <option value="">Choose…</option>
              {next.map((row) => (
                <option
                  key={row.slug}
                  value={row.slug}
                  disabled={row.status !== "open" || row.who === "person"}
                >
                  #{row.position} {row.title}
                  {row.status !== "open" ? ` (${row.status})` : ""}
                </option>
              ))}
            </NativeSelect>
          </div>
          <ChangeProblemBox problem={problem} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={!slug || mutation.isPending}>
              <PlayIcon /> Run it
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * Release a stale run lock with a typed confirmation.
 *
 * @param props - The lock's slug and the close handler.
 * @returns The element.
 */
function StaleLockDialog({
  slug,
  onClose,
}: {
  /** The lock's item. */ slug: string;
  /** Closes it. */ onClose: () => void;
}) {
  const { mutation, problem } = useLoopAction("/api/lock/release-stale", onClose);
  const [typed, setTyped] = useState("");
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        title="Release the stale run lock"
        description="Only when no run is alive. The server refuses while a loop or a run's claude lives."
      >
        <form
          className="flex flex-col gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            mutation.mutate({ confirm: typed.trim() });
          }}
        >
          <div>
            <Label htmlFor="lock-confirm">
              Type <code>{slug}</code> to confirm
            </Label>
            <Input id="lock-confirm" value={typed} onChange={(e) => setTyped(e.target.value)} autoFocus />
          </div>
          <ChangeProblemBox problem={problem} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button
              type="submit"
              variant="destructive"
              disabled={typed.trim() !== slug || mutation.isPending}
            >
              Release
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The loop page.
 *
 * @returns The element.
 */
export function LoopPage() {
  const loop = useLoop();
  const liveRun = useLiveRun();
  const [dialog, setDialog] = useState<"start" | "kill" | "item" | "lock" | null>(null);
  const pause = useLoopCommand("pause");
  const resume = useLoopCommand("resume");
  const stop = useLoopCommand("stop");
  const view = loop.data?.view ?? null;
  const logTail = (loop.data as { logTail?: string[] } | undefined)?.logTail ?? [];
  if (loop.isLoading || !view) return <Skeleton className="m-4 h-60" />;
  const tone = LOOP_STATE_TEXT[view.shown].tone;
  const expected = view.shown === "triage" ? "triage" : (view.slug ?? "loop");
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">Loop</h1>
      <Card>
        <CardHeader>
          <CardTitle>{loopLine(view)}</CardTitle>
          <span className={`text-xs ${tone === "bad" ? "text-bad" : "text-muted-foreground"}`}>
            {view.live ? `pid ${view.pid ?? "?"}` : "no loop process"}
          </span>
        </CardHeader>
        <div className="flex flex-col gap-3 p-4 text-sm">
          <p>{view.detail}</p>
          <dl className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <div>
              <dt className="text-xs text-muted-foreground">Started</dt>
              <dd>{relativeTime(view.started)}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Done by this loop</dt>
              <dd>
                {Object.entries(view.counts)
                  .map(([k, v]) => `${k} ${v}`)
                  .join(", ") || "-"}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Blocked in a row</dt>
              <dd>{view.blockedStreak}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Traces</dt>
              <dd>{formatBytes(view.tracesBytes)}</dd>
            </div>
          </dl>
          <div className="flex flex-wrap gap-2">
            {!view.live ? (
              <Button onClick={() => setDialog("start")}>
                <CirclePlayIcon /> Start the loop…
              </Button>
            ) : null}
            {!view.live ? (
              <Button variant="outline" onClick={() => setDialog("item")}>
                <PlayIcon /> Run one item…
              </Button>
            ) : null}
            {view.live && !view.flags.pause ? (
              <Button variant="outline" disabled={pause.isPending} onClick={() => pause.mutate()}>
                Pause
              </Button>
            ) : null}
            {view.flags.pause || view.flags.stop ? (
              <Button variant="outline" disabled={resume.isPending} onClick={() => resume.mutate()}>
                Resume
              </Button>
            ) : null}
            {view.live && !view.flags.stop ? (
              <Button variant="outline" disabled={stop.isPending} onClick={() => stop.mutate()}>
                Stop
              </Button>
            ) : null}
            {view.live ? (
              <Button variant="destructive" onClick={() => setDialog("kill")}>
                <OctagonXIcon /> Hard stop…
              </Button>
            ) : null}
          </div>
          {view.flags.pause && !view.live ? (
            <Alert tone="info">A pause is set: the next start begins paused until you resume.</Alert>
          ) : null}
          {view.interruptedRun ? (
            <Alert tone={view.interruptedRun.needsPerson ? "bad" : "warn"}>
              <div>
                Interrupted run of <strong>{view.interruptedRun.slug}</strong> ({view.interruptedRun.phase}
                {view.interruptedRun.why ? `: ${view.interruptedRun.why}` : ""}).{" "}
                {view.interruptedRun.needsPerson
                  ? "It cannot be continued automatically: look at its trace and branch, finish or stop it by hand, then start with 'Forget the interrupted run'."
                  : `The next start continues it in the same session${view.interruptedRun.waitUntil ? ` after ${view.interruptedRun.waitUntil.replace("T", " ").slice(0, 16)}` : ""}.`}
              </div>
            </Alert>
          ) : null}
          {view.orphanClaude ? (
            <Alert tone="warn">
              A claude of the last loop is still working; the next start waits for it.
            </Alert>
          ) : null}
          {view.lock ? (
            <div className="flex flex-wrap items-center gap-2 text-sm">
              Run lock: item <strong>{view.lock.slug}</strong>, branch {view.lock.branch}, since{" "}
              {view.lock.started.replace("T", " ")}
              {view.lock.stale ? (
                <Button size="sm" variant="destructive" onClick={() => setDialog("lock")}>
                  Release the stale lock…
                </Button>
              ) : null}
            </div>
          ) : (
            <p className="text-xs text-muted-foreground">Run lock: free</p>
          )}
          {view.lastEnd && !view.live ? (
            <p className="text-xs text-muted-foreground">
              The last loop ended {relativeTime(view.lastEnd.ended)} ({view.lastEnd.reason}, exit{" "}
              {view.lastEnd.exitCode ?? "?"}).
            </p>
          ) : null}
        </div>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>The loop's log</CardTitle>
        </CardHeader>
        <pre className="max-h-[50vh] overflow-auto p-4 font-mono text-xs whitespace-pre-wrap">
          {logTail.length
            ? logTail.join("\n")
            : "No log yet (a loop of feature 344 or newer writes .git/tandem-backlog-loop/loop.log)."}
        </pre>
      </Card>
      {dialog === "start" ? (
        <StartDialog
          onClose={() => setDialog(null)}
          interrupted={view.interruptedRun?.needsPerson ?? false}
        />
      ) : null}
      {dialog === "kill" ? (
        <KillDialog
          expected={expected}
          probe={liveRun.data?.run?.guiProbeRunning ?? false}
          triage={view.shown === "triage"}
          onClose={() => setDialog(null)}
        />
      ) : null}
      {dialog === "item" ? <RunItemDialog onClose={() => setDialog(null)} /> : null}
      {dialog === "lock" && view.lock ? (
        <StaleLockDialog slug={view.lock.slug} onClose={() => setDialog(null)} />
      ) : null}
    </div>
  );
}
