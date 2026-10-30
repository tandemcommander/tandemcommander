// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Settings (data-model *Settings*): theme, density, notifications (desktop, events, quiet
 * hours), the automatic commit before the loop starts, the AI budget, and the saved views.
 */

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { EVENT_KINDS, type Settings } from "@backlog-app/shared";
import { AppLink } from "@/components/app-link.tsx";
import { Button } from "@/components/ui/button.tsx";
import {
  Card,
  CardHeader,
  CardTitle,
  Input,
  Label,
  NativeSelect,
  Skeleton,
} from "@/components/ui/primitives.tsx";
import { apiCall, ApiFailure } from "@/lib/api.ts";
import { useSettings, useViews } from "@/lib/queries.ts";
import { setTheme, useTheme, type ThemeChoice } from "@/lib/theme.ts";
import { applyNotificationSettings, requestDesktopPermission } from "@/features/notifications/desktop.ts";

/** Readable names of the event kinds. */
const EVENT_LABEL: Record<string, string> = {
  "run-ended": "A run ended",
  "stopped-for-person": "The loop stopped for a person",
  "usage-limit": "The loop waits for a usage limit",
  "usage-limit-over": "The usage-limit wait is over",
  "precheck-wait": "The loop waited on its precheck for 10 minutes",
  "inbox-added": "Runs added Inbox items",
  "check-findings": "The check found problems",
  "loop-ended": "The loop ended",
};

/**
 * The settings page.
 *
 * @returns The element.
 */
