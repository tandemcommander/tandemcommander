// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Changing routes of the backlog (contracts/http-api.md, *Backlog (change)* and *Change
 * tray*; user stories 3, 4 and 6).
 *
 * Every route validates its body with the shared schema, then runs inside the write queue: edit
 * lock, gate, revision check, the backlog tool with the user's texts on stdin, and a tray entry
 * with the files the tool wrote. The application never writes a backlog file itself, except the
 * undo of its own uncommitted change (FR-022).
 */

import { Hono, type Context } from "hono";
import {
  ApiError,
  BlockRequestSchema,
  BodyRequestSchema,
  BulkRequestSchema,
  CloseRequestSchema,
  CommitRequestSchema,
  ConfirmRequestSchema,
  DecideRequestSchema,
  ImportRequestSchema,
  LogRequestSchema,
  MoveRequestSchema,
  NewItemRequestSchema,
  OrderRequestSchema,
  ReplyRequestSchema,
  SetFieldsRequestSchema,
  StepRequestSchema,
  UnblockRequestSchema,
  UndoRequestSchema,
  VerifyRequestSchema,
  type Change,
  type ChangeResult,
  type SectionName,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { fileHash, type Base } from "../backlog/write-queue.ts";
import { resolveRef } from "../repo/git.ts";
import { join } from "node:path";
import { param, readBody, SLUG_PATTERN } from "./common.ts";

/** The tool's short name of each section (`--section`). */
export const SECTION_ARG: Record<SectionName, string> = {
  "In progress": "progress",
  Next: "next",
  "Decisions for the maintainer": "decisions",
  "Person steps": "person",
  Inbox: "inbox",
  Parked: "parked",
  Rejected: "rejected",
};

/** Body sections `body` may edit, by their names in the item format. */
const BODY_SECTIONS = new Set([
  "Problem",
  "Evidence",
  "Expected",
  "Approach",
  "Notes",
  "Question",
  "Options",
  "Recommendation",
  "Steps",
]);

/** One operation of the queue: what to run and how to describe it. */
interface Operation {
  /** Tray operation kind. */
  operation: Change["operation"];
  /** The tool's arguments (validated values only). */
  args: string[];
  /** Texts for `--input-json -`. */
  texts?: Record<string, unknown>;
  /** One line for the tray (`slug: Inbox -> Next #11`). */
  summary: string;
  /** The maintainer's reason. */
  reason?: string | null;
}

/**
 * Formats a header value for `set key=value` (lists as `a,b` or `[]`).
 *
 * @param value - The value.
 * @returns The text.
 */
function setValue(value: string | number | string[]): string {
  if (Array.isArray(value)) return value.length ? value.join(",") : "[]";
  return String(value);
}

/**
 * Creates the changing routes.
 *
 * @param services - The server's services.
 * @returns The routes, mounted under `/api`.
 */
export function backlogWriteRoutes(services: Services): Hono {
  const app = new Hono();
  const { queue, tray, tool } = services;

  /**
   * Runs one or more tool operations in the queue and records them in the tray.
   *
   * @param purpose - For the edit lock.
   * @param base - The view's revisions.
   * @param slug - The item of `base.item`.
   * @param operations - The operations, in order (a later one runs only if the earlier ones did).
   * @returns The answer of the route.
   */
  const apply = (
    purpose: string,
    base: Base,
    slug: string | null,
    operations: Operation[],
  ): Promise<ChangeResult> =>
    queue.run(purpose, base, slug, async () => {
      let last: Change | null = null;
      const findings: ChangeResult["findings"] = [];
      const notices: string[] = [];
      for (const op of operations) {
        const before = tray.snapshot();
        const result = await tool.change(op.args, op.texts ?? {});
        findings.push(...result.findings);
        notices.push(...result.notices);
        last = tray.record({
          operation: op.operation,
          slugs: result.slugs.length ? result.slugs : slug ? [slug] : [],
          summary: op.summary,
          reason: op.reason ?? null,
          before,
          written: result.written,
        });
        // A written change with check findings stops the chain: never build on a broken state.
        if (result.findings.length > 0) break;
      }
      const root = services.ctx.repo.root;
      const itemSlug = last?.slugs[0] ?? slug;
      return {
        ok: true,
        findings,
        notices,
        change: last,
        board: fileHash(join(root, "backlog", "BACKLOG.md")) ?? "",
        item: itemSlug ? fileHash(join(root, "backlog", "items", itemSlug, "desc.md")) : null,
      };
    });

  /**
   * The slug of the route.
   *
   * @param c - The request context.
   * @returns The validated slug.
   */
  const slugOf = (c: Context): string => param(c.req.param("slug"), SLUG_PATTERN, "item");

  // --- items (user story 3) ---
  app.post("/items/:slug/fields", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, SetFieldsRequestSchema);
    const pairs = Object.entries(body.set)
      .filter(([key]) => key !== "title")
      .map(([key, value]) => `${key}=${setValue(value)}`);
    const texts: Record<string, unknown> = {};
    if (typeof body.set["title"] === "string") texts["title"] = body.set["title"];
    if (body.reason) texts["log"] = body.reason;
    const changed = Object.keys(body.set).join(", ");
    return c.json(
      await apply(`set ${changed} of ${slug}`, body.base, slug, [
        {
          operation: "set",
          args: ["set", slug, ...pairs, ...(body.position ? ["--position", String(body.position)] : [])],
          texts,
          summary: `${slug}: set ${Object.entries(body.set)
            .map(([k, v]) => `${k}=${setValue(v)}`)
            .join(", ")}`,
          reason: body.reason ?? null,
        },
      ]),
    );
  });

  app.post("/items/:slug/move", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, MoveRequestSchema);
    const operation: Change["operation"] =
      body.section === "Parked" ? "park" : body.section === "Rejected" ? "reject" : "move";
    return c.json(
      await apply(`move ${slug} to ${body.section}`, body.base, slug, [
        {
          operation,
          args: [
            "move",
            slug,
            "--section",
            SECTION_ARG[body.section],
            ...(body.position ? ["--position", String(body.position)] : []),
          ],
          texts: body.reason ? { reason: body.reason } : {},
          summary: `${slug}: -> ${body.section}${body.position ? ` #${body.position}` : ""}`,
          reason: body.reason ?? null,
        },
      ]),
    );
  });

  app.post("/sections/:section/order", async (c) => {
    const name = Object.entries(SECTION_ARG).find(([, arg]) => arg === c.req.param("section"))?.[0] as
      SectionName | undefined;
    if (!name) throw new ApiError("not-found", "no such section");
    const body = await readBody(c, OrderRequestSchema);
    return c.json(
      await apply(`reorder ${name}`, body.base, null, [
        {
          operation: "reorder",
          args: ["reorder", "--section", SECTION_ARG[name]],
          texts: { order: body.order },
          summary: `${name} reordered`,
        },
      ]),
    );
  });

  app.post("/items/:slug/block", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, BlockRequestSchema);
    return c.json(
      await apply(`block ${slug}`, body.base, slug, [
        {
          operation: "block",
          args: ["block", slug],
          texts: { reason: body.reason },
          summary: `${slug}: blocked`,
          reason: body.reason,
        },
      ]),
    );
  });

  app.post("/items/:slug/unblock", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, UnblockRequestSchema);
    return c.json(
      await apply(`unblock ${slug}`, body.base, slug, [
        {
          operation: "unblock",
          args: ["unblock", slug],
          texts: body.note ? { note: body.note } : {},
          summary: `${slug}: unblocked`,
          reason: body.note ?? null,
        },
      ]),
    );
  });

  // --- items (user story 4) ---
  app.post("/items/:slug/close", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, CloseRequestSchema);
    return c.json(
      await apply(`close ${slug}`, body.base, slug, [
        {
          operation: "close",
          args: ["remove", slug],
          texts: { reason: body.reason },
          summary: `${slug}: closed`,
          reason: body.reason,
        },
      ]),
    );
  });

  app.post("/items/:slug/body/:section", async (c) => {
    const slug = slugOf(c);
    const section = c.req.param("section");
    if (!BODY_SECTIONS.has(section)) throw new ApiError("not-found", "no such body section");
    const body = await readBody(c, BodyRequestSchema);
    const texts: Record<string, unknown> = body.remove ? { remove: true } : { markdown: body.markdown ?? "" };
    if (body.log) texts["log"] = body.log;
    return c.json(
      await apply(`edit ${section} of ${slug}`, body.base, slug, [
        {
          operation: "body",
          args: ["body", slug, "--section", section],
          texts,
          summary: `${slug}: ${body.remove ? "removed" : "edited"} ${section}`,
          reason: body.log ?? null,
        },
      ]),
    );
  });

  app.post("/items/:slug/steps/:n", async (c) => {
    const slug = slugOf(c);
    const n = param(c.req.param("n"), /^[1-9]\d{0,2}$/, "step");
    const body = await readBody(c, StepRequestSchema);
    return c.json(
      await apply(`step ${n} of ${slug}`, body.base, slug, [
        {
          operation: "step",
          args: ["step", slug, n, body.done ? "--done" : "--undone"],
          texts: body.note ? { note: body.note } : {},
          summary: `${slug}: step ${n} ${body.done ? "done" : "reopened"}`,
          reason: body.note ?? null,
        },
      ]),
    );
  });

  app.post("/items/:slug/decide", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, DecideRequestSchema);
    const { then } = body;
    let action: string;
    switch (then.action) {
      case "move":
        if (!then.section) throw new ApiError("invalid-request", "a move needs a section");
        action = `move:${SECTION_ARG[then.section]}${then.position ? `@${then.position}` : ""}`;
        break;
      case "set-type":
        if (!then.type) throw new ApiError("invalid-request", "set-type needs a type");
        action = `set-type:${then.type}${then.who ? `,who:${then.who}` : ""}${then.position ? `@${then.position}` : ""}`;
        break;
      default:
        action = then.action;
    }
    const args = ["decide", slug, "--option", body.option, "--then", action];
    if (then.type && (then.action === "move" || then.action === "keep")) args.push("--type", then.type);
    return c.json(
      await apply(`decide ${slug}`, body.base, slug, [
        {
          operation: "decide",
          args,
          texts: { decision: body.decision },
          summary: `${slug}: decided ${body.option} (${action})`,
          reason: body.decision,
        },
      ]),
    );
  });

  app.post("/items/:slug/reply", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, ReplyRequestSchema);
    return c.json(
      await apply(`reply of ${slug}`, body.base, slug, [
        {
          operation: "reply",
          args: ["reply", slug, "--state", body.state],
          summary: `${slug}: reply ${body.state}`,
        },
      ]),
    );
  });

  app.post("/items/:slug/log", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, LogRequestSchema);
    return c.json(
      await apply(`log on ${slug}`, body.base, slug, [
        {
          operation: "log",
          args: ["log", slug],
          texts: { text: body.text },
          summary: `${slug}: log line`,
          reason: body.text,
        },
      ]),
    );
  });

  app.post("/items/:slug/verify", async (c) => {
    const slug = slugOf(c);
    const body = await readBody(c, VerifyRequestSchema);
    const main = await resolveRef(services.ctx.repo.root, "main");
    if (!main) throw new ApiError("refused", "there is no main branch to verify against");
    return c.json(
      await apply(`verify ${slug}`, body.base, slug, [
        {
          operation: "verify",
          args: ["verify", slug, "--commit", main.slice(0, 12)],
          texts: body.note ? { note: body.note } : {},
          summary: `${slug}: verified at ${main.slice(0, 8)}`,
          reason: body.note ?? null,
        },
      ]),
    );
  });

  app.post("/items", async (c) => {
    const body = await readBody(c, NewItemRequestSchema);
    const args = ["new", "--type", body.type, "--severity", String(body.severity), "--area", body.area];
    if (body.who) args.push("--who", body.who);
    if (body.effort) args.push("--effort", body.effort);
    if (body.source) args.push("--source", body.source);
    if (body.related?.length) args.push("--related", body.related.join(","));
    if (body.dependsOn?.length) args.push("--depends-on", body.dependsOn.join(","));
    if (body.slug) args.push("--slug", body.slug);
    const texts: Record<string, unknown> = { title: body.title };
    for (const key of [
      "problem",
      "evidence",
      "expected",
      "approach",
      "notes",
      "question",
      "options",
      "recommendation",
      "steps",
    ] as const) {
      if (body[key]) texts[key] = body[key];
    }
    // The new item is placed in a second operation, once its slug is known.
    const result = await queue.run(`new item ${body.title.slice(0, 40)}`, body.base, null, async () => {
      const before = tray.snapshot();
      const created = await tool.change(args, texts);
      const slug = created.slugs[0] ?? "";
      const change = tray.record({
        operation: "new",
        slugs: created.slugs,
        summary: `${slug}: created in Inbox`,
        reason: null,
        before,
        written: created.written,
      });
      let last = change;
      const findings = [...created.findings];
      const notices = [...created.notices];
      if (body.place && body.place.section !== "Inbox" && created.findings.length === 0) {
        const beforeMove = tray.snapshot();
        const moved = await tool.change([
          "move",
          slug,
          "--section",
          SECTION_ARG[body.place.section],
          ...(body.place.position ? ["--position", String(body.place.position)] : []),
        ]);
        findings.push(...moved.findings);
        notices.push(...moved.notices);
        last = tray.record({
          operation: "move",
          slugs: [slug],
          summary: `${slug}: -> ${body.place.section}${body.place.position ? ` #${body.place.position}` : ""}`,
          reason: null,
          before: beforeMove,
          written: moved.written,
        });
      }
      const root = services.ctx.repo.root;
      return {
        ok: true,
        findings,
        notices,
        change: last,
        board: fileHash(join(root, "backlog", "BACKLOG.md")) ?? "",
        item: fileHash(join(root, "backlog", "items", slug, "desc.md")),
      } satisfies ChangeResult;
    });
    return c.json(result);
  });

  app.post("/import-github", async (c) => {
    const body = await readBody(c, ImportRequestSchema);
    if ((body.number === undefined) === (body.label === undefined)) {
      throw new ApiError("invalid-request", "give either an issue number or a label");
    }
    const args = ["import-github"];
    if (body.number !== undefined) args.push(String(body.number));
    else args.push("--label", body.label!);
    if (body.area) args.push("--area", body.area);
    if (body.severity !== undefined) args.push("--severity", String(body.severity));
    if (body.type && body.number !== undefined) args.push("--type", body.type);
    if (body.dryRun) args.push("--dry-run");
    return c.json(
      await apply(`import GitHub ${body.number ?? body.label}`, body.base, null, [
        {
          operation: "import",
          args,
          summary: `imported GitHub ${body.number !== undefined ? `#${body.number}` : `label ${body.label}`}`,
        },
      ]),
    );
  });

  // --- bulk changes (user story 6) ---
  app.post("/bulk", async (c) => {
    const body = await readBody(c, BulkRequestSchema);
    const results: { slug: string; ok: boolean; refused?: string; findings?: unknown[] }[] = [];
    // One queued operation per item, each validated by the tool on its own.
    for (const slug of body.slugs) {
      const { operation } = body;
      let op: Operation;
      switch (operation.kind) {
        case "block":
          op = {
            operation: "block",
            args: ["block", slug],
            texts: { reason: operation.reason },
            summary: `${slug}: blocked`,
            reason: operation.reason,
          };
          break;
        case "unblock":
          op = {
            operation: "unblock",
            args: ["unblock", slug],
            texts: operation.note ? { note: operation.note } : {},
            summary: `${slug}: unblocked`,
          };
          break;
        case "move":
          op = {
            operation:
              operation.section === "Parked" ? "park" : operation.section === "Rejected" ? "reject" : "move",
            args: ["move", slug, "--section", SECTION_ARG[operation.section]],
            texts: operation.reason ? { reason: operation.reason } : {},
            summary: `${slug}: -> ${operation.section}`,
            reason: operation.reason ?? null,
          };
          break;
        case "set":
          op = {
            operation: "set",
            args: ["set", slug, ...Object.entries(operation.set).map(([k, v]) => `${k}=${setValue(v)}`)],
            texts: operation.reason ? { log: operation.reason } : {},
            summary: `${slug}: set ${Object.keys(operation.set).join(", ")}`,
            reason: operation.reason ?? null,
          };
          break;
      }
      try {
        const answer = await apply(`bulk ${operation.kind} ${slug}`, {}, slug, [op]);
        results.push({ slug, ok: true, findings: answer.findings });
      } catch (error) {
        results.push({ slug, ok: false, refused: error instanceof Error ? error.message : String(error) });
        if (error instanceof ApiError && error.code === "gate-closed") break;
      }
    }
    return c.json({ results });
  });

  // --- check fixes and the stale lock ---
  app.post("/check/sync", async (c) =>
    c.json(
      await apply("sync the overview", {}, null, [
        { operation: "sync", args: ["sync"], summary: "overview synced" },
      ]),
    ),
  );

  app.post("/lock/release-stale", async (c) => {
    const { confirm } = await readBody(c, ConfirmRequestSchema);
    const view = await services.loop.refresh();
    const lock = view?.lock;
    if (!lock) throw new ApiError("refused", "the run lock is free");
    if (!lock.stale)
      throw new ApiError(
        "refused",
        "the run lock is not stale (younger than 24 hours) - it belongs to a run",
      );
    if (view.live || view.orphanClaude)
      throw new ApiError("refused", "a loop or a claude of a run is still alive - the lock is in use");
    if (confirm !== lock.slug) throw new ApiError("refused", `type '${lock.slug}' to confirm`);
    const result = await services.tool.releaseStaleLock();
    await services.loop.refresh();
    services.publishGate();
    return c.json({ output: result });
  });

  // --- the change tray ---
  app.get("/tray", async (c) => c.json(await tray.view()));

  app.post("/tray/undo", async (c) => {
    const { changeId } = await readBody(c, UndoRequestSchema);
    const change = await queue.run("undo a change", null, null, () => Promise.resolve(tray.undo(changeId)));
    return c.json({ change });
  });

  app.post("/tray/commit", async (c) => {
    const body = await readBody(c, CommitRequestSchema);
    const hash = await queue.run("commit the change tray", null, null, () =>
      tray.commit(body.message, body.includeOutside),
    );
    return c.json({ commit: hash });
  });

  return app;
}
