// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The gallery of a run (feature 415, FR-007): the screenshots the run looked at or produced
 * and those of its feature folder, as thumbnails; one opens a full-screen viewer with swipe,
 * arrow keys, Escape, a thumbnail strip, its name and where it came from. Images are fetched with
 * the session token and shown as object URLs (contracts/http-api.md); the page names an image by
 * its number only.
 */

import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ImageOffIcon,
  ImagesIcon,
  Maximize2Icon,
  XIcon,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import type { RunImage } from "@backlog-app/shared";
import { Skeleton } from "@/components/ui/primitives.tsx";
import { cn, formatBytes, relativeTime } from "@/lib/utils.ts";
import { useImageUrl } from "./use-run-insight.ts";

/**
 * One image (thumbnail or full size), loaded with the token.
 *
 * @param props - The run, the image, the classes and the alternative text.
 * @returns The element.
 */
function RunPicture({
  runId,
  image,
  className,
  fit = "cover",
}: {
  /** The run. */ runId: string;
  /** The image. */ image: RunImage;
  /** Classes of the picture. */ className?: string;
  /** How it fills its box. */ fit?: "cover" | "contain" | "none";
}) {
  const url = useImageUrl(runId, image.size === null ? null : image.key, image.modified);
  if (image.size === null || url === "gone") {
    return (
      <div
        className={cn(
          "flex flex-col items-center justify-center gap-1 bg-muted text-xs text-muted-foreground",
          className,
        )}
      >
        <ImageOffIcon className="size-5" aria-hidden />
        the file is gone
      </div>
    );
  }
  if (url === null) return <Skeleton className={className} />;
  return (
    <img
      src={url}
      alt={`${image.name} (${image.where})`}
      className={cn(
        className,
        fit === "cover" && "object-cover object-top",
        fit === "contain" && "object-contain",
        fit === "none" && "object-none",
      )}
      draggable={false}
    />
  );
}

/**
 * The full-screen viewer.
 *
 * @param props - The run, the images, the open index and how to change it.
 * @returns The element.
 */
