// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file Overlay components on Radix primitives (shadcn/ui pattern): dialog, side sheet, drop-down
 * menu, tooltip and tabs. Radix handles focus trapping, focus return, Escape and screen-reader
 * semantics, which the keyboard-only journeys rely on (SC-009).
 */

import { XIcon } from "lucide-react";
import {
  Dialog as DialogPrimitive,
  DropdownMenu as MenuPrimitive,
  Tabs as TabsPrimitive,
  Tooltip as TooltipPrimitive,
} from "radix-ui";
import type { ComponentProps, ReactNode } from "react";
import { cn } from "@/lib/utils.ts";

/** The dialog root (controls the open state). */
export const Dialog = DialogPrimitive.Root;

/** The element that opens a dialog. */
export const DialogTrigger = DialogPrimitive.Trigger;

/** An element that closes the dialog. */
export const DialogClose = DialogPrimitive.Close;

/**
 * The content of a dialog with its overlay and a close button.
 *
 * @param props - Content properties, the title and an optional description.
 * @returns The element.
 */
export function DialogContent({
  className,
  children,
  title,
  description,
  wide = false,
  ...props
}: ComponentProps<typeof DialogPrimitive.Content> & {
  /** The dialog's title (required for screen readers). */
  title: ReactNode;
  /** A line under the title. */
  description?: ReactNode;
  /** A wider dialog for forms with two columns. */
  wide?: boolean;
}) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/40 data-[state=open]:animate-in data-[state=open]:fade-in-0" />
      <DialogPrimitive.Content
        className={cn(
          "fixed top-[12vh] left-1/2 z-50 flex max-h-[80vh] w-[calc(100vw-2rem)] -translate-x-1/2 flex-col gap-3 overflow-y-auto rounded-lg border bg-popover p-5 text-popover-foreground shadow-xl data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95",
          wide ? "max-w-3xl" : "max-w-lg",
          className,
        )}
        {...props}
      >
        <div className="pr-6">
          <DialogPrimitive.Title className="text-base font-semibold">{title}</DialogPrimitive.Title>
          {description ? (
            <DialogPrimitive.Description className="mt-1 text-sm text-muted-foreground">
              {description}
            </DialogPrimitive.Description>
          ) : (
            <DialogPrimitive.Description className="sr-only">{title}</DialogPrimitive.Description>
          )}
        </div>
        {children}
        <DialogPrimitive.Close
          className="absolute top-4 right-4 rounded-sm opacity-70 hover:opacity-100 focus-visible:ring-2 focus-visible:ring-ring"
          aria-label="Close"
        >
          <XIcon className="size-4" />
        </DialogPrimitive.Close>
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}

/**
 * A row of dialog buttons, right-aligned.
 *
 * @param props - Div properties.
 * @returns The element.
 */
export function DialogFooter({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("mt-2 flex flex-wrap justify-end gap-2", className)} {...props} />;
}

/**
 * A panel sliding in from the right (detail pane on narrow windows, the change tray).
 *
 * @param props - Content properties and the title.
 * @returns The element.
 */
export function SheetContent({
  className,
  children,
  title,
  ...props
}: ComponentProps<typeof DialogPrimitive.Content> & {
  /** The panel's title. */
  title: ReactNode;
}) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/30" />
      <DialogPrimitive.Content
        className={cn(
          "fixed inset-y-0 right-0 z-50 flex w-full max-w-xl flex-col border-l bg-popover text-popover-foreground shadow-xl data-[state=open]:animate-in data-[state=open]:slide-in-from-right",
          className,
        )}
        {...props}
      >
        <div className="flex items-center justify-between border-b px-4 py-3">
          <DialogPrimitive.Title className="text-base font-semibold">{title}</DialogPrimitive.Title>
          <DialogPrimitive.Description className="sr-only">{title}</DialogPrimitive.Description>
          <DialogPrimitive.Close className="rounded-sm opacity-70 hover:opacity-100" aria-label="Close">
            <XIcon className="size-4" />
          </DialogPrimitive.Close>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto p-4">{children}</div>
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}

/** The drop-down menu root. */
export const DropdownMenu = MenuPrimitive.Root;

/** The element that opens a drop-down menu. */
export const DropdownMenuTrigger = MenuPrimitive.Trigger;

/**
 * The content of a drop-down menu.
 *
 * @param props - Content properties.
 * @returns The element.
 */
export function DropdownMenuContent({
  className,
  sideOffset = 4,
  ...props
}: ComponentProps<typeof MenuPrimitive.Content>) {
  return (
    <MenuPrimitive.Portal>
      <MenuPrimitive.Content
        sideOffset={sideOffset}
        className={cn(
          "z-50 min-w-40 rounded-md border bg-popover p-1 text-popover-foreground shadow-lg",
          className,
        )}
        {...props}
      />
    </MenuPrimitive.Portal>
  );
}

/**
 * One item of a drop-down menu.
 *
 * @param props - Item properties.
 * @returns The element.
 */
export function DropdownMenuItem({ className, ...props }: ComponentProps<typeof MenuPrimitive.Item>) {
  return (
    <MenuPrimitive.Item
      className={cn(
        "flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none select-none data-[disabled]:opacity-50 data-[highlighted]:bg-accent [&_svg]:size-4",
        className,
      )}
      {...props}
    />
  );
}

/**
 * A separator line inside a drop-down menu.
 *
 * @param props - Separator properties.
 * @returns The element.
 */
export function DropdownMenuSeparator({
  className,
  ...props
}: ComponentProps<typeof MenuPrimitive.Separator>) {
  return <MenuPrimitive.Separator className={cn("-mx-1 my-1 h-px bg-border", className)} {...props} />;
}

/** Provides tooltip timing for the whole app. */
export const TooltipProvider = TooltipPrimitive.Provider;

/**
 * A tooltip around a trigger element.
 *
 * @param props - The trigger (child) and the tooltip text.
 * @returns The element.
 */
export function Tooltip({
  children,
  content,
}: {
  /** The element the tooltip describes (must accept a ref). */
  children: ReactNode;
  /** The tooltip text; nothing is shown when empty. */
  content: ReactNode;
}) {
  if (!content) return <>{children}</>;
  return (
    <TooltipPrimitive.Root>
      <TooltipPrimitive.Trigger asChild>{children}</TooltipPrimitive.Trigger>
      <TooltipPrimitive.Portal>
        <TooltipPrimitive.Content
          sideOffset={4}
          className="z-50 max-w-sm rounded-md bg-foreground px-2 py-1 text-xs text-background shadow"
        >
          {content}
        </TooltipPrimitive.Content>
      </TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

/** The tabs root. */
export const Tabs = TabsPrimitive.Root;

/**
 * The row of tab buttons.
 *
 * @param props - List properties.
 * @returns The element.
 */
export function TabsList({ className, ...props }: ComponentProps<typeof TabsPrimitive.List>) {
  return <TabsPrimitive.List className={cn("flex gap-1 border-b", className)} {...props} />;
}

/**
 * One tab button.
 *
 * @param props - Trigger properties.
 * @returns The element.
 */
export function TabsTrigger({ className, ...props }: ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      className={cn(
        "-mb-px border-b-2 border-transparent px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground data-[state=active]:border-primary data-[state=active]:font-medium data-[state=active]:text-foreground",
        className,
      )}
      {...props}
    />
  );
}

/**
 * The content of one tab.
 *
 * @param props - Content properties.
 * @returns The element.
 */
export function TabsContent({ className, ...props }: ComponentProps<typeof TabsPrimitive.Content>) {
  return <TabsPrimitive.Content className={cn("pt-3 outline-none", className)} {...props} />;
}