export function SettingsPage() {
  const settings = useSettings();
  const views = useViews();
  const theme = useTheme();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<Settings | null>(null);
  const [draftOf, setDraftOf] = useState<Settings | undefined>(undefined);
  // Freshly loaded settings become the draft (adjusted during render).
  if (settings.data && settings.data !== draftOf) {
    setDraftOf(settings.data);
    setDraft(settings.data);
  }
  const save = useMutation({
    mutationFn: (next: Settings) => apiCall<Settings>("PUT", "/api/settings", next),
    onSuccess: (stored) => {
      toast.success("Settings saved");
      applyNotificationSettings(stored);
      void queryClient.invalidateQueries({ queryKey: ["settings"] });
    },
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
  const removeView = useMutation({
    mutationFn: (name: string) => apiCall("DELETE", `/api/views/${encodeURIComponent(name)}`, {}),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["views"] }),
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
  if (!draft) return <Skeleton className="m-4 h-60" />;
  /**
   * Changes the draft.
   *
   * @param patch - The fields to change.
   */
  const set = (patch: Partial<Settings>): void => {
    setDraft({ ...draft, ...patch });
  };
  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 p-4">
      <h1 className="text-lg font-semibold">Settings</h1>
      <Card>
        <CardHeader>
          <CardTitle>Appearance</CardTitle>
        </CardHeader>
        <div className="grid gap-3 p-4 sm:grid-cols-2">
          <div>
            <Label htmlFor="theme">Theme</Label>
            <NativeSelect
              id="theme"
              value={theme}
              onChange={(e) => {
                setTheme(e.target.value as ThemeChoice);
                set({ theme: e.target.value as ThemeChoice });
              }}
            >
              <option value="system">System</option>
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </NativeSelect>
          </div>
          <div>
            <Label htmlFor="density">Density</Label>
            <NativeSelect
              id="density"
              value={draft.density}
              onChange={(e) => set({ density: e.target.value as Settings["density"] })}
            >
              <option value="compact">Compact</option>
              <option value="comfortable">Comfortable</option>
            </NativeSelect>
          </div>
        </div>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Notifications</CardTitle>
        </CardHeader>
        <div className="flex flex-col gap-3 p-4 text-sm">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={draft.notifications.desktop}
              onChange={(e) => {
                void (async () => {
                  const on = e.target.checked && (await requestDesktopPermission());
                  if (e.target.checked && !on) toast.error("The browser did not allow notifications.");
                  set({ notifications: { ...draft.notifications, desktop: on } });
                })();
              }}
            />
            Desktop notifications (the browser asks once)
          </label>
          <fieldset className="grid gap-1 sm:grid-cols-2">
            <legend className="mb-1 text-xs font-medium text-muted-foreground">Events</legend>
            {EVENT_KINDS.map((kind) => (
              <label key={kind} className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={draft.notifications.events[kind] !== false}
                  onChange={(e) =>
                    set({
                      notifications: {
                        ...draft.notifications,
                        events: { ...draft.notifications.events, [kind]: e.target.checked },
                      },
                    })
                  }
                />
                {EVENT_LABEL[kind] ?? kind}
              </label>
            ))}
          </fieldset>
          <div className="flex flex-wrap items-end gap-2">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={draft.notifications.quietHours !== null}
                onChange={(e) =>
                  set({
                    notifications: {
                      ...draft.notifications,
                      quietHours: e.target.checked ? { from: "22:00", to: "07:00" } : null,
                    },
                  })
                }
              />
              Quiet hours (no desktop notifications)
            </label>
            {draft.notifications.quietHours ? (
              <>
                <Input
                  aria-label="Quiet from"
                  type="time"
                  className="w-28"
                  value={draft.notifications.quietHours.from}
                  onChange={(e) =>
                    set({
                      notifications: {
                        ...draft.notifications,
                        quietHours: { ...draft.notifications.quietHours!, from: e.target.value },
                      },
                    })
                  }
                />
                <Input
                  aria-label="Quiet until"
                  type="time"
                  className="w-28"
                  value={draft.notifications.quietHours.to}
                  onChange={(e) =>
                    set({
                      notifications: {
                        ...draft.notifications,
                        quietHours: { ...draft.notifications.quietHours!, to: e.target.value },
                      },
                    })
                  }
                />
              </>
            ) : null}
          </div>
        </div>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>Loop and AI</CardTitle>
        </CardHeader>
        <div className="grid gap-3 p-4 sm:grid-cols-2">
          <div>
            <Label htmlFor="autocommit">Commit the change tray before the loop starts or resumes</Label>
            <NativeSelect
              id="autocommit"
              value={draft.autoCommitBeforeLoop}
              onChange={(e) =>
                set({ autoCommitBeforeLoop: e.target.value as Settings["autoCommitBeforeLoop"] })
              }
            >
              <option value="ask">Ask</option>
              <option value="always">Always</option>
              <option value="never">Never (the loop then waits on the dirty tree)</option>
            </NativeSelect>
          </div>
          <div>
            <Label htmlFor="budget">AI budget per job (USD)</Label>
            <Input
              id="budget"
              type="number"
              min={0.1}
              max={50}
              step={0.1}
              value={draft.aiBudgetUsd}
              onChange={(e) => set({ aiBudgetUsd: Number(e.target.value) })}
            />
          </div>
        </div>
      </Card>
      <div className="flex justify-end">
        <Button disabled={save.isPending} onClick={() => save.mutate(draft)}>
          Save settings
        </Button>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Saved views</CardTitle>
        </CardHeader>
        <ul className="flex flex-col gap-1 p-4 text-sm">
          {(views.data?.views ?? []).map((view) => (
            <li key={view.name} className="flex items-center gap-2">
              <AppLink href={view.url} className="text-primary hover:underline">
                {view.name}
              </AppLink>
              <code className="truncate text-xs text-muted-foreground">{view.url}</code>
              {view.builtIn ? (
                <span className="ml-auto text-xs text-muted-foreground">built in</span>
              ) : (
                <Button
                  size="sm"
                  variant="ghost"
                  className="ml-auto"
                  onClick={() => removeView.mutate(view.name)}
                >
                  Delete
                </Button>
              )}
            </li>
          ))}
        </ul>
      </Card>
    </div>
  );
}
