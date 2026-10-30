// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The filter box of the backlog views (FR-007, research R20): one text field in the filter
 * language, quick chips for the common conditions, and the parts the server did not understand
 * shown under the box - never silently ignored. The query lives in the page address (FR-009).
 */

import { XIcon } from "lucide-react";
import { useEffect, useState } from "react";
import type { FilterError } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Input } from "@/components/ui/primitives.tsx";
import { cn } from "@/lib/utils.ts";

/** Conditions offered as one-click chips. */
const CHIPS: { label: string; term: string }[] = [
  { label: "agent-doable", term: "who:agent,both" },
  { label: "small", term: "effort:S" },
  { label: "sev ≥ 5", term: "sev>=5" },
  { label: "blocked", term: "is:blocked" },
  { label: "GitHub", term: "is:github" },
  { label: "not verified", term: "verified:none" },
];

/**
 * The filter box.
 *
 * @param props - The current query, its errors and the setter.
 * @returns The element.
 */
export function FilterBox({
  query,
  errors,
  matches,
  onChange,
}: {
  /** The query from the address. */
  query: string;
  /** Parts the server did not understand. */
  errors: FilterError[];
  /** Number of matching items. */
  matches: number | null;
  /** Called with the new query (typing pauses or Enter). */
  onChange: (query: string) => void;
}) {
  const [text, setText] = useState(query);
  const [shownQuery, setShownQuery] = useState(query);
  // The address may change from elsewhere (a saved view, the back button): adopt it during
  // render (React's pattern for state derived from a property), not in an effect.
  if (query !== shownQuery) {
    setShownQuery(query);
    setText(query);
  }
  // Apply the query 300 ms after typing stops; Enter applies at once.
  useEffect(() => {
    if (text === query) return;
    const timer = window.setTimeout(() => onChange(text), 300);
    return () => window.clearTimeout(timer);
  }, [text, query, onChange]);

  /**
   * Adds or removes a chip's term.
   *
   * @param term - The term.
   */
  const toggle = (term: string): void => {
    const terms = text.split(/\s+/).filter(Boolean);
    const next = terms.includes(term) ? terms.filter((t) => t !== term) : [...terms, term];
    setText(next.join(" "));
    onChange(next.join(" "));
  };

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center gap-2">
        <label htmlFor="filter-box" className="sr-only">
          Filter the backlog
        </label>
        <div className="relative min-w-0 flex-1">
          <Input
            id="filter-box"
            value={text}
            placeholder='Filter: area:encoding sev>=5 who:agent "code page"   ( / )'
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") onChange(text);
              if (e.key === "Escape") (e.target as HTMLInputElement).blur();
            }}
            aria-invalid={errors.length > 0}
            aria-describedby={errors.length ? "filter-errors" : undefined}
            className="pr-8 font-mono text-[13px]"
          />
          {text ? (
            <button
              type="button"
              aria-label="Clear the filter"
              className="absolute top-1/2 right-2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              onClick={() => {
                setText("");
                onChange("");
              }}
            >
              <XIcon className="size-4" />
            </button>
          ) : null}
        </div>
        {matches !== null && query ? (
          <span className="shrink-0 text-xs text-muted-foreground tabular-nums">
            {matches} match{matches === 1 ? "" : "es"}
          </span>
        ) : null}
      </div>
      <div className="flex flex-wrap gap-1">
        {CHIPS.map((chip) => {
          const on = text.split(/\s+/).includes(chip.term);
          return (
            <Button
              key={chip.term}
              size="sm"
              variant={on ? "secondary" : "ghost"}
              aria-pressed={on}
              className={cn("h-6 rounded-full border px-2 text-xs", on && "border-primary/40")}
              onClick={() => toggle(chip.term)}
            >
              {chip.label}
            </Button>
          );
        })}
      </div>
      {errors.length > 0 ? (
        <ul id="filter-errors" className="text-xs text-bad" role="alert">
          {errors.map((error) => (
            <li key={error.token}>
              <code>{error.token}</code>: {error.message}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
