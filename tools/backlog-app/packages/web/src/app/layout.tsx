// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The frame around every page (analysis A4 §2.1): a sidebar with the sections and their live
 * counts, a top bar with the loop's state (the most time-critical information), the repository
 * state and the change tray, and the banners for a lost connection and a closed write gate.
 */

import { Link, Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  ActivityIcon,
  ArchiveIcon,
  BookCheckIcon,
  CircleCheckIcon,
  CogIcon,
  FlagIcon,
  HistoryIcon,
  HomeIcon,
  InboxIcon,
  ListOrderedIcon,
  MessageCircleQuestionIcon,
  MoonIcon,
  PackageIcon,
  PlusIcon,
  RepeatIcon,
  SearchIcon,
  SunIcon,
  SunMoonIcon,
  UserCheckIcon,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Button } from "@/components/ui/button.tsx";
import { Badge, Kbd } from "@/components/ui/primitives.tsx";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Tooltip,
} from "@/components/ui/overlays.tsx";
import { useBoard, useSettings, useViews } from "@/lib/queries.ts";
import { applyNotificationSettings } from "@/features/notifications/desktop.ts";
import { setTheme, useTheme, type ThemeChoice } from "@/lib/theme.ts";
import { useShortcuts, type Shortcut } from "@/lib/hotkeys.ts";
import { cn } from "@/lib/utils.ts";
import { useAppStore } from "./store.ts";
import { LoopStatus } from "@/features/loop/loop-status.tsx";
import { CommandPalette } from "@/features/palette/palette.tsx";
import { ShortcutSheet } from "@/features/palette/shortcut-sheet.tsx";
import { TrayButton } from "@/features/tray/tray-drawer.tsx";
import { GateBanner } from "@/features/gate/gate-banner.tsx";

/** One entry of the sidebar. */
interface NavEntry {
  /** Visible label. */
  label: string;
  /** Target address. */
  to: string;
  /** Icon. */
  icon: LucideIcon;
  /** The `g` shortcut letter. */
  key?: string;
  /** Section name whose count is shown. */
  section?: string;
  /** Indent under Backlog. */
  sub?: boolean;
}

/** The sidebar entries in order. */
const NAV: NavEntry[] = [
  { label: "Home", to: "/", icon: HomeIcon, key: "h" },
  { label: "Live run", to: "/live", icon: ActivityIcon, key: "l" },
  { label: "Backlog", to: "/backlog/all", icon: ListOrderedIcon, key: "b" },
  { label: "Next", to: "/backlog/next", icon: ListOrderedIcon, key: "n", section: "Next", sub: true },
  {
    label: "Decisions",
    to: "/backlog/decisions",
    icon: FlagIcon,
    key: "d",
    section: "Decisions for the maintainer",
    sub: true,
  },
  {
    label: "Person steps",
    to: "/backlog/person",
    icon: UserCheckIcon,
    key: "p",
    section: "Person steps",
    sub: true,
  },
  { label: "Inbox", to: "/backlog/inbox", icon: InboxIcon, key: "i", section: "Inbox", sub: true },
  { label: "Parked", to: "/backlog/parked", icon: ArchiveIcon, section: "Parked", sub: true },
  { label: "Rejected", to: "/backlog/rejected", icon: ArchiveIcon, section: "Rejected", sub: true },
  { label: "Closed", to: "/closed", icon: CircleCheckIcon, sub: true },
  { label: "Triage", to: "/triage", icon: InboxIcon, key: "t" },
  { label: "Loop", to: "/loop", icon: RepeatIcon, key: "o" },
  { label: "Runs", to: "/runs", icon: HistoryIcon, key: "r" },
  { label: "Features", to: "/features", icon: PackageIcon, key: "f" },
  { label: "Release", to: "/release", icon: BookCheckIcon, key: "e" },
  { label: "Check", to: "/check", icon: CircleCheckIcon, key: "c" },
  { label: "Ask", to: "/ask", icon: MessageCircleQuestionIcon, key: "a" },
];

