// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file AI jobs in the page (user story 5; FR-037 - FR-039; contracts/ai-jobs.md): starting a job,
 * following it, cancelling it, and the job card. A job only reads (its claude has no write or shell
 * tools); its result is a proposal the maintainer reviews and edits before the app applies it
 * through the backlog tool. One job runs at a time.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { LoaderIcon, SparklesIcon, XIcon } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import type { AiJob, AiJobKind } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Card } from "@/components/ui/primitives.tsx";
import { apiGet, apiPost, ApiFailure } from "@/lib/api.ts";
import { formatDuration } from "@/lib/utils.ts";
import { useNow } from "@/lib/now.ts";

/**
 * Starts and follows one AI job.
 *
 * @returns The current job (null before a start), a start function, a cancel function, and the
 *   start mutation.
 */
export function useAiJob() {
  const queryClient = useQueryClient();
  const [jobId, setJobId] = useState<string | null>(null);
  const job = useQuery({
    queryKey: ["jobs", jobId],
    queryFn: ({ signal }) => apiGet<AiJob>(`/api/ai/jobs/${jobId}`, signal),
    enabled: jobId !== null,
    // Events invalidate it; the interval is a safety net while it runs.
    refetchInterval: (query) => (query.state.data?.state === "running" ? 2000 : false),
  });
  const start = useMutation({
    mutationFn: ({ kind, input }: { kind: AiJobKind; input: Record<string, unknown> }) =>
      apiPost<AiJob>("/api/ai/jobs", { kind, input }),
    onSuccess: (created) => {
      setJobId(created.id);
      void queryClient.invalidateQueries({ queryKey: ["jobs"] });
    },
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
  const cancel = useMutation({
    mutationFn: () => apiPost(`/api/ai/jobs/${jobId}/cancel`, {}),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["jobs"] }),
  });
  return {
    job: job.data ?? null,
    start: (kind: AiJobKind, input: Record<string, unknown>) => start.mutate({ kind, input }),
    starting: start.isPending,
    cancel: () => cancel.mutate(),
    reset: () => setJobId(null),
  };
}

/**
 * The job card: state, the last progress lines, elapsed time, cost, cancel, failure text.
 *
 * @param props - The job and its cancel handler.
 * @returns The element.
 */
export function JobCard({
  job,
  onCancel,
}: {
  /** The job. */ job: AiJob;
  /** Cancels it. */ onCancel: () => void;
}) {
  const now = useNow(1000, job.state === "running");
  const elapsed = ((job.endedAt ? Date.parse(job.endedAt) : now) - Date.parse(job.startedAt)) / 1000;
  return (
    <Card className="flex flex-col gap-2 p-3 text-sm" aria-live="polite">
      <div className="flex items-center gap-2">
        {job.state === "running" ? (
          <LoaderIcon className="size-4 animate-spin motion-reduce:animate-none" aria-hidden />
        ) : (
          <SparklesIcon className="size-4" aria-hidden />
        )}
        <span className="font-medium">
          AI {job.kind}: {job.state}
        </span>
        <span className="text-xs text-muted-foreground">
          {formatDuration(elapsed)}
          {job.costUsd !== null ? ` · $${job.costUsd.toFixed(2)}` : ""}
        </span>
        {job.state === "running" ? (
          <Button size="sm" variant="ghost" className="ml-auto" onClick={onCancel}>
            <XIcon /> Cancel
          </Button>
        ) : null}
      </div>
      {job.progress.length > 0 ? (
        <ul className="max-h-28 overflow-y-auto font-mono text-xs text-muted-foreground">
          {job.progress.slice(-8).map((p, i) => (
            <li key={`${p.at}-${i}`} className="truncate">
              {p.text}
            </li>
          ))}
        </ul>
      ) : null}
      {job.error ? <Alert tone="bad">{job.error}</Alert> : null}
      {job.state === "running" ? (
        <p className="text-xs text-muted-foreground">
          The AI only reads the repository; nothing is written until you confirm the result.
        </p>
      ) : null}
    </Card>
  );
}
