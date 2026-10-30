// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The change dialogs of an item (user stories 3 and 4; analysis A4 §4.5): move, reasons
 * (block, park, reject, reopen, close), fields, log line, verification, decision and person-step
 * results. Every dialog sends the item's revision as its base, shows a refusal at the dialog with
 * the tool's words, and keeps what was typed when the item changed underneath.
 */

import { useState, type FormEvent, type ReactNode } from "react";
import {
  SECTION_NAMES,
  ORDERED_SECTIONS,
  type Item,
  type Legend,
  type SectionName,
} from "@backlog-app/shared";
import { Button } from "@/components/ui/button.tsx";
import { Input, Label, NativeSelect } from "@/components/ui/primitives.tsx";
import { Dialog, DialogContent, DialogFooter } from "@/components/ui/overlays.tsx";
import { ChangeProblemBox } from "@/components/change-problem.tsx";
import { useChange } from "@/lib/changes.ts";
import { useDraft } from "@/lib/drafts.ts";

/** Kinds of dialogs the action bar opens. */
export type DialogKind =
  | "move"
  | "block"
  | "unblock"
  | "park"
  | "reject"
  | "reopen"
  | "close"
  | "fields"
  | "log"
  | "verify"
  | "decide"
  | "steps"
  | "reply";

/** Common properties of the dialogs. */
interface DialogProps {
  /** The item. */
  item: Item;
  /** The board revision (moves). */
  boardRevision: string | null;
  /** The legend (field values). */
  legend: Legend | null;
  /** Closes the dialog. */
  onClose: () => void;
}

/** Hints of the reason fields (analysis A4 §4.5). */
const REASON_HINT: Partial<Record<DialogKind, string>> = {
  block: "What does it wait for? (one line)",
  park: "What would bring it back? (one line)",
  reject: "Why not - so a future reader can judge whether a new argument is new (one line)",
  reopen: "The new reason - it must answer something the old one did not (one line)",
  close:
    "Why it is closed: fixed by which feature or commit, or why obsolete (one line; also in the commit message)",
};

/**
 * A dialog shell with a form, the problem box and the submit button.
 *
 * @param props - Title, description, the submit handler, pending state, problem and fields.
 * @returns The element.
 */
function FormDialog({
  title,
  description,
  onSubmit,
  pending,
  problem,
  submitLabel,
  destructive = false,
  onClose,
  children,
  wide = false,
}: {
  /** Dialog title. */
  title: string;
  /** Line under the title. */
  description?: ReactNode;
  /** Called on submit. */
  onSubmit: () => void;
  /** A submit is running. */
  pending: boolean;
  /** The last problem. */
  problem: Parameters<typeof ChangeProblemBox>[0]["problem"];
  /** Text of the submit button. */
  submitLabel: string;
  /** Red submit button. */
  destructive?: boolean;
  /** Closes the dialog. */
  onClose: () => void;
  /** The fields. */
  children: ReactNode;
  /** A wide dialog. */
  wide?: boolean;
}) {
  /**
   * Submits once.
   *
   * @param event - The form event.
   */
  const submit = (event: FormEvent): void => {
    event.preventDefault();
    if (!pending) onSubmit();
  };
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent title={title} description={description} wide={wide}>
        <form
          onSubmit={submit}
          onKeyDown={(e) => {
            // requestSubmit runs the form's own checks (a required reason) like the button does.
            if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
              e.preventDefault();
              e.currentTarget.requestSubmit();
            }
          }}
          className="flex flex-col gap-3"
        >
          {children}
          <ChangeProblemBox problem={problem} />
          <DialogFooter>
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant={destructive ? "destructive" : "default"} disabled={pending}>
              {pending ? "Working…" : submitLabel}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * The dependents of an item, listed before a park, reject or close.
 *
 * @param props - The item.
 * @returns The element, or nothing.
 */
