// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file What the server knows about a run beyond its trace (feature 415,
 * `specs/415-live-run-dashboard/contracts/http-api.md`): the documents of its feature folder, the
 * decisions and assumptions recorded in its `spec.md`, the diagrams of its `plan.md`, the gallery
 * of screenshots, and the basis of the expected duration.
 *
 * Every file is read open-read-close and only on request (the page asks while a tab is shown). A
 * gallery image is served only from the list this module builds - images the run's own trace
 * opened or wrote, and images of its feature folder - and only when its real path lies inside the
 * repository or the system temporary folder: the page names an image by its number, never by a
 * path.
 */

import { createHash } from "node:crypto";
import { existsSync, lstatSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join, relative, resolve, sep } from "node:path";
import {
  ApiError,
  normalizeTraceLine,
  relativePath,
  RUN_DOCUMENTS,
  RunStory,
  type Decision,
  type RunImage,
  type RunInsight,
} from "@backlog-app/shared";
import type { Services } from "../services.ts";
import { readTraceLines } from "./tailer.ts";

/** Image types the gallery serves, by extension. */
export const IMAGE_TYPES: Readonly<Record<string, string>> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".bmp": "image/bmp",
  ".webp": "image/webp",
};

/** Largest image served. */
const MAX_IMAGE_BYTES = 25 * 1024 * 1024;

/** Most images listed from the feature folder. */
const MAX_FOLDER_IMAGES = 200;

/** Most folders walked in a feature folder. */
const MAX_FOLDERS = 300;

/** Largest document text served. */
const MAX_DOCUMENT_BYTES = 1024 * 1024;

/** How long an insight is reused (the page asks at most every 10 s; two tabs share it). */
const CACHE_MS = 4000;

/** Form of a feature branch (and of its spec folder). */
const FEATURE_BRANCH = /^\d{3}-[a-z0-9][a-z0-9.-]*$/;

/** An image of the list with its real path (never sent to the page). */
interface ListedImage extends RunImage {
  /** The real path. */
  real: string | null;
}

/** A cached insight. */
interface Cached {
  /** When it was built. */
  at: number;
  /** The insight. */
  insight: RunInsight;
  /** Its images with their real paths. */
  images: ListedImage[];
}

/**
 * Whether a path lies inside a folder (both real paths; case-insensitive on Windows; the folder's
 * own path counts as inside).
 *
 * @param child - A real path.
 * @param parent - A real folder path.
 * @returns True when inside.
 */
export function isInside(child: string, parent: string): boolean {
  /**
   * A path as compared: lower case on Windows.
   *
   * @param p - A path.
   * @returns The folded path.
   */
  const fold = (p: string): string => (process.platform === "win32" ? p.toLowerCase() : p);
  const c = fold(resolve(child));
  const p = fold(resolve(parent));
  if (c === p) return true;
  return c.startsWith(p.endsWith(sep) ? p : p + sep);
}

/**
 * The real path of an existing file, or null.
 *
 * @param path - Any path.
 * @returns The real path, or null when it does not exist.
 */
function real(path: string): string | null {
  try {
    return realpathSync.native(path);
  } catch {
    return null;
  }
}

/**
 * Parses the decisions of a spec: the `- Q: ... → A: ...` bullets of its *Clarifications*.
 *
 * @param text - The spec's text.
 * @returns The decisions.
 */
export function parseDecisions(text: string): Decision[] {
  const decisions: Decision[] = [];
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*-\s*Q:\s*(.+?)\s*(?:→|->)\s*A:\s*(.+)$/.exec(line);
    if (!m) continue;
    let answer = m[2]!.trim();
    let how = "";
    const tail = /\s*\((?:autonomous run:\s*)?([^()]*)\)\s*$/.exec(answer);
    if (tail && /autonomous run:/.test(tail[0])) {
      how = tail[1]!.trim();
      answer = answer.slice(0, tail.index).trim();
    }
    decisions.push({ question: m[1]!.trim(), answer, how });
  }
  return decisions;
}

/**
 * Parses the assumptions of a spec: the lines naming an `Assumption (autonomous run):`.
 *
 * @param text - The spec's text.
 * @returns The assumptions.
 */
