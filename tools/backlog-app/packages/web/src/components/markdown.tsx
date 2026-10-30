// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Rendered Markdown of item descriptions, issue texts and feature records.
 *
 * Item and GitHub texts are untrusted data (analysis A1 §8): raw HTML is never rendered (it is
 * shown as text), links open in a new tab without a referrer, and remote images are not loaded -
 * the content security policy would block them anyway - but shown as links (contracts/security.md).
 * Words of the current search are highlighted.
 */

import ReactMarkdown, { type Components } from "react-markdown";
import remarkGfm from "remark-gfm";
import { Fragment, type ReactNode } from "react";
import { foldText } from "@backlog-app/shared";
import { cn } from "@/lib/utils.ts";

/**
 * Splits a text at the hits of the search words and marks them.
 *
 * @param text - The text.
 * @param words - Words to highlight.
 * @returns The text with `<mark>` around hits.
 */
export function highlight(text: string, words: readonly string[]): ReactNode {
  const needles = words.map((w) => foldText(w)).filter((w) => w.length > 1);
  if (needles.length === 0) return text;
  const folded = foldText(text);
  // Folding keeps lengths for the usual Latin text (accents are dropped after NFD decomposition
  // of single code points), so positions in the folded text index the original.
  if (folded.length !== text.length) return text;
  const parts: ReactNode[] = [];
  let at = 0;
  while (at < text.length) {
    let next = -1;
    let length = 0;
    for (const needle of needles) {
      const found = folded.indexOf(needle, at);
      if (found >= 0 && (next < 0 || found < next)) {
        next = found;
        length = needle.length;
      }
    }
    if (next < 0) break;
    if (next > at) parts.push(text.slice(at, next));
    parts.push(
      <mark key={next} className="hit">
        {text.slice(next, next + length)}
      </mark>,
    );
    at = next + length;
  }
  parts.push(text.slice(at));
  return parts.map((part, i) => <Fragment key={i}>{part}</Fragment>);
}

/** The element overrides of the renderer. */
const components: Components = {
  /**
   * Links open in a new tab without referrer; in-app paths stay in the tab.
   *
   * @param props - The anchor properties.
   * @returns The element.
   */
  a: ({ href, children }) => {
    const internal = typeof href === "string" && href.startsWith("/");
    return (
      <a href={href} {...(internal ? {} : { target: "_blank", rel: "noopener noreferrer" })}>
        {children}
      </a>
    );
  },
  /**
   * Images are never loaded: they are shown as links.
   *
   * @param props - The image properties.
   * @returns The element.
   */
  img: ({ src, alt }) => (
    <a href={typeof src === "string" ? src : undefined} target="_blank" rel="noopener noreferrer">
      [image: {alt || (typeof src === "string" ? src : "")}]
    </a>
  ),
};

/**
 * Rendered Markdown.
 *
 * @param props - The Markdown text and an optional class.
 * @returns The element.
 */
export function Markdown({
  children,
  className,
}: {
  /** Markdown text. */ children: string;
  /** Extra class. */ className?: string;
}) {
  return (
    <div className={cn("prose-backlog text-sm", className)}>
      {/* skipHtml: raw HTML in the text is dropped, never rendered. */}
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={components} skipHtml>
        {children}
      </ReactMarkdown>
    </div>
  );
}
