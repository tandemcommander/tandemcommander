// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Entry point of the web client: establishes the session (the one-time start code from the
 * address, contracts/security.md), connects the event stream and renders the app.
 */

import "./index.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { Toaster } from "sonner";
import { TooltipProvider } from "@/components/ui/overlays.tsx";
import { establishSession, onSessionLost } from "@/lib/api.ts";
import { useTheme } from "@/lib/theme.ts";
import { connectAppEvents } from "./app/events.ts";
import { FullPageMessage } from "./app/layout.tsx";
import { router } from "./app/router.tsx";
import { useAppStore } from "./app/store.ts";

/** The query cache: data is kept fresh by events, so no polling and no refetch on focus. */
const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, refetchOnWindowFocus: false, retry: 1 },
  },
});

/**
 * The toasts, in the current theme.
 *
 * @returns The element.
 */
function ThemedToaster() {
  const theme = useTheme();
  return <Toaster theme={theme} position="bottom-right" closeButton richColors />;
}

/**
 * The app with its providers.
 *
 * @returns The element.
 */
function App() {
  return (
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <TooltipProvider delayDuration={300}>
          <RouterProvider router={router} />
          <ThemedToaster />
        </TooltipProvider>
      </QueryClientProvider>
    </StrictMode>
  );
}

/** Starts the client. */
async function start(): Promise<void> {
  const root = createRoot(document.getElementById("root")!);
  const hasSession = await establishSession();
  if (!hasSession) {
    root.render(
      <FullPageMessage title="Open the backlog app from its start address">
        This page has no session. Start the app with <code>bin/start-backlog-app.sh</code>; it opens the right
        address (with a one-time start code) and prints it in the terminal.
      </FullPageMessage>,
    );
    return;
  }
  onSessionLost(() => useAppStore.getState().setSessionLost());
  connectAppEvents(queryClient);
  root.render(<App />);
}

void start();