export function parseAssumptions(text: string): string[] {
  const found: string[] = [];
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const m = /Assumption \(autonomous run\):\s*(.*)$/.exec(lines[i]!);
    if (!m) continue;
    // A bullet may go on over indented lines.
    let body = m[1]!.trim();
    for (let j = i + 1; j < lines.length && /^\s{2,}\S/.test(lines[j]!) && !/^\s*-\s/.test(lines[j]!); j++)
      body += ` ${lines[j]!.trim()}`;
    found.push(body);
  }
  return found;
}

/**
 * The diagrams of a plan: fenced blocks drawn with box or arrow characters, with the heading
 * above them.
 *
 * @param text - The plan's text.
 * @returns The diagrams.
 */
export function parseDiagrams(text: string): { title: string; text: string }[] {
  const diagrams: { title: string; text: string }[] = [];
  const lines = text.split(/\r?\n/);
  let heading = "Diagram";
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    const h = /^#{1,6}\s+(.*)$/.exec(line);
    if (h) {
      heading = h[1]!.trim();
      continue;
    }
    if (!/^```/.test(line)) continue;
    const body: string[] = [];
    let j = i + 1;
    for (; j < lines.length && !/^```/.test(lines[j]!); j++) body.push(lines[j]!);
    i = j;
    const block = body.join("\n");
    if (/[─│┌└├┐┘┤┬┴┼═║▶◀→←↓↑▼▲]|-->|==>/.test(block) && body.length >= 2)
      diagrams.push({ title: heading, text: block });
  }
  return diagrams.slice(0, 20);
}

/**
 * The median of numbers.
 *
 * @param values - The numbers.
 * @returns The median, or null for none.
 */
function median(values: number[]): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length >> 1;
  return sorted.length % 2 ? sorted[mid]! : (sorted[mid - 1]! + sorted[mid]!) / 2;
}

/** The insight service. */
export class RunInsightService {
  /** The server's services. */
  private readonly services: Services;

  /** Insights by run id. */
  private readonly cache = new Map<string, Cached>();

  /** Images of ended runs' traces, by id and trace size. */
  private readonly traceImages = new Map<string, { size: number; paths: string[] }>();

  /**
   * Creates the service.
   *
   * @param services - The server's services.
   */
  constructor(services: Services) {
    this.services = services;
  }

  /**
   * The repository root.
   *
   * @returns Its absolute path.
   */
  private get root(): string {
    return this.services.ctx.repo.root;
  }

  /**
   * The insight of a run.
   *
   * @param id - The run id (validated by the route).
   * @returns The insight.
   * @throws ApiError `not-found` for an unknown run.
   */
  async insight(id: string): Promise<RunInsight> {
    return (await this.build(id)).insight;
  }

  /**
   * Builds (or reuses) a run's insight.
   *
   * @param id - The run id.
   * @returns The cached insight with its images.
   * @throws ApiError `not-found` for an unknown run.
   */
  private async build(id: string): Promise<Cached> {
    const cached = this.cache.get(id);
    if (cached && Date.now() - cached.at < CACHE_MS) return cached;
    const live = this.services.runs.liveInsight();
    const isLive = live?.id === id;
    let branch: string | null;
    let tracePaths: string[];
    if (isLive) {
      branch = this.services.loop.view?.lock?.branch ?? null;
      tracePaths = live.story.images().map((i) => i.path);
    } else {
      const run = await this.services.runs.detail(id);
      branch = run.branch;
      tracePaths = run.hasTrace ? this.imagesOfTrace(id) : [];
    }
    if (branch && !FEATURE_BRANCH.test(branch)) branch = null;
    const folderRel = branch ? `specs/${branch}` : null;
    const folder =
      folderRel && existsSync(join(this.root, "specs", branch!)) ? join(this.root, "specs", branch!) : null;
    const documents: RunInsight["documents"] = [];
    let decisions: Decision[] = [];
    let assumptions: string[] = [];
    let diagrams: RunInsight["diagrams"] = [];
    if (folder) {
      for (const name of RUN_DOCUMENTS) {
        const file = `${name}.md`;
        try {
          const stat = statSync(join(folder, file));
          if (stat.isFile())
            documents.push({ name, file, size: stat.size, modified: stat.mtime.toISOString() });
        } catch {
          // Not written (yet).
        }
      }
      const spec = this.readText(join(folder, "spec.md"));
      if (spec) {
        decisions = parseDecisions(spec);
        assumptions = parseAssumptions(spec);
      }
      const plan = this.readText(join(folder, "plan.md"));
      if (plan) diagrams = parseDiagrams(plan);
    }
    const images = this.listImages(tracePaths, folder);
    const insight: RunInsight = {
      branch,
      featureFolder: folder ? folderRel : null,
      documents,
      decisions,
      assumptions,
      diagrams,
      images: images.map(({ real: _real, ...image }) => image),
      estimate: await this.estimate(),
    };
    const entry = { at: Date.now(), insight, images };
    this.cache.set(id, entry);
    if (this.cache.size > 20) this.cache.delete(this.cache.keys().next().value!);
    return entry;
  }

