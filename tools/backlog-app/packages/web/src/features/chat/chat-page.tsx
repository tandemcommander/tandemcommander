// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The conversation with Claude about one item (feature 371, user story 4; FR-014 -
 * FR-020): opened in its own window without the app's frame, the item's essentials at the top,
 * the transcript below, a composer at the bottom. Replies stream in as they are produced (the
 * conversation stream); Claude's tool uses show as short lines; a reply can be stopped; the
 * transcript is kept on the server and shown again after a reload. Claude only reads.
 */

import { getRouteApi } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { LoaderIcon, MessageSquareTextIcon, SendIcon, SquareIcon, Trash2Icon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import type { ChatContext, Conversation, Turn } from "@backlog-app/shared";
import { SeverityBadge, StatusBadge, TypeBadge } from "@/components/badges.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Badge, Skeleton, Textarea } from "@/components/ui/primitives.tsx";
import { apiGet, apiPost, ApiFailure } from "@/lib/api.ts";
import { openStream } from "@/lib/sse.ts";
import { cn, relativeTime } from "@/lib/utils.ts";

/** The route. */
const route = getRouteApi("/items/$slug/chat");

/**
 * The conversation of an item.
 *
 * @param slug - The item.
 * @returns The query.
 */
function useConversation(slug: string) {
  return useQuery({
    queryKey: ["chat", slug],
    queryFn: ({ signal }) => apiGet<Conversation>(`/api/items/${slug}/chat`, signal),
  });
}

/**
 * The item's context.
 *
 * @param slug - The item.
 * @returns The query.
 */
function useChatContext(slug: string) {
  return useQuery({
    queryKey: ["chat", slug, "context"],
    queryFn: ({ signal }) => apiGet<ChatContext>(`/api/items/${slug}/chat/context`, signal),
  });
}

/** What the stream adds to the running turn. */
interface LiveTurn {
  /** The turn number. */
  turn: number;
  /** The text so far. */
  text: string;
  /** Progress lines so far. */
  progress: { at: string; text: string }[];
}

/**
 * Follows the stream of the running reply.
 *
 * @param slug - The item.
 * @param running - The running turn (from the transcript), or null.
 * @returns The live text and progress, or null.
 */
function useLiveTurn(slug: string, running: Turn | null): LiveTurn | null {
  const queryClient = useQueryClient();
  const [live, setLive] = useState<LiveTurn | null>(null);
  const runningId = running?.id ?? null;
  // A new running turn resets the live text to what the transcript has (adjusted during render,
  // not in the effect).
  const [liveOf, setLiveOf] = useState<number | null>(null);
  if (runningId !== liveOf) {
    setLiveOf(runningId);
    setLive(
      runningId === null
        ? null
        : { turn: runningId, text: running?.assistant ?? "", progress: running?.progress ?? [] },
    );
  }
  useEffect(() => {
    if (runningId === null) return;
    const close = openStream(`/api/items/${slug}/chat/stream`, {
      onEvent: ({ event, data }) => {
        const payload = data as { turn: number; text?: string; whole?: boolean; at?: string; error?: string };
        if (payload.turn !== runningId && event !== "ping") return;
        switch (event) {
          case "delta":
            setLive((l) =>
              l ? { ...l, text: payload.whole ? (payload.text ?? "") : l.text + (payload.text ?? "") } : l,
            );
            break;
          case "progress":
            setLive((l) =>
              l ? { ...l, progress: [...l.progress, { at: payload.at ?? "", text: payload.text ?? "" }] } : l,
            );
            break;
          case "done":
          case "failed":
            void queryClient.invalidateQueries({ queryKey: ["chat", slug] });
            break;
          default:
            break;
        }
      },
    });
    return close;
    // The transcript's running turn is the trigger; its fields are read once at the start.
  }, [slug, runningId, queryClient]);
  return live;
}

/**
 * The item's essentials.
 *
 * @param props - The context.
 * @returns The element.
 */
function Essentials({ context }: { /** The context. */ context: ChatContext }) {
  const { item } = context;
  const [open, setOpen] = useState(false);
  return (
    <header className="flex flex-col gap-2 border-b px-4 py-3" aria-label="The item">
      <div className="flex flex-wrap items-center gap-1.5">
        <TypeBadge type={item.type} />
        <SeverityBadge severity={item.severity} />
        <StatusBadge status={item.status} />
        <Badge variant="outline">{item.area}</Badge>
        {item.section ? (
          <Badge variant="outline">
            {item.section}
            {item.position ? ` #${item.position}` : ""}
          </Badge>
        ) : null}
        {context.running ? <Badge variant="primary">a run works on it now</Badge> : null}
      </div>
      <h1 className="text-lg font-semibold">
        {item.title} <span className="font-mono text-sm font-normal text-muted-foreground">{item.slug}</span>
      </h1>
      <dl className="grid grid-cols-[repeat(auto-fill,minmax(9rem,1fr))] gap-x-3 gap-y-1 text-sm">
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Who / effort</dt>
          <dd>
            {item.who} / {item.effort}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Source</dt>
          <dd>{item.source}</dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Created / updated</dt>
          <dd>
            {item.created} / {item.updated}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Feature</dt>
          <dd>
            {item.feature ?? "-"}
            {context.featureFolder ? ` (${context.featureFolder})` : ""}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Runs</dt>
          <dd>
            {context.runs.length === 0
              ? "none"
              : context.runs
                  .slice(0, 3)
                  .map((r) => `${r.outcome}${r.feature ? ` (${r.feature})` : ""}`)
                  .join(", ")}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Related / depends on</dt>
          <dd>{[...item.related, ...item.dependsOn].join(", ") || "none"}</dd>
        </div>
        <div>
          <dt className="text-[11px] text-muted-foreground uppercase">Claude reads</dt>
          <dd>branch {context.branch}</dd>
        </div>
      </dl>
      {item.reason ? <Alert tone="info">{item.reason}</Alert> : null}
      <button
        type="button"
        className="self-start text-xs text-primary hover:underline"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        {open ? "Hide the description" : "Show the description"}
      </button>
      {open ? (
        <div className="max-h-[40vh] overflow-y-auto rounded-md border p-3">
          {item.body
            .filter((s) => s.name !== "Log")
            .map((s) => (
              <section key={s.name}>
                <h3 className="mt-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                  {s.name}
                </h3>
                <Markdown>{s.markdown}</Markdown>
              </section>
            ))}
        </div>
      ) : null}
    </header>
  );
}

/**
 * One turn of the transcript.
 *
 * @param props - The turn and the live text when it is running.
 * @returns The element.
 */
function TurnView({ turn, live }: { /** The turn. */ turn: Turn; /** Live text. */ live: LiveTurn | null }) {
  const text = live && live.turn === turn.id ? live.text : turn.assistant;
  const progress = live && live.turn === turn.id ? live.progress : turn.progress;
  const [showProgress, setShowProgress] = useState(false);
  return (
    <li className="flex flex-col gap-2" aria-label={`Turn ${turn.id}`}>
      <div
        className="self-end rounded-lg bg-primary/10 px-3 py-2 text-sm whitespace-pre-wrap"
        aria-label="You"
      >
        {turn.user}
      </div>
      <div className="rounded-lg border px-3 py-2 text-sm" aria-label="Claude">
        {text ? <Markdown>{text}</Markdown> : null}
        {turn.state === "running" ? (
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <LoaderIcon className="size-3 animate-spin motion-reduce:animate-none" aria-hidden /> writing…
          </div>
        ) : null}
        {turn.error ? <Alert tone={turn.state === "stopped" ? "info" : "bad"}>{turn.error}</Alert> : null}
        {progress.length > 0 ? (
          <div className="mt-1">
            <button
              type="button"
              className="text-xs text-muted-foreground hover:underline"
              aria-expanded={showProgress}
              onClick={() => setShowProgress((s) => !s)}
            >
              {progress.length} tool use{progress.length === 1 ? "" : "s"}
            </button>
            {showProgress ? (
              <ul className="mt-1 max-h-40 overflow-y-auto font-mono text-xs text-muted-foreground">
                {progress.map((p, i) => (
                  <li key={`${p.at}-${i}`} className="truncate">
                    {p.text}
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : null}
        <div className="mt-1 text-[11px] text-muted-foreground">
          {relativeTime(turn.at)}
          {turn.costUsd !== null ? ` · $${turn.costUsd.toFixed(3)}` : ""}
        </div>
      </div>
    </li>
  );
}

/**
 * The conversation page.
 *
 * @returns The element.
 */
export function ChatPage() {
  const { slug } = route.useParams();
  const queryClient = useQueryClient();
  const conversation = useConversation(slug);
  const context = useChatContext(slug);
  const turns = conversation.data?.turns ?? [];
  const running = turns.find((t) => t.state === "running") ?? null;
  const live = useLiveTurn(slug, running);
  const [text, setText] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const bottom = useRef<HTMLDivElement>(null);
  useEffect(() => {
    document.title = context.data ? `Chat: ${context.data.item.title}` : "Chat";
  }, [context.data]);
  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [turns.length, live?.text.length]);

  const send = useMutation({
    mutationFn: (message: string) => apiPost<Turn>(`/api/items/${slug}/chat/messages`, { text: message }),
    onMutate: () => setProblem(null),
    onSuccess: () => {
      setText("");
      void queryClient.invalidateQueries({ queryKey: ["chat", slug] });
    },
    onError: (error) => setProblem(error instanceof ApiFailure ? error.message : String(error)),
  });
  const stop = useMutation({
    mutationFn: () => apiPost(`/api/items/${slug}/chat/stop`, {}),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["chat", slug] }),
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });
  const reset = useMutation({
    mutationFn: () => apiPost(`/api/items/${slug}/chat/reset`, {}),
    onSuccess: () => {
      toast.success("A new conversation");
      void queryClient.invalidateQueries({ queryKey: ["chat", slug] });
    },
    onError: (error) => toast.error(error instanceof ApiFailure ? error.message : String(error)),
  });

  /** Sends the composer's text. */
  const submit = (): void => {
    const message = text.trim();
    if (!message || running || send.isPending) return;
    send.mutate(message);
  };

  return (
    <div className="flex h-full flex-col bg-background text-foreground">
      {context.data ? (
        <Essentials context={context.data} />
      ) : context.error ? (
        <div className="p-4">
          <Alert tone="bad">{String(context.error)}</Alert>
        </div>
      ) : (
        <div className="flex flex-col gap-2 p-4">
          <Skeleton className="h-6 w-2/3" />
          <Skeleton className="h-16" />
        </div>
      )}
      <main className="flex-1 overflow-y-auto px-4 py-3" aria-label="The conversation">
        {conversation.isLoading ? <Skeleton className="h-20" /> : null}
        {turns.length === 0 && !conversation.isLoading ? (
          <p className="text-sm text-muted-foreground">
            <MessageSquareTextIcon className="mr-1 inline size-4" aria-hidden />
            Ask about this item: what to check first, which files it touches, what the last run did. Claude
            reads the repository and never changes anything.
          </p>
        ) : null}
        <ol className="flex flex-col gap-4">
          {turns.map((turn) => (
            <TurnView key={turn.id} turn={turn} live={live} />
          ))}
        </ol>
        <div ref={bottom} />
      </main>
      <footer className="flex flex-col gap-2 border-t px-4 py-3">
        {problem ? <Alert tone="bad">{problem}</Alert> : null}
        <form
          className="flex items-end gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            submit();
          }}
        >
          <Textarea
            aria-label="Your message"
            placeholder="Ask about this item… (Enter sends, Shift+Enter is a new line)"
            value={text}
            rows={3}
            className="flex-1"
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                submit();
              }
            }}
          />
          <div className="flex flex-col gap-1">
            {running ? (
              <Button type="button" variant="outline" disabled={stop.isPending} onClick={() => stop.mutate()}>
                <SquareIcon /> Stop
              </Button>
            ) : (
              <Button type="submit" disabled={!text.trim() || send.isPending}>
                <SendIcon /> Send
              </Button>
            )}
            <Button
              type="button"
              variant="ghost"
              size="sm"
              disabled={reset.isPending || turns.length === 0}
              onClick={() => reset.mutate()}
            >
              <Trash2Icon /> New conversation
            </Button>
          </div>
        </form>
        <p className={cn("text-xs text-muted-foreground")}>
          Claude only reads the repository (files and git history); nothing here changes the backlog.
          {conversation.data && conversation.data.costUsd > 0
            ? ` Cost so far $${conversation.data.costUsd.toFixed(2)}.`
            : ""}
        </p>
      </footer>
    </div>
  );
}
