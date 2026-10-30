// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Client state shared by the whole page: the overview state the server pushes (write gate,
 * loop, repository, tray counter), the connection status of the event stream, and whether the
 * session was lost (the app was restarted).
 *
 * Server data that a view shows (board, items, runs) lives in TanStack Query, not here; the event
 * stream only invalidates it (research R5).
 */

import { create } from "zustand";
import type { LoopView, StateView, WriteGate } from "@backlog-app/shared";

/** The shared client state. */
export interface AppState {
  /** The last overview state, null before the first `hello`. */
  state: StateView | null;
  /** True while the event stream is connected. */
  connected: boolean;
  /** True when the server rejected the token (it was restarted). */
  sessionLost: boolean;
  /** Replaces the whole overview state (on `hello`). */
  setState: (state: StateView) => void;
  /** Replaces the write gate (on `gate.changed`). */
  setGate: (gate: WriteGate) => void;
  /** Replaces the loop view (on `loop.changed`). */
  setLoop: (loop: LoopView) => void;
  /** Sets the tray counters (on `tray.changed`). */
  setTray: (tray: StateView["tray"]) => void;
  /** Sets the check count (on `check.changed`). */
  setCheck: (total: number) => void;
  /** Sets the read source (on `board.changed`). */
  setSource: (source: StateView["source"]) => void;
  /** Sets the run summary (on `run.changed`). */
  setRun: (run: StateView["run"]) => void;
  /** Sets the connection status. */
  setConnected: (connected: boolean) => void;
  /** Marks the session as lost. */
  setSessionLost: () => void;
}

/** The store hook. */
export const useAppStore = create<AppState>((set) => ({
  state: null,
  connected: false,
  sessionLost: false,
  setState: (state) => set({ state }),
  setGate: (gate) => set((s) => (s.state ? { state: { ...s.state, gate } } : s)),
  setLoop: (loop) => set((s) => (s.state ? { state: { ...s.state, loop } } : s)),
  setTray: (tray) => set((s) => (s.state ? { state: { ...s.state, tray } } : s)),
  setCheck: (total) => set((s) => (s.state ? { state: { ...s.state, check: { total } } } : s)),
  setSource: (source) => set((s) => (s.state ? { state: { ...s.state, source } } : s)),
  setRun: (run) => set((s) => (s.state ? { state: { ...s.state, run } } : s)),
  setConnected: (connected) => set({ connected }),
  setSessionLost: () => set({ sessionLost: true }),
}));