  /**
   * A document of a run's feature folder.
   *
   * @param id - The run id.
   * @param name - One of {@link RUN_DOCUMENTS}.
   * @returns Its text and modification time.
   * @throws ApiError `not-found` for an unknown name, a run without a folder, a missing file.
   */
  async document(id: string, name: string): Promise<{ name: string; text: string; modified: string }> {
    if (!(RUN_DOCUMENTS as readonly string[]).includes(name))
      throw new ApiError("not-found", "no such document");
    const { insight } = await this.build(id);
    const doc = insight.documents.find((d) => d.name === name);
    if (!insight.featureFolder || !doc) throw new ApiError("not-found", "the run has no such document");
    const path = join(this.root, insight.featureFolder, doc.file);
    let bytes: Buffer;
    try {
      bytes = readFileSync(path);
    } catch {
      throw new ApiError("not-found", "the document is gone");
    }
    let text: string;
    if (bytes.length > MAX_DOCUMENT_BYTES) {
      // Cut by bytes at the last line end before the limit (a whole line, never half a character).
      const head = bytes.subarray(0, MAX_DOCUMENT_BYTES);
      const end = head.lastIndexOf(0x0a);
      text = `${head.subarray(0, end > 0 ? end : MAX_DOCUMENT_BYTES).toString("utf8")}\n\n*(The rest of the document is not shown: it is larger than 1 MB.)*\n`;
    } else {
      text = bytes.toString("utf8");
    }
    let modified = doc.modified;
    try {
      modified = statSync(path).mtime.toISOString();
    } catch {
      // Keep the listed time.
    }
    return { name, text, modified };
  }

  /**
   * One image of a run's gallery.
   *
   * @param id - The run id.
   * @param key - Its key in the run's list.
   * @returns Its bytes and content type.
   * @throws ApiError `not-found` for a key outside the list, a vanished or refused file.
   */
  async image(id: string, key: string): Promise<{ bytes: Buffer; type: string }> {
    const { images } = await this.build(id);
    const image = images.find((i) => i.key === key);
    if (!image || !image.real) throw new ApiError("not-found", "no such image");
    // Checked again at the moment of reading: the file may have been replaced by a link since.
    const now = real(image.real);
    if (!now || !this.allowed(now)) throw new ApiError("not-found", "no such image");
    const type = IMAGE_TYPES[extname(now).toLowerCase()];
    if (!type) throw new ApiError("not-found", "no such image");
    let bytes: Buffer;
    try {
      const stat = statSync(now);
      if (!stat.isFile() || stat.size > MAX_IMAGE_BYTES) throw new Error("not a served file");
      bytes = readFileSync(now);
    } catch {
      throw new ApiError("not-found", "the image is gone");
    }
    return { bytes, type };
  }

  /**
   * Whether a real path may be served: inside the repository or the system temporary folder.
   *
   * @param path - A real path.
   * @returns True when allowed.
   */
  private allowed(path: string): boolean {
    const roots = [real(this.root), real(tmpdir())].filter((r): r is string => r !== null);
    return roots.some((r) => isInside(path, r)) && Boolean(IMAGE_TYPES[extname(path).toLowerCase()]);
  }

