// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Connects the page to the server's event stream and turns events into store updates and
 * query invalidations (research R5; FR-014, FR-045).
 *
 * Files changed underneath (by a run, a terminal or Claude Code) reach every open view this way:
 * the server notices the change, publishes `board.changed`, and the views re-fetch - without a
 * page reload.
 */

import type { QueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import type { LoopView, NotificationEvent, StateView, WriteGate } from "@backlog-app/shared";
import { openStream } from "@/lib/sse.ts";
import { useAppStore } from "./store.ts";
import { showDesktopNotification } from "@/features/notifications/desktop.ts";

/**
 * Opens the event stream for the page's lifetime.
 *
 * @param queryClient - The query cache to invalidate.
 * @returns A function that closes the stream.
 */
export function connectAppEvents(queryClient: QueryClient): () => void {
  const store = useAppStore.getState();
  return openStream("/api/events", {
    onConnection: (connected) => {
      store.setConnected(connected);
      // After a reconnect everything may have changed while the stream was down.
      if (connected) void queryClient.invalidateQueries();
    },
    onEvent: ({ event, data }) => {
      switch (event) {
        case "hello":
          store.setState(data as StateView);
          break;
        case "gate.changed":
          store.setGate(data as WriteGate);
          break;
        case "loop.changed":
          store.setLoop(data as LoopView);
          void queryClient.invalidateQueries({ queryKey: ["loop"] });
          break;
        case "board.changed":
          store.setSource((data as { ref: StateView["source"] }).ref);
          void queryClient.invalidateQueries({ queryKey: ["board"] });
          void queryClient.invalidateQueries({ queryKey: ["item"] });
          void queryClient.invalidateQueries({ queryKey: ["next"] });
          break;
        case "check.changed":
          store.setCheck((data as { total: number }).total);
          void queryClient.invalidateQueries({ queryKey: ["check"] });
          break;
        case "tray.changed":
          store.setTray(data as StateView["tray"]);
          void queryClient.invalidateQueries({ queryKey: ["tray"] });
          break;
        case "run.changed":
          store.setRun(data as StateView["run"]);
          void queryClient.invalidateQueries({ queryKey: ["run"] });
          void queryClient.invalidateQueries({ queryKey: ["runs"] });
          break;
        case "job.changed":
          void queryClient.invalidateQueries({ queryKey: ["jobs"] });
          break;
        case "notify": {
          const notification = data as NotificationEvent;
          const show =
            notification.severity === "urgent"
              ? toast.error
              : notification.severity === "attention"
                ? toast.warning
                : toast.info;
          show(notification.title, {
            description: notification.text,
            duration: notification.severity === "urgent" ? Infinity : 8000,
          });
          showDesktopNotification(notification);
          void queryClient.invalidateQueries({ queryKey: ["events"] });
          break;
        }
        default:
          break;
      }
    },
  });
}
