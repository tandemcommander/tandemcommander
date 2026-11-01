// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The context of a conversation about one item (feature 371, contracts/chat.md): the item
 * as the detail view has it, its runs and journal rows, the feature folder, the branch of the
 * working tree. Shown at the top of the conversation page and given to claude as data with the
 * first message.
 */

import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import type { ChatContext } from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { currentBranch, resolveRef } from "../repo/git.ts";

/**
 * The feature folder of an item's run (`specs/NNN-<slug>`), when one exists in the working
 * tree.
 *
 * @param root - The repository root.
 * @param feature - The feature number, or null.
 * @param slug - The item.
 * @returns The folder relative to the root, or null.
 */
function featureFolder(root: string, feature: string | null, slug: string): string | null {
  const specs = join(root, "specs");
  if (!existsSync(specs)) return null;
  const names = readdirSync(specs);
  const byNumber = feature ? names.find((n) => n.startsWith(`${feature}-`)) : undefined;
  const bySlug = names.find((n) => /^\d{3}-/.test(n) && n.slice(4) === slug);
  const found = byNumber ?? bySlug;
  return found ? `specs/${found}` : null;
}

/**
 * Builds the context of one item.
 *
 * @param services - The server's services.
 * @param slug - The item (validated, known to the board).
 * @returns The context.
 */
export async function buildChatContext(services: Services, slug: string): Promise<ChatContext> {
  const root = services.ctx.repo.root;
  const source = services.source();
  let item = await services.tool.show(slug, source);
  const running = services.running();
  if (running && running.slug === slug) {
    item = { ...item, section: "In progress", position: 1, status: "in-progress", feature: running.feature };
  }
  const runs = (await services.runs.list({ slug })).sort((a, b) =>
    (a.started ?? "") < (b.started ?? "") ? 1 : -1,
  );
  const journal = runs
    .filter((r) => r.id.startsWith("runs-md-") || r.branch || r.feature)
    .map((r) => [
      r.started ?? "-",
      r.slug ?? "-",
      r.outcome,
      r.feature ?? "-",
      r.branch ?? "-",
      r.note ?? "-",
    ]);
  const branch = services.repo.state?.branch ?? (await currentBranch(root).catch(() => "?"));
  return {
    item,
    runs: runs.slice(0, 20),
    journal,
    featureFolder: featureFolder(root, item.feature ?? running?.feature ?? null, slug),
    branch,
    running: running?.slug === slug,
  };
}

/**
 * The repository facts of the prompt.
 *
 * @param services - The server's services.
 * @returns Branch, HEAD and `main`.
 */
export async function repositoryFacts(
  services: Services,
): Promise<{ branch: string; head: string | null; main: string | null }> {
  const root = services.ctx.repo.root;
  const [branch, head, main] = await Promise.all([
    services.repo.state?.branch ?? currentBranch(root).catch(() => "?"),
    resolveRef(root, "HEAD"),
    resolveRef(root, "main"),
  ]);
  return { branch, head, main };
}
