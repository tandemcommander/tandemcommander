// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Editing one body section of an item (FR-031; analysis A4 §3.3): a Markdown source editor
 * (CodeMirror) with a preview, kept as a local draft while typing. The whole text goes to the
 * backlog tool on stdin; the tool validates the body before it writes. When the item changed on
 * disk meanwhile, saving is refused as "changed underneath" and the draft stays.
 */

import CodeMirror from "@uiw/react-codemirror";
import { markdown } from "@codemirror/lang-markdown";
import { EditorView } from "@codemirror/view";
import { useState } from "react";
import type { Item } from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Input, Label, NativeSelect } from "@/components/ui/primitives.tsx";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/overlays.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { Markdown } from "@/components/markdown.tsx";
import { useChange } from "@/lib/changes.ts";
import { hasDraft, useDraft } from "@/lib/drafts.ts";
import { isDark } from "@/lib/theme.ts";

/** The body sections that can be edited (not the log: it is appended by every change). */
const EDITABLE = [
  "Problem",
  "Evidence",
  "Expected",
  "Approach",
  "Notes",
  "Question",
  "Options",
  "Recommendation",
  "Steps",
];

/** Sections that may be removed (optional ones). */
const REMOVABLE = new Set(["Approach", "Notes"]);

/**
 * The editor dialog.
 *
 * @param props - The item, the section to start with, and the close handler.
 * @returns The element.
 */
export function SectionEditorDialog({
  item,
  initialSection,
  onClose,
}: {
  /** The item. */ item: Item;
  /** Section to open. */ initialSection?: string;
  /** Closes it. */ onClose: () => void;
}) {
  const [section, setSection] = useState(
    initialSection ?? item.body.find((b) => EDITABLE.includes(b.name))?.name ?? "Problem",
  );
  const stored = item.body.find((b) => b.name === section)?.markdown ?? "";
  const draftKey = `body:${item.slug}:${section}`;
  const restored = hasDraft(draftKey);
  const [text, setText, dropDraft] = useDraft(draftKey, stored);
  const [log, setLog] = useState("");
  const { mutation, problem } = useChange(() => {
    dropDraft();
    onClose();
  });
  /**
   * Saves or removes the section.
   *
   * @param remove - Remove an optional section instead of saving it.
   */
  const save = (remove: boolean): void => {
    mutation.mutate({
      path: `/api/items/${item.slug}/body/${encodeURIComponent(section)}`,
      body: {
        base: { item: item.revision },
        ...(remove ? { remove: true } : { markdown: text }),
        ...(log.trim() ? { log: log.trim() } : {}),
      },
    });
  };
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent title={`Edit ${item.title}`} wide className="max-w-5xl">
        <div className="flex items-end gap-2">
          <div className="w-56">
            <Label htmlFor="section">Section</Label>
            <NativeSelect id="section" value={section} onChange={(e) => setSection(e.target.value)}>
              {EDITABLE.map((name) => (
                <option key={name} value={name}>
                  {name}
                  {item.body.some((b) => b.name === name) ? "" : " (new)"}
                </option>
              ))}
            </NativeSelect>
          </div>
          {restored ? <span className="pb-1.5 text-xs text-info">Restored your unsaved draft.</span> : null}
        </div>
        <Tabs defaultValue="edit">
          <TabsList>
            <TabsTrigger value="edit">Markdown</TabsTrigger>
            <TabsTrigger value="preview">Preview</TabsTrigger>
          </TabsList>
          <TabsContent value="edit">
            <CodeMirror
              value={text}
              onChange={setText}
              height="45vh"
              theme={isDark() ? "dark" : "light"}
              extensions={[markdown(), EditorView.lineWrapping]}
              basicSetup={{ lineNumbers: false, foldGutter: false }}
              aria-label={`${section} in Markdown`}
            />
          </TabsContent>
          <TabsContent value="preview">
            <div className="max-h-[45vh] overflow-y-auto rounded-md border p-3">
              <Markdown>{text}</Markdown>
            </div>
          </TabsContent>
        </Tabs>
        <div>
          <Label htmlFor="body-log">Why (log line, optional)</Label>
          <Input
            id="body-log"
            value={log}
            onChange={(e) => setLog(e.target.value)}
            placeholder={`edited ${section}`}
          />
        </div>
        <ChangeProblemBox problem={problem} />
        <DialogFooter>
          {REMOVABLE.has(section) && item.body.some((b) => b.name === section) ? (
            <Button
              variant="destructive"
              className="mr-auto"
              disabled={mutation.isPending}
              onClick={() => save(true)}
            >
              Remove the section
            </Button>
          ) : null}
          <Button variant="outline" onClick={onClose}>
            Cancel (keep the draft)
          </Button>
          <Button disabled={mutation.isPending || text === stored} onClick={() => save(false)}>
            {mutation.isPending ? "Saving…" : "Save"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
