// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The client side of every backlog change (FR-024, FR-036; analysis A4 §4.2).
 *
 * - A change is confirmed, not optimistic: the view shows the state the server read back after the
 *   tool wrote, never a guess (only reorders move a row at once, see the sortable section).
 * - A refusal (`refused`, nothing written) is shown at the control with the tool's text verbatim.
 * - A change written with check findings is a warning without a retry button (the change is in).
 * - A stale view (`changed-underneath`) reloads the data and keeps what the user typed.
 */

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import type { ChangeResult } from "@backlog-app/shared";
import { apiPost, ApiFailure } from "./api.ts";

/** What a change dialog shows after a failed submit. */
export interface ChangeProblem {
  /** `refused`, `changed-underneath`, `gate-closed`, ... */
  code: string;
  /** The message (for `refused` the tool's own words). */
  message: string;
}

/**
 * A mutation for one changing route.
 *
 * @param onDone - Called after a written change (e.g. to close the dialog).
 * @returns The mutation, the last problem and a reset of it.
 */
export function useChange(onDone?: (result: ChangeResult) => void) {
  const queryClient = useQueryClient();
  const [problem, setProblem] = useState<ChangeProblem | null>(null);
  const mutation = useMutation({
    mutationFn: ({ path, body }: { path: string; body: unknown }) => apiPost<ChangeResult>(path, body),
    onMutate: () => setProblem(null),
    onSuccess: (result) => {
      void queryClient.invalidateQueries({ queryKey: ["board"] });
      void queryClient.invalidateQueries({ queryKey: ["item"] });
      void queryClient.invalidateQueries({ queryKey: ["tray"] });
      if (result.findings.length > 0) {
        // Written: never offer a retry (analysis A1 §3).
        toast.warning("The change was written, but the check found problems", {
          description: result.findings.map((f) => `${f.rule}: ${f.message}`).join("\n"),
          duration: 15_000,
        });
      } else {
        toast.success(result.change?.summary ?? "Changed");
      }
      for (const notice of result.notices) toast.info(notice);
      onDone?.(result);
    },
    onError: (error) => {
      const failure = error instanceof ApiFailure ? error : new ApiFailure(0, "network", String(error));
      setProblem({ code: failure.code, message: failure.message });
      if (failure.code === "changed-underneath") {
        void queryClient.invalidateQueries({ queryKey: ["board"] });
        void queryClient.invalidateQueries({ queryKey: ["item"] });
      }
    },
  });
  return { mutation, problem, clearProblem: () => setProblem(null) };
}