function Dependents({ item }: { /** The item. */ item: Item }) {
  if (item.dependents.length === 0) return null;
  return (
    <p className="rounded-md border border-warn/50 bg-warn/10 px-2 py-1.5 text-sm">
      {item.dependents.length} item(s) depend on this one: {item.dependents.join(", ")}. The tool logs the
      change in them.
    </p>
  );
}

/**
 * Move to a section and position.
 *
 * @param props - See {@link DialogProps}.
 * @returns The element.
 */
export function MoveDialog({ item, boardRevision, onClose }: DialogProps) {
  const { mutation, problem } = useChange(onClose);
  const [section, setSection] = useState<SectionName>(
    item.section === "Inbox" ? "Next" : (item.section ?? "Next"),
  );
  const [position, setPosition] = useState("");
  const [reason, setReason] = useDraft(`move-reason:${item.slug}`, "");
  const reopening = (item.status === "parked" || item.status === "rejected") && section !== item.section;
  const needsReason = section === "Parked" || section === "Rejected" || reopening;
  const ordered = ORDERED_SECTIONS.includes(section);
  return (
    <FormDialog
      title={`Move ${item.title}`}
      description={`Now in ${item.section ?? "?"}${item.position ? ` at #${item.position}` : ""}.`}
      pending={mutation.isPending}
      problem={problem}
      submitLabel="Move"
      onClose={onClose}
      onSubmit={() =>
        mutation.mutate({
          path: `/api/items/${item.slug}/move`,
          body: {
            // A position counts rows: then the board must be the one the user saw.
            base: {
              ...(ordered && position ? { board: boardRevision ?? undefined } : {}),
              item: item.revision,
            },
            section,
            ...(ordered && position ? { position: Number(position) } : {}),
            ...(needsReason ? { reason: reason.trim() } : {}),
          },
        })
      }
    >
      <div className="grid grid-cols-[1fr_8rem] gap-2">
        <div>
          <Label htmlFor="move-section">Section</Label>
          <NativeSelect
            id="move-section"
            value={section}
            onChange={(e) => setSection(e.target.value as SectionName)}
          >
            {SECTION_NAMES.filter((s) => s !== "In progress").map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </NativeSelect>
        </div>
        <div>
          <Label htmlFor="move-position">Position</Label>
          <Input
            id="move-position"
            type="number"
            min={1}
            value={position}
            disabled={!ordered}
            placeholder={ordered ? "end" : "sorted"}
            onChange={(e) => setPosition(e.target.value)}
          />
        </div>
      </div>
      {needsReason ? (
        <div>
          <Label htmlFor="move-reason">{reopening ? "New reason (required)" : "Reason (required)"}</Label>
          <Input
            id="move-reason"
            value={reason}
            required
            onChange={(e) => setReason(e.target.value)}
            placeholder={REASON_HINT[reopening ? "reopen" : section === "Parked" ? "park" : "reject"]}
          />
          {reopening && item.reason ? (
            <p className="mt-1 text-xs text-muted-foreground">Old reason: {item.reason}</p>
          ) : null}
        </div>
      ) : null}
      {section === "Parked" || section === "Rejected" ? <Dependents item={item} /> : null}
    </FormDialog>
  );
}

/**
 * A change that needs one reason: block, park, reject, reopen, close; and unblock with an optional
 * note.
 *
 * @param props - See {@link DialogProps} and the kind.
 * @returns The element.
 */
export function ReasonDialog({
  item,
  onClose,
  kind,
}: DialogProps & { /** The change. */ kind: "block" | "unblock" | "park" | "reject" | "reopen" | "close" }) {
  const { mutation, problem } = useChange(onClose);
  const [reason, setReason] = useDraft(`${kind}-reason:${item.slug}`, "");
  // These changes do not depend on the order of rows: the item's revision is the whole base. (The
  // board's revision would refuse a change right after the user's own previous change, before the
  // page has re-read the board.)
  const base = { item: item.revision };
  const titles: Record<typeof kind, string> = {
    block: "Block",
    unblock: "Unblock",
    park: "Park",
    reject: "Reject",
    reopen: "Reopen",
    close: "Close",
  };
  /** Sends the change. */
  const submit = (): void => {
    const text = reason.trim();
    switch (kind) {
      case "block":
        mutation.mutate({ path: `/api/items/${item.slug}/block`, body: { base, reason: text } });
        break;
      case "unblock":
        mutation.mutate({
          path: `/api/items/${item.slug}/unblock`,
          body: { base, ...(text ? { note: text } : {}) },
        });
        break;
      case "park":
        mutation.mutate({
          path: `/api/items/${item.slug}/move`,
          body: { base, section: "Parked", reason: text },
        });
        break;
      case "reject":
        mutation.mutate({
          path: `/api/items/${item.slug}/move`,
          body: { base, section: "Rejected", reason: text },
        });
        break;
      case "reopen":
        mutation.mutate({
          path: `/api/items/${item.slug}/move`,
          body: { base, section: "Inbox", reason: text },
        });
        break;
      case "close":
        mutation.mutate({ path: `/api/items/${item.slug}/close`, body: { base, reason: text } });
        break;
    }
  };
  return (
    <FormDialog
      title={`${titles[kind]}: ${item.title}`}
      description={
        kind === "close"
          ? "The item's folder is removed (also evidence/ files). Until the change tray is committed, Undo brings it back."
          : kind === "reopen"
            ? "The item goes back to the Inbox for triage."
            : undefined
      }
      pending={mutation.isPending}
      problem={problem}
      // "Close" alone would share its name with the dialog's close button.
      submitLabel={kind === "close" ? "Close the item" : titles[kind]}
      destructive={kind === "close" || kind === "reject"}
      onClose={onClose}
      onSubmit={submit}
    >
      <div>
        <Label htmlFor="reason">{kind === "unblock" ? "Note (optional)" : "Reason (required)"}</Label>
        <Input
          id="reason"
          value={reason}
          required={kind !== "unblock"}
          onChange={(e) => setReason(e.target.value)}
          placeholder={REASON_HINT[kind] ?? ""}
          autoFocus
        />
        {kind === "reopen" && item.reason ? (
          <p className="mt-1 text-xs text-muted-foreground">Old reason: {item.reason}</p>
        ) : null}
      </div>
      {kind === "close" || kind === "reject" || kind === "park" ? <Dependents item={item} /> : null}
      {kind === "close" && item.source.startsWith("github#") ? (
        <p className="text-sm text-muted-foreground">
          This item came from GitHub ({item.source}). Answer and close the issue on GitHub yourself - the app
          never posts there.
        </p>
      ) : null}
      {kind === "close" && !item.verified ? (
        <p className="text-sm text-warn">The item was never verified at the current code.</p>
      ) : null}
    </FormDialog>
  );
}

/**
 * A select of legend values (the current value is always offered, even if the legend lost it).
 *
 * @param props - Id, label, values, the value and its setter.
 * @returns The element.
 */
function LegendSelect({
  id,
  label,
  values,
  value,
  onChange,
}: {
  /** Id. */ id: string;
  /** Label. */ label: string;
  /** Values. */ values: string[];
  /** Value. */ value: string;
  /** Setter. */ onChange: (v: string) => void;
}) {
  return (
    <div>
      <Label htmlFor={id}>{label}</Label>
      <NativeSelect id={id} value={value} onChange={(e) => onChange(e.target.value)}>
        {[...new Set([value, ...values])].map((v) => (
          <option key={v} value={v}>
            {v}
          </option>
        ))}
      </NativeSelect>
    </div>
  );
}

/**
 * Change header fields (title, type, severity, area, who, effort, relations).
 *
 * @param props - See {@link DialogProps}.
 * @returns The element.
 */
export function FieldsDialog({ item, boardRevision, legend, onClose }: DialogProps) {
  const { mutation, problem } = useChange(onClose);
  const [title, setTitle] = useState(item.title);
  const [type, setType] = useState(item.type);
  const [severity, setSeverity] = useState(String(item.severity));
  const [area, setArea] = useState(item.area);
  const [who, setWho] = useState(item.who);
  const [effort, setEffort] = useState(item.effort);
  const [related, setRelated] = useState(item.related.join(", "));
  const [dependsOn, setDependsOn] = useState(item.dependsOn.join(", "));
  const [reason, setReason] = useState("");
  const [position, setPosition] = useState("");
  /**
   * A comma list as slugs.
   *
   * @param text - The field text.
   * @returns The slugs.
   */
  const list = (text: string): string[] => text.split(/[\s,]+/).filter(Boolean);
  /** Sends only the fields that changed. */
  const submit = (): void => {
    const set: Record<string, string | number | string[]> = {};
    if (title.trim() !== item.title) set["title"] = title.trim();
    if (type !== item.type) set["type"] = type;
    if (Number(severity) !== item.severity) set["severity"] = Number(severity);
    if (area !== item.area) set["area"] = area;
    if (who !== item.who) set["who"] = who;
    if (effort !== item.effort) set["effort"] = effort;
    if (list(related).join(",") !== item.related.join(",")) set["related"] = list(related);
    if (list(dependsOn).join(",") !== item.dependsOn.join(",")) set["depends-on"] = list(dependsOn);
    if (Object.keys(set).length === 0) {
      onClose();
      return;
    }
    mutation.mutate({
      path: `/api/items/${item.slug}/fields`,
      body: {
        base: { ...(position ? { board: boardRevision ?? undefined } : {}), item: item.revision },
        set,
        ...(reason.trim() ? { reason: reason.trim() } : {}),
        ...(position ? { position: Number(position) } : {}),
      },
    });
  };
  const sectionMayChange = type !== item.type || who !== item.who;
  return (
    <FormDialog
      title="Edit fields"
      pending={mutation.isPending}
      problem={problem}
      submitLabel="Save"
      onClose={onClose}
      onSubmit={submit}
      wide
    >
      <div>
        <Label htmlFor="f-title">Title</Label>
        <Input id="f-title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={200} />
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        <LegendSelect
          id="f-type"
          label="Type"
          values={legend?.types.map((v) => v.value) ?? []}
          value={type}
          onChange={setType}
        />
        <div>
          <Label htmlFor="f-sev">Severity</Label>
          <Input
            id="f-sev"
            type="number"
            min={0}
            max={10}
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
          />
        </div>
        <LegendSelect
          id="f-area"
          label="Area"
          values={legend?.areas.map((v) => v.value) ?? []}
          value={area}
          onChange={setArea}
        />
        <LegendSelect
          id="f-who"
          label="Who"
          values={legend?.who.map((v) => v.value) ?? []}
          value={who}
          onChange={setWho}
        />
        <LegendSelect
          id="f-effort"
          label="Effort"
          values={legend?.efforts.map((v) => v.value) ?? []}
          value={effort}
          onChange={setEffort}
        />
        {sectionMayChange ? (
          <div>
            <Label htmlFor="f-pos">Position in the new section</Label>
            <Input
              id="f-pos"
              type="number"
              min={1}
              value={position}
              placeholder="end"
              onChange={(e) => setPosition(e.target.value)}
            />
          </div>
        ) : null}
      </div>
      <div className="grid gap-2 sm:grid-cols-2">
        <div>
          <Label htmlFor="f-rel">Related (slugs)</Label>
          <Input id="f-rel" value={related} onChange={(e) => setRelated(e.target.value)} />
        </div>
        <div>
          <Label htmlFor="f-dep">Depends on (slugs)</Label>
          <Input id="f-dep" value={dependsOn} onChange={(e) => setDependsOn(e.target.value)} />
        </div>
      </div>
      <div>
        <Label htmlFor="f-reason">Why (becomes the log line)</Label>
        <Input
          id="f-reason"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="e.g. triage: severity 7 after the review"
        />
      </div>
    </FormDialog>
  );
}

/**
 * Append a log line, or stamp the item as verified at `main`.
 *
 * @param props - See {@link DialogProps} and the kind.
 * @returns The element.
 */
export function TextDialog({
  item,
  onClose,
  kind,
}: DialogProps & { /** The change. */ kind: "log" | "verify" }) {
  const { mutation, problem } = useChange(onClose);
  const [text, setText] = useDraft(`${kind}:${item.slug}`, "");
  return (
    <FormDialog
      title={kind === "log" ? "Add a log line" : "Verify at the current main"}
      description={
        kind === "verify"
          ? "Stamps the item as verified at the current commit of main, with your note."
          : undefined
      }
      pending={mutation.isPending}
      problem={problem}
      submitLabel={kind === "log" ? "Add" : "Verify"}
      onClose={onClose}
      onSubmit={() =>
        mutation.mutate({
          path: `/api/items/${item.slug}/${kind}`,
          body: {
            base: { item: item.revision },
            ...(kind === "log" ? { text: text.trim() } : text.trim() ? { note: text.trim() } : {}),
          },
        })
      }
    >
      <div>
        <Label htmlFor="text">{kind === "log" ? "Text (one line)" : "Note (optional)"}</Label>
        <Input
          id="text"
          value={text}
          required={kind === "log"}
          onChange={(e) => setText(e.target.value)}
          autoFocus
        />
      </div>
    </FormDialog>
  );
}

/**
 * Record the maintainer's decision on a decision item (FR-030).
 *
 * @param props - See {@link DialogProps}.
 * @returns The element.
 */
export function DecideDialog({ item, legend, onClose }: DialogProps) {
  const { mutation, problem } = useChange(onClose);
  const [option, setOption] = useState(item.options[0]?.key ?? "A");
  const [decision, setDecision] = useDraft(`decision:${item.slug}`, "");
  const [action, setAction] = useState<"keep" | "move" | "set-type" | "park" | "close">("set-type");
  const [type, setType] = useState("improvement");
  const [who, setWho] = useState("agent");
  const [section, setSection] = useState<SectionName>("Next");
  const [position, setPosition] = useState("");
  const recommendation = item.body.find((b) => b.name === "Recommendation")?.markdown.trim();
  return (
    <FormDialog
      title={`Decide: ${item.title}`}
      description={item.body
        .find((b) => b.name === "Question")
        ?.markdown.trim()
        .slice(0, 300)}
      pending={mutation.isPending}
      problem={problem}
      submitLabel="Record the decision"
      onClose={onClose}
      wide
      onSubmit={() =>
        mutation.mutate({
          path: `/api/items/${item.slug}/decide`,
          body: {
            base: { item: item.revision },
            option,
            decision: decision.trim(),
            then: {
              action,
              ...(action === "move" ? { section } : {}),
              ...(action === "set-type" ? { type, who } : {}),
              ...((action === "move" || action === "set-type") && position
                ? { position: Number(position) }
                : {}),
            },
          },
        })
      }
    >
      <fieldset className="flex flex-col gap-1.5">
        <legend className="mb-1 text-xs font-medium text-muted-foreground">Option</legend>
        {(item.options.length ? item.options : [{ key: "A", text: "(no options listed)" }]).map((o) => (
          <label
            key={o.key}
            className="flex cursor-pointer gap-2 rounded-md border p-2 text-sm has-checked:border-primary has-checked:bg-primary/5"
          >
            <input
              type="radio"
              name="option"
              value={o.key}
              checked={option === o.key}
              onChange={() => setOption(o.key)}
            />
            <span>
              <strong>{o.key}</strong> {o.text}
            </span>
          </label>
        ))}
      </fieldset>
      {recommendation ? (
        <p className="text-xs text-muted-foreground">Recommendation: {recommendation.slice(0, 400)}</p>
      ) : null}
      <div>
        <Label htmlFor="decision">The decision (one sentence)</Label>
        <Input id="decision" value={decision} required onChange={(e) => setDecision(e.target.value)} />
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <div className="col-span-2">
          <Label htmlFor="then">Then</Label>
          <NativeSelect id="then" value={action} onChange={(e) => setAction(e.target.value as typeof action)}>
            <option value="set-type">make it work (new type)</option>
            <option value="move">move it</option>
            <option value="park">park it</option>
            <option value="close">close it</option>
            <option value="keep">keep it here</option>
          </NativeSelect>
        </div>
        {action === "set-type" ? (
          <>
            <div>
              <Label htmlFor="d-type">Type</Label>
              <NativeSelect id="d-type" value={type} onChange={(e) => setType(e.target.value)}>
                {(legend?.types ?? [])
                  .filter((t) => t.value !== "decision")
                  .map((t) => (
                    <option key={t.value}>{t.value}</option>
                  ))}
              </NativeSelect>
            </div>
            <div>
              <Label htmlFor="d-who">Who</Label>
              <NativeSelect id="d-who" value={who} onChange={(e) => setWho(e.target.value)}>
                {(legend?.who ?? []).map((w) => (
                  <option key={w.value}>{w.value}</option>
                ))}
              </NativeSelect>
            </div>
          </>
        ) : null}
        {action === "move" ? (
          <div>
            <Label htmlFor="d-sec">Section</Label>
            <NativeSelect
              id="d-sec"
              value={section}
              onChange={(e) => setSection(e.target.value as SectionName)}
            >
              {ORDERED_SECTIONS.filter((s) => s !== "In progress").map((s) => (
                <option key={s}>{s}</option>
              ))}
            </NativeSelect>
          </div>
        ) : null}
        {action === "move" || action === "set-type" ? (
          <div>
            <Label htmlFor="d-pos">Position</Label>
            <Input
              id="d-pos"
              type="number"
              min={1}
              value={position}
              placeholder="end"
              onChange={(e) => setPosition(e.target.value)}
            />
          </div>
        ) : null}
      </div>
    </FormDialog>
  );
}

/**
 * Record results of a person step's checklist (FR-030).
 *
 * @param props - See {@link DialogProps}.
 * @returns The element.
 */
export function StepsDialog({ item, onClose }: DialogProps) {
  const { mutation, problem } = useChange();
  const [notes, setNotes] = useState<Record<number, string>>({});
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent
        title={`Steps: ${item.title}`}
        description="Tick a step with its result; each tick is one log line."
        wide
      >
        <ol className="flex flex-col gap-2">
          {item.steps.map((step) => (
            <li key={step.index} className="flex flex-col gap-1 rounded-md border p-2">
              <div className="flex items-start gap-2 text-sm">
                <span className={step.done ? "text-ok" : "text-muted-foreground"}>
                  {step.done ? "✓" : "○"}
                </span>
                <span className="flex-1">{step.text}</span>
              </div>
              <div className="flex gap-2">
                <Input
                  aria-label={`Result of step ${step.index}`}
                  value={notes[step.index] ?? ""}
                  onChange={(e) => setNotes((n) => ({ ...n, [step.index]: e.target.value }))}
                  placeholder={step.done ? "why reopen (optional)" : "the result (optional)"}
                />
                <Button
                  size="sm"
                  variant={step.done ? "outline" : "default"}
                  disabled={mutation.isPending}
                  onClick={() =>
                    mutation.mutate({
                      path: `/api/items/${item.slug}/steps/${step.index}`,
                      body: {
                        base: { item: item.revision },
                        done: !step.done,
                        ...(notes[step.index]?.trim() ? { note: notes[step.index]!.trim() } : {}),
                      },
                    })
                  }
                >
                  {step.done ? "Reopen" : "Done"}
                </Button>
              </div>
            </li>
          ))}
        </ol>
        <ChangeProblemBox problem={problem} />
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