/** Icons and labels of the theme choices. */
const THEMES: { value: ThemeChoice; label: string; icon: LucideIcon }[] = [
  { value: "system", label: "System", icon: SunMoonIcon },
  { value: "light", label: "Light", icon: SunIcon },
  { value: "dark", label: "Dark", icon: MoonIcon },
];

/**
 * The theme switch in the top bar.
 *
 * @returns The element.
 */
function ThemeMenu() {
  const theme = useTheme();
  const current = THEMES.find((t) => t.value === theme) ?? THEMES[0]!;
  const Icon = current.icon;
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" aria-label={`Theme: ${current.label}`}>
          <Icon />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {THEMES.map((t) => (
          <DropdownMenuItem key={t.value} onSelect={() => setTheme(t.value)}>
            <t.icon /> {t.label}
            {t.value === theme ? (
              <span className="ml-auto text-xs text-muted-foreground">current</span>
            ) : null}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/**
 * The sidebar with navigation, counts and saved views.
 *
 * @param props - Whether it is collapsed to icons.
 * @returns The element.
 */
function Sidebar({ collapsed }: { /** Show icons only. */ collapsed: boolean }) {
  const navigate = useNavigate();
  const board = useBoard("");
  const views = useViews();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const counts = useMemo(() => {
    const map = new Map<string, number>();
    for (const section of board.data?.sections ?? []) map.set(section.name, section.total);
    return map;
  }, [board.data]);
  const pinned = (views.data?.views ?? []).filter((v) => v.pinned);
  return (
    <nav
      aria-label="Main"
      className="flex h-full flex-col gap-0.5 overflow-y-auto border-r bg-sidebar p-2 text-sidebar-foreground"
    >
      {NAV.map((entry) => {
        const active = entry.to === "/" ? path === "/" : path === entry.to || path.startsWith(`${entry.to}/`);
        const count = entry.section ? counts.get(entry.section) : undefined;
        const link = (
          <Link
            key={entry.to}
            to={entry.to}
            className={cn(
              "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-sidebar-accent",
              active && "bg-sidebar-accent font-medium",
              entry.sub && !collapsed && "pl-6 text-[13px]",
            )}
            aria-current={active ? "page" : undefined}
          >
            <entry.icon className="size-4 shrink-0 opacity-80" aria-hidden />
            {collapsed ? (
              <span className="sr-only">{entry.label}</span>
            ) : (
              <span className="truncate">{entry.label}</span>
            )}
            {!collapsed && count !== undefined ? (
              <span className="ml-auto text-xs text-muted-foreground tabular-nums">{count}</span>
            ) : null}
          </Link>
        );
        return collapsed ? (
          <Tooltip key={entry.to} content={entry.label}>
            {link}
          </Tooltip>
        ) : (
          link
        );
      })}
      {!collapsed && pinned.length > 0 ? (
        <>
          <div className="mt-3 px-2 pb-1 text-xs font-medium text-muted-foreground">Saved views</div>
          {pinned.map((view) => (
            <a
              key={view.name}
              href={view.url}
              // Inside the app: navigate without a page load (a middle click still opens a tab).
              onClick={(event) => {
                if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey) return;
                event.preventDefault();
                void navigate({ href: view.url });
              }}
              className="truncate rounded-md px-2 py-1 text-[13px] hover:bg-sidebar-accent"
            >
              {view.name}
            </a>
          ))}
        </>
      ) : null}
      <div className="mt-auto pt-2">
        <Link
          to="/settings"
          className="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-sidebar-accent"
        >
          <CogIcon className="size-4" aria-hidden />
          {collapsed ? <span className="sr-only">Settings</span> : "Settings"}
        </Link>
      </div>
    </nav>
  );
}

/**
 * A full-page message that replaces the app (no session).
 *
 * @param props - Title and text.
 * @returns The element.
 */
export function FullPageMessage({
  title,
  children,
}: {
  /** Heading. */ title: string;
  /** Text. */ children: ReactNode;
}) {
  return (
    <main className="mx-auto mt-[15vh] max-w-lg px-6 text-center">
      <h1 className="text-lg font-semibold">{title}</h1>
      <div className="mt-2 text-sm text-muted-foreground">{children}</div>
    </main>
  );
}

/**
 * The layout of every page.
 *
 * @returns The element.
 */
export function Layout() {
  const navigate = useNavigate();
  const connected = useAppStore((s) => s.connected);
  const sessionLost = useAppStore((s) => s.sessionLost);
  const state = useAppStore((s) => s.state);
  const settings = useSettings();
  // Desktop notifications follow the stored settings from the start, on every page.
  useEffect(() => {
    if (settings.data) applyNotificationSettings(settings.data);
  }, [settings.data]);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  const shortcuts = useMemo<Shortcut[]>(
    () => [
      ...NAV.filter((e) => e.key).map((e) => ({
        keys: `g ${e.key}`,
        label: `Go to ${e.label}`,
        run: () => void navigate({ to: e.to }),
      })),
      { keys: "ctrl+k", label: "Command palette", run: () => setPaletteOpen(true), inFields: true },
      { keys: "?", label: "Keyboard shortcuts", run: () => setSheetOpen(true) },
      {
        keys: "c",
        label: "New item",
        run: () => void navigate({ to: "/new", search: { type: "", from: "" } }),
      },
      { keys: "/", label: "Focus the filter", run: () => document.getElementById("filter-box")?.focus() },
    ],
    [navigate],
  );
  useShortcuts(shortcuts, !paletteOpen);

  if (sessionLost) {
    return (
      <FullPageMessage title="The backlog app was restarted">
        This page belongs to an earlier start. Open the address the app printed in its terminal (or start it
        again with <code>bin/start-backlog-app.sh</code>, which opens a new one).
      </FullPageMessage>
    );
  }

  return (
    <div
      className={cn(
        "grid h-full grid-rows-[auto_1fr]",
        collapsed ? "grid-cols-[3.25rem_1fr]" : "grid-cols-[13.5rem_1fr]",
        "max-[899px]:grid-cols-[3.25rem_1fr]",
      )}
    >
      <header className="col-span-2 flex h-12 items-center gap-2 border-b bg-card px-3">
        <button
          type="button"
          className="flex items-center gap-2 rounded-md px-1 font-semibold"
          onClick={() => setCollapsed((c) => !c)}
          aria-label={collapsed ? "Expand the sidebar" : "Collapse the sidebar"}
        >
          <img src="/favicon.svg" alt="" className="size-6" />
          <span className="max-[899px]:hidden">Tandem backlog</span>
        </button>
        <div className="mx-2 min-w-0 flex-1">
          <LoopStatus />
        </div>
        {state ? (
          <Tooltip
            content={
              state.source === "main"
                ? "The backlog is read from main's commits (a run is active or the tree is not on main)"
                : "The backlog is read from the working tree"
            }
          >
            <Badge variant="outline" className="max-[1100px]:hidden">
              {state.repo.branch}
              {state.source === "main" ? " · reading main" : ""}
              {state.repo.ahead ? ` · +${state.repo.ahead} ahead` : ""}
            </Badge>
          </Tooltip>
        ) : null}
        <TrayButton />
        <Button
          variant="outline"
          size="sm"
          onClick={() => setPaletteOpen(true)}
          className="text-muted-foreground max-[700px]:hidden"
        >
          <SearchIcon /> Search or command <Kbd>Ctrl K</Kbd>
        </Button>
        <Button size="sm" onClick={() => void navigate({ to: "/new", search: { type: "", from: "" } })}>
          <PlusIcon /> <span className="max-[700px]:sr-only">New item</span>
        </Button>
        <ThemeMenu />
      </header>
      <Sidebar collapsed={collapsed} />
      <main className="flex min-h-0 min-w-0 flex-col overflow-y-auto">
        {!connected && state ? (
          <div role="status" className="border-b border-warn/50 bg-warn/10 px-4 py-1.5 text-sm">
            Connection to the app lost - retrying. Showing the last state; changes are disabled.
          </div>
        ) : null}
        <GateBanner />
        <Outlet />
      </main>
      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
      <ShortcutSheet open={sheetOpen} onOpenChange={setSheetOpen} shortcuts={shortcuts} />
    </div>
  );
}