function Viewer({
  runId,
  images,
  index,
  onIndex,
  onClose,
}: {
  /** The run. */ runId: string;
  /** The images. */ images: RunImage[];
  /** The image shown. */ index: number;
  /** Shows another image. */ onIndex: (i: number) => void;
  /** Closes the viewer. */ onClose: () => void;
}) {
  const image = images[index]!;
  const [actual, setActual] = useState(false);
  const start = useRef<{ x: number; y: number } | null>(null);
  const dialog = useRef<HTMLDivElement>(null);
  const strip = useRef<HTMLDivElement>(null);
  /**
   * Moves by a step, wrapping around.
   *
   * @param step - +1 or -1.
   */
  const go = (step: number): void => {
    setActual(false);
    onIndex((index + step + images.length) % images.length);
  };
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    dialog.current?.focus();
    return () => previous?.focus();
  }, []);
  useEffect(() => {
    strip.current
      ?.querySelector<HTMLElement>(`[data-n="${index}"]`)
      ?.scrollIntoView({ block: "nearest", inline: "center" });
  }, [index]);
  return createPortal(
    <div
      ref={dialog}
      role="dialog"
      aria-modal="true"
      aria-label={`Screenshot ${index + 1} of ${images.length}: ${image.name}`}
      tabIndex={-1}
      className="fixed inset-0 z-50 flex flex-col bg-black/92 text-white outline-none"
      onKeyDown={(e) => {
        if (e.key === "Tab") {
          // Focus stays in the viewer while it is open (a modal dialog).
          const items = [...(dialog.current?.querySelectorAll<HTMLElement>("button") ?? [])];
          const first = items[0];
          const last = items[items.length - 1];
          if (first && last && e.shiftKey && document.activeElement === first) {
            e.preventDefault();
            last.focus();
          } else if (first && last && !e.shiftKey && document.activeElement === last) {
            e.preventDefault();
            first.focus();
          } else if (first && document.activeElement === dialog.current) {
            e.preventDefault();
            first.focus();
          }
        } else if (e.key === "Escape") {
          e.preventDefault();
          onClose();
        } else if (e.key === "ArrowRight") {
          e.preventDefault();
          go(1);
        } else if (e.key === "ArrowLeft") {
          e.preventDefault();
          go(-1);
        } else if (e.key === "Home") {
          onIndex(0);
        } else if (e.key === "End") {
          onIndex(images.length - 1);
        }
      }}
    >
      <div className="flex items-center gap-3 px-4 py-2 text-sm">
        <span className="font-semibold">{image.name}</span>
        <span className="truncate text-white/70">{image.where}</span>
        <span className="rounded-full bg-white/15 px-2 text-xs">
          {image.source === "trace" ? "the run looked at it" : "feature folder"}
        </span>
        <span className="text-xs text-white/70">
          {image.size !== null ? formatBytes(image.size) : ""}{" "}
          {image.modified ? `· ${relativeTime(image.modified)}` : ""}
        </span>
        <span className="ml-auto text-xs text-white/70 tabular-nums">
          {index + 1} / {images.length}
        </span>
        <button
          type="button"
          className="rounded p-1 hover:bg-white/15"
          aria-label={actual ? "Fit to the window" : "Actual size"}
          onClick={() => setActual((a) => !a)}
        >
          <Maximize2Icon className="size-4" />
        </button>
        <button
          type="button"
          className="rounded p-1 hover:bg-white/15"
          aria-label="Close the viewer"
          onClick={onClose}
        >
          <XIcon className="size-5" />
        </button>
      </div>
      <div
        className={cn(
          "relative flex min-h-0 flex-1 touch-pan-y items-center justify-center select-none",
          actual ? "overflow-auto" : "overflow-hidden",
        )}
        onPointerDown={(e) => {
          start.current = { x: e.clientX, y: e.clientY };
        }}
        onPointerUp={(e) => {
          const from = start.current;
          start.current = null;
          if (!from) return;
          const dx = e.clientX - from.x;
          // A horizontal swipe of 50 px or more turns the page; a tap does nothing.
          if (Math.abs(dx) >= 50 && Math.abs(dx) > Math.abs(e.clientY - from.y)) go(dx < 0 ? 1 : -1);
        }}
        aria-label="Swipe left or right, or use the arrow keys"
      >
        <RunPicture
          key={image.n}
          runId={runId}
          image={image}
          fit={actual ? "none" : "contain"}
          // Fitted, a picture is made smaller to fit, never larger than it is (a small capture
          // stays sharp).
          className={actual ? "max-w-none" : "max-h-full max-w-full"}
        />
        {images.length > 1 ? (
          <>
            <button
              type="button"
              aria-label="Previous screenshot"
              onClick={() => go(-1)}
              className="absolute top-1/2 left-3 -translate-y-1/2 rounded-full bg-black/50 p-2 hover:bg-black/75"
            >
              <ChevronLeftIcon className="size-6" />
            </button>
            <button
              type="button"
              aria-label="Next screenshot"
              onClick={() => go(1)}
              className="absolute top-1/2 right-3 -translate-y-1/2 rounded-full bg-black/50 p-2 hover:bg-black/75"
            >
              <ChevronRightIcon className="size-6" />
            </button>
          </>
        ) : null}
      </div>
      <div ref={strip} className="flex gap-2 overflow-x-auto px-4 py-2" aria-label="All screenshots">
        {images.map((img, i) => (
          <button
            key={img.n}
            type="button"
            data-n={i}
            aria-label={`Show ${img.name}`}
            aria-current={i === index ? "true" : undefined}
            onClick={() => onIndex(i)}
            className={cn(
              "h-14 w-20 shrink-0 overflow-hidden rounded border-2",
              i === index ? "border-white" : "border-transparent opacity-60 hover:opacity-100",
            )}
          >
            <RunPicture runId={runId} image={img} className="h-full w-full" />
          </button>
        ))}
      </div>
    </div>,
    document.body,
  );
}

/**
 * The gallery tab.
 *
 * @param props - The run and its images.
 * @returns The element.
 */
export function Gallery({
  runId,
  images,
}: {
  /** The run. */ runId: string;
  /** The images. */ images: RunImage[];
}) {
  const [open, setOpen] = useState<number | null>(null);
  if (images.length === 0) {
    return (
      <p className="flex items-center gap-2 rounded-lg border p-4 text-sm text-muted-foreground">
        <ImagesIcon className="size-5" aria-hidden /> No screenshots yet. A run shows here every image it
        looks at or saves (probe captures, evidence) and the images of its feature folder.
      </p>
    );
  }
  return (
    <>
      <ul
        className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6"
        aria-label="Screenshots"
      >
        {images.map((image, i) => (
          <li key={image.n}>
            <button
              type="button"
              onClick={() => setOpen(i)}
              className="group flex w-full flex-col overflow-hidden rounded-lg border bg-card text-left hover:border-primary"
              aria-label={`Open ${image.name}`}
            >
              <RunPicture
                runId={runId}
                image={image}
                className="aspect-video w-full transition-transform group-hover:scale-[1.02]"
              />
              <span className="truncate px-2 pt-1 text-xs font-medium">{image.name}</span>
              <span className="truncate px-2 pb-1.5 text-[11px] text-muted-foreground">
                {image.where} · {image.source === "trace" ? "looked at by the run" : "feature folder"}
              </span>
            </button>
          </li>
        ))}
      </ul>
      {open !== null && images[open] ? (
        <Viewer runId={runId} images={images} index={open} onIndex={setOpen} onClose={() => setOpen(null)} />
      ) : null}
    </>
  );
}
