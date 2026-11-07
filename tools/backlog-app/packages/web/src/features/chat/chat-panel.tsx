// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The conversation with Claude about one item as a component (feature 371, made reusable by
 * feature 415): the transcript, the running reply streaming in, the composer, stop and a new
 * conversation. The chat window of an item and the live run's dashboard show it; while the loop
 * works on the item the server gives every message a fresh snapshot of the run (feature 415),
 * and the dashboard offers ready questions. Claude only reads.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { LoaderIcon, MessageSquareTextIcon, SendIcon, SquareIcon, Trash2Icon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import type { ChatContext, Conversation, Turn } from "@backlog-app/shared";
import { Markdown } from "@/components/markdown.tsx";
import { Button } from "@/components/ui/button.tsx";
import { Alert, Skeleton, Textarea } from "@/components/ui/primitives.tsx";
import { apiGet, apiPost, ApiFailure } from "@/lib/api.ts";
import { openStream } from "@/lib/sse.ts";
import { cn, relativeTime } from "@/lib/utils.ts";

/**
 * The conversation of an item.
 *
 * @param slug - The item.
 * @returns The query.
 */
export function useConversation(slug: string) {
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
export function useChatContext(slug: string) {
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
 * The conversation: transcript, composer, stop and a new conversation.
 *
 * @param props - The item, an optional row of ready questions, an introduction and whether the
 *   panel is the narrow column of the dashboard.
 * @returns The element.
 */
export function ChatPanel({
  slug,
  questions = [],
  intro,
  compact = false,
}: {
  /** The item. */ slug: string;
  /** Ready questions sent with one click. */ questions?: readonly string[];
  /** Text shown before the first message. */ intro?: string;
  /** A narrow column (smaller composer). */ compact?: boolean;
}) {
  const queryClient = useQueryClient();
  const conversation = useConversation(slug);
  const turns = conversation.data?.turns ?? [];
  const running = turns.find((t) => t.state === "running") ?? null;
  const live = useLiveTurn(slug, running);
  const [text, setText] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const bottom = useRef<HTMLDivElement>(null);
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

  /**
   * Sends a message.
   *
   * @param value - The text (the composer's when omitted).
   */
  const submit = (value?: string): void => {
    const message = (value ?? text).trim();
    if (!message || running || send.isPending) return;
    send.mutate(message);
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex-1 overflow-y-auto px-4 py-3" role="log" aria-label="The conversation">
        {conversation.isLoading ? <Skeleton className="h-20" /> : null}
        {turns.length === 0 && !conversation.isLoading ? (
          <p className="text-sm text-muted-foreground">
            <MessageSquareTextIcon className="mr-1 inline size-4" aria-hidden />
            {intro ??
              "Ask about this item: what to check first, which files it touches, what the last run did. Claude reads the repository and never changes anything."}
          </p>
        ) : null}
        <ol className="flex flex-col gap-4">
          {turns.map((turn) => (
            <TurnView key={turn.id} turn={turn} live={live} />
          ))}
        </ol>
        <div ref={bottom} />
      </div>
      <div className="flex flex-col gap-2 border-t px-4 py-3">
        {questions.length > 0 ? (
          <div className="flex flex-wrap gap-1.5" aria-label="Ready questions">
            {questions.map((q) => (
              <button
                key={q}
                type="button"
                disabled={Boolean(running) || send.isPending}
                onClick={() => submit(q)}
                className="rounded-full border border-primary/40 bg-primary/8 px-2.5 py-0.5 text-xs text-primary hover:bg-primary/15 disabled:opacity-50"
              >
                {q}
              </button>
            ))}
          </div>
        ) : null}
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
            placeholder={
              compact
                ? "Ask about the run… (Enter sends)"
                : "Ask about this item… (Enter sends, Shift+Enter is a new line)"
            }
            value={text}
            rows={compact ? 2 : 3}
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
              <Trash2Icon /> {compact ? "New" : "New conversation"}
            </Button>
          </div>
        </form>
        <p className={cn("text-xs text-muted-foreground")}>
          Claude only reads the repository (files and git history); nothing here changes the backlog.
          {conversation.data && conversation.data.costUsd > 0
            ? ` Cost so far $${conversation.data.costUsd.toFixed(2)}.`
            : ""}
        </p>
      </div>
    </div>
  );
}
