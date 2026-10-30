// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file A link to an in-app address that is only known as text (a saved view's URL, the link of a
 * notification): a plain click navigates inside the app, without a page load that would drop the
 * page's state (marks, skipped triage items) and reconnect the event stream; a middle or modified
 * click still opens a new tab. Typed routes use the router's `Link` instead.
 */

import { useNavigate } from "@tanstack/react-router";
import type { ReactNode } from "react";

/**
 * The link.
 *
 * @param props - The in-app address, the class and the content.
 * @returns The element.
 */
export function AppLink({
  href,
  className,
  children,
}: {
  /** An address inside the app (`/backlog/next?q=...`). */
  href: string;
  /** Classes of the anchor. */
  className?: string;
  /** The content. */
  children: ReactNode;
}) {
  const navigate = useNavigate();
  return (
    <a
      href={href}
      className={className}
      onClick={(event) => {
        if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey) return;
        event.preventDefault();
        void navigate({ href });
      }}
    >
      {children}
    </a>
  );
}
