// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * @file ESLint flat configuration of the backlog app (feature 344).
 *
 * Besides the usual TypeScript and React rules it enforces two project rules:
 *
 * 1. Every source file is documented (FR-050, research R22): a file overview, and a
 *    documentation comment on every function, method, class, interface, type alias, property
 *    and top-level variable - also the private ones.
 * 2. Processes are never started through a shell and item text is never code (research R7,
 *    contracts/security.md): `exec`, `execSync`, `shell: true`, `eval`, `new Function` and
 *    `dangerouslySetInnerHTML` are forbidden everywhere.
 */

import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import jsdoc from "eslint-plugin-jsdoc";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import tsdoc from "eslint-plugin-tsdoc";
import globals from "globals";
import tseslint from "typescript-eslint";

/**
 * AST selectors whose nodes must carry a documentation comment, in addition to the function
 * forms `require-jsdoc` checks through its `require` option.
 */
const documentedContexts = [
  "TSInterfaceDeclaration",
  "TSTypeAliasDeclaration",
  // Members of interfaces; property signatures of inline object types are described by the
  // documentation of the thing they belong to.
  "TSInterfaceBody > TSPropertySignature",
  "TSInterfaceBody > TSMethodSignature",
  "TSEnumDeclaration",
  "PropertyDefinition",
  "Program > VariableDeclaration",
  "ExportNamedDeclaration[declaration.type='VariableDeclaration']",
];

/** Syntax that would run text as code or start a shell; forbidden in every file. */
const forbiddenSyntax = [
  {
    selector: "Property[key.name='shell'][value.value=true]",
    message: "Never start a process through a shell (research R7).",
  },
  {
    selector: "CallExpression[callee.name='eval']",
    message: "eval is forbidden: item text is never code.",
  },
  {
    selector: "NewExpression[callee.name='Function']",
    message: "new Function is forbidden: item text is never code.",
  },
  {
    selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
    message: "Raw HTML is never rendered (contracts/security.md).",
  },
];

export default defineConfig(
  {
    // Generated output, dependencies and test reports are never linted.
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "docs-api/**",
      "test-results/**",
      "playwright-report/**",
      "coverage/**",
      ".cache/**",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: {
          allowDefaultProject: ["*.js"],
        },
        tsconfigRootDir: import.meta.dirname,
      },
      globals: { ...globals.node },
    },
    plugins: { jsdoc, tsdoc },
    settings: { jsdoc: { mode: "typescript" } },
    rules: {
      // --- documentation (FR-050) ---
      "jsdoc/require-file-overview": [
        "error",
        { tags: { file: { mustExist: true, preventDuplicates: true, initialCommentsOnly: true } } },
      ],
      "jsdoc/require-jsdoc": [
        "error",
        {
          publicOnly: false,
          require: {
            FunctionDeclaration: true,
            MethodDefinition: true,
            ClassDeclaration: true,
            ClassExpression: true,
            ArrowFunctionExpression: false,
            FunctionExpression: false,
          },
          contexts: [
            ...documentedContexts,
            "VariableDeclarator > ArrowFunctionExpression",
            "VariableDeclarator > FunctionExpression",
          ],
          checkConstructors: false,
          checkGetters: true,
          checkSetters: true,
        },
      ],
      "jsdoc/require-description": ["error", { contexts: ["any"], exemptedBy: ["file", "inheritdoc"] }],
      "jsdoc/require-param": ["error", { checkDestructured: false }],
      "jsdoc/require-param-description": "error",
      "jsdoc/require-returns": ["error", { checkGetters: false }],
      "jsdoc/require-returns-description": "error",
      "jsdoc/check-param-names": ["error", { checkDestructured: false }],
      "jsdoc/no-types": "error",
      "jsdoc/check-tag-names": ["error", { definedTags: ["file", "remarks", "typeParam", "defaultValue"] }],
      "tsdoc/syntax": "error",
      // --- no shell, no code from text (research R7) ---
      "no-restricted-syntax": ["error", ...forbiddenSyntax],
      "no-restricted-imports": [
        "error",
        {
          paths: [
            { name: "node:child_process", importNames: ["exec", "execSync"], message: "Use proc/spawn.ts." },
            { name: "child_process", message: "Import node:child_process only in proc/spawn.ts." },
          ],
        },
      ],
      // --- TypeScript strictness that keeps Node's type stripping happy (research R6) ---
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
    },
  },
  {
    // The browser client: React rules and browser globals.
    files: ["packages/web/**/*.{ts,tsx}"],
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    languageOptions: { globals: { ...globals.browser } },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  },
  {
    // Scripts the browser loads as they are (the theme script) run with browser globals.
    files: ["packages/web/public/**/*.js"],
    languageOptions: { globals: { ...globals.browser } },
  },
  {
    // shadcn-style component files export their variant helpers next to the components, feature
    // modules export their hooks next to the components that use them, and main.tsx is the entry
    // point. The rule only serves live reload in development: for such a file Vite reloads the
    // page instead of swapping the component, which is acceptable for this tool.
    files: [
      "packages/web/src/components/**/*.tsx",
      "packages/web/src/features/**/*.tsx",
      "packages/web/src/main.tsx",
    ],
    rules: { "react-refresh/only-export-components": "off" },
  },
  {
    // Plain JavaScript files (configs, the theme script) are not type-checked.
    files: ["**/*.js", "**/*.mjs"],
    ...tseslint.configs.disableTypeChecked,
  },
  {
    // Only the process module may import node:child_process at all.
    files: ["packages/server/src/proc/**/*.ts"],
    rules: { "no-restricted-imports": "off" },
  },
  {
    // Tests may use test-only helpers without documenting every callback.
    files: ["**/test/**/*.{ts,tsx}", "e2e/**/*.ts"],
    rules: {
      "jsdoc/require-jsdoc": [
        "error",
        { publicOnly: false, require: { FunctionDeclaration: true }, contexts: [] },
      ],
      "@typescript-eslint/no-floating-promises": "off",
      "@typescript-eslint/unbound-method": "off",
    },
  },
);