  /**
   * The gallery: the trace's images first (in order of use), then the feature folder's.
   *
   * @param tracePaths - Image paths the trace names.
   * @param folder - The feature folder, or null.
   * @returns The listed images.
   */
  private listImages(tracePaths: string[], folder: string | null): ListedImage[] {
    const list: ListedImage[] = [];
    const seen = new Set<string>();
    /**
     * Adds an image when it is allowed.
     *
     * @param path - The path as named.
     * @param source - Where it was found.
     */
    const add = (path: string, source: RunImage["source"]): void => {
      if (!IMAGE_TYPES[extname(path).toLowerCase()]) return;
      const absolute = resolve(this.root, path);
      const realPath = real(absolute);
      const key = (realPath ?? absolute).toLowerCase();
      if (seen.has(key)) return;
      // A file that is gone stays listed (the viewer says so); one outside the allowed places
      // is never listed.
      if (realPath && !this.allowed(realPath)) return;
      if (!realPath && !isInside(absolute, this.root) && !isInside(absolute, tmpdir())) return;
      seen.add(key);
      let size: number | null = null;
      let modified: string | null = null;
      if (realPath) {
        try {
          const stat = statSync(realPath);
          if (!stat.isFile()) return;
          size = stat.size;
          modified = stat.mtime.toISOString();
        } catch {
          // Gone between the checks.
        }
      }
      const rel = isInside(absolute, this.root)
        ? relative(this.root, absolute).replace(/\\/g, "/")
        : relativePath(absolute);
      const slash = rel.lastIndexOf("/");
      list.push({
        n: list.length,
        key: createHash("sha256").update(key).digest("hex").slice(0, 16),
        name: slash >= 0 ? rel.slice(slash + 1) : rel,
        where: slash >= 0 ? rel.slice(0, slash) : ".",
        source,
        size,
        modified,
        real: realPath,
      });
    };
    for (const path of tracePaths) add(path, "trace");
    if (folder) {
      const pending: { dir: string; depth: number }[] = [{ dir: folder, depth: 0 }];
      let found = 0;
      let visited = 0;
      while (pending.length > 0 && found < MAX_FOLDER_IMAGES) {
        const { dir, depth } = pending.shift()!;
        let names: string[];
        try {
          names = readdirSync(dir);
        } catch {
          continue;
        }
        for (const name of names.sort()) {
          const path = join(dir, name);
          if (IMAGE_TYPES[extname(name).toLowerCase()]) {
            const before = list.length;
            add(path, "feature");
            if (list.length > before) found++;
            if (found >= MAX_FOLDER_IMAGES) break;
          } else if (depth < 4 && visited < MAX_FOLDERS) {
            try {
              // Links and junctions are not followed: a junction to a drive's root would be
              // walked on every rebuild (its images would be refused anyway).
              const entry = lstatSync(path);
              if (entry.isDirectory() && !entry.isSymbolicLink()) {
                pending.push({ dir: path, depth: depth + 1 });
                visited++;
              }
            } catch {
              // Unreadable entry.
            }
          }
        }
      }
    }
    return list;
  }

  /**
   * The image paths an ended run's trace names (folded once per trace size).
   *
   * @param id - The run id.
   * @returns The paths.
   */
  private imagesOfTrace(id: string): string[] {
    const path = join(this.root, ".agent-traces", id, "trace.jsonl");
    let size: number;
    try {
      size = statSync(path).size;
    } catch {
      return [];
    }
    const known = this.traceImages.get(id);
    if (known && known.size === size) return known.paths;
    const story = new RunStory("item");
    let offset = 0;
    for (let i = 0; i < 100_000; i++) {
      const read = readTraceLines(path, offset);
      for (const line of read.lines)
        for (const event of normalizeTraceLine(line.text, line.offset, line.end)) story.apply(event);
      if (read.offset === offset) break;
      offset = read.offset;
    }
    const paths = story.images().map((i) => i.path);
    this.traceImages.set(id, { size, paths });
    return paths;
  }

  /**
   * The basis of the expected duration: the median of the last 40 closed item runs.
   *
   * @returns Median seconds (null with fewer than three) and the count.
   */
  async estimate(): Promise<RunInsight["estimate"]> {
    const runs = await this.services.runs.list({ outcome: "closed", kind: "item" });
    const durations = runs
      .filter((r) => typeof r.durationSeconds === "number" && r.durationSeconds > 60)
      .sort((a, b) => ((a.started ?? "") < (b.started ?? "") ? 1 : -1))
      .slice(0, 40)
      .map((r) => r.durationSeconds!);
    return { medianSeconds: durations.length >= 3 ? median(durations) : null, count: durations.length };
  }

  /**
   * Reads a text file open-read-close.
   *
   * @param path - The file.
   * @returns Its text, or null.
   */
  private readText(path: string): string | null {
    try {
      return readFileSync(path, "utf8");
    } catch {
      return null;
    }
  }
}
