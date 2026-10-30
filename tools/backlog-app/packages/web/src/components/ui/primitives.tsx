// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Small styled primitives: badge, input, textarea, native select, label, card, skeleton,
 * separator, keyboard key, and an inline alert. Native form elements are used on purpose: they are
 * accessible and keyboard-friendly without extra code.
 */

import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils.ts";

/** The class variants of a badge. */
export const badgeVariants = cva(
  "inline-flex items-center gap-1 rounded-md border px-1.5 py-px text-xs font-medium whitespace-nowrap",
  {
    variants: {
      variant: {
        default: "border-transparent bg-secondary text-secondary-foreground",
        outline: "text-foreground",
        primary: "border-transparent bg-primary/12 text-primary",
      },
    },
    defaultVariants: { variant: "default" },
  },
);

/**
 * A badge (status, type, counters).
 *
 * @param props - Span properties and the variant.
 * @returns The element.
 */
export function Badge({
  className,
  variant,
  ...props
}: ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}

/** Shared look of text fields. */
const fieldClass =
  "w-full min-w-0 rounded-md border border-input bg-card px-2.5 py-1 text-sm shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/40 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive";

/**
 * A one-line text field.
 *
 * @param props - Input properties.
 * @returns The element.
 */
export function Input({ className, ...props }: ComponentProps<"input">) {
  return <input className={cn(fieldClass, "h-8", className)} {...props} />;
}

/**
 * A multi-line text field.
 *
 * @param props - Textarea properties.
 * @returns The element.
 */
export function Textarea({ className, ...props }: ComponentProps<"textarea">) {
  return (
    <textarea className={cn(fieldClass, "min-h-20 py-1.5 font-mono text-[13px]", className)} {...props} />
  );
}

/**
 * A native drop-down list.
 *
 * @param props - Select properties.
 * @returns The element.
 */
export function NativeSelect({ className, ...props }: ComponentProps<"select">) {
  return <select className={cn(fieldClass, "h-8 pr-7", className)} {...props} />;
}

/**
 * A form label.
 *
 * @param props - Label properties.
 * @returns The element.
 */
export function Label({ className, ...props }: ComponentProps<"label">) {
  return <label className={cn("text-xs font-medium text-muted-foreground", className)} {...props} />;
}

/**
 * A card: a bordered surface for a group of content.
 *
 * @param props - Div properties.
 * @returns The element.
 */
export function Card({ className, ...props }: ComponentProps<"div">) {
  return (
    <div className={cn("rounded-lg border bg-card text-card-foreground shadow-xs", className)} {...props} />
  );
}

/**
 * The title row of a card.
 *
 * @param props - Div properties.
 * @returns The element.
 */
export function CardHeader({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      className={cn("flex items-center justify-between gap-2 border-b px-4 py-2.5", className)}
      {...props}
    />
  );
}

/**
 * The title of a card.
 *
 * @param props - Heading properties.
 * @returns The element.
 */
export function CardTitle({ className, ...props }: ComponentProps<"h2">) {
  return <h2 className={cn("text-sm font-semibold", className)} {...props} />;
}

/**
 * A placeholder shown while content loads for the first time.
 *
 * @param props - Div properties.
 * @returns The element.
 */
export function Skeleton({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("animate-pulse rounded-md bg-muted", className)} aria-hidden {...props} />;
}

/**
 * A thin separating line.
 *
 * @param props - Div properties and the orientation.
 * @returns The element.
 */
export function Separator({
  className,
  orientation = "horizontal",
  ...props
}: ComponentProps<"div"> & {
  /** Horizontal (default) or vertical. */
  orientation?: "horizontal" | "vertical";
}) {
  return (
    <div
      role="separator"
      aria-orientation={orientation}
      className={cn(
        "shrink-0 bg-border",
        orientation === "horizontal" ? "h-px w-full" : "h-full w-px",
        className,
      )}
      {...props}
    />
  );
}

/**
 * A keyboard key in help texts.
 *
 * @param props - Kbd properties.
 * @returns The element.
 */
export function Kbd({ className, ...props }: ComponentProps<"kbd">) {
  return (
    <kbd
      className={cn(
        "inline-flex h-5 min-w-5 items-center justify-center rounded border bg-muted px-1 font-mono text-[11px] text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}

/** The class variants of an inline alert. */
const alertVariants = cva("flex gap-2 rounded-md border px-3 py-2 text-sm", {
  variants: {
    tone: {
      info: "border-info/40 bg-info/8",
      warn: "border-warn/50 bg-warn/10",
      bad: "border-bad/50 bg-bad/8",
      ok: "border-ok/40 bg-ok/8",
    },
  },
  defaultVariants: { tone: "info" },
});

/**
 * An inline message (refusals at a control, read-only banners, warnings).
 *
 * @param props - Div properties and the tone.
 * @returns The element.
 */
export function Alert({
  className,
  tone,
  ...props
}: ComponentProps<"div"> & VariantProps<typeof alertVariants>) {
  return (
    <div
      role={tone === "bad" ? "alert" : "status"}
      className={cn(alertVariants({ tone }), className)}
      {...props}
    />
  );
}
