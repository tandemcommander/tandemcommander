// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file The full page of one item (`/items/<slug>`); the open tab is in the address.
 */

import { getRouteApi, useNavigate } from "@tanstack/react-router";
import { ItemView } from "./item-view.tsx";

/** The route's parameters. */
const route = getRouteApi("/items/$slug");

/**
 * The item page.
 *
 * @returns The element.
 */
export function ItemPage() {
  const { slug } = route.useParams();
  const { tab } = route.useSearch();
  const navigate = useNavigate();
  return (
    <div className="mx-auto w-full max-w-5xl">
      <ItemView
        slug={slug}
        tab={tab}
        onTab={(next) =>
          void navigate({
            to: "/items/$slug",
            params: { slug },
            search: { tab: next === "description" ? "" : next },
            replace: true,
          })
        }
      />
    </div>
  );
}
