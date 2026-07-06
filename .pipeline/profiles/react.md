---
title: "Implementation Profile — React Platform"
project: "Digital Systems Engineering Pipeline"
tier: implementation
platform: "react"
version: "1.0.0"
created: "2026-06-16"
created_time: "2026-06-16T09:40:52Z"
last_updated: "2026-06-20"
last_updated_time: "2026-06-20T13:13:00+08:00"
---

# Implementation Profile: React Platform

> This document governs feature implementation and builds for both local and hosted React environments.
> Read alongside `.pipeline/constitution.md` (functional layer).

## 1. Platform & Stack
- **Framework & Version:** React (as resolved from environment configuration)
- **Language & Version:** TypeScript (strict mode enabled). Note: TypeScript implementations MUST use lowercase primitives (`string`, `number`, `boolean`), not UML wrapper types (`String`, `Real`, `Boolean`).
- **Persistence Architecture:** Modular Repository/Adapter pattern.
  - Direct database/API SDK imports (such as `@firebase/firestore`) are forbidden in React components.
  - Components must depend only on abstract Repository interfaces.
  - Active adapter is injected at application bootstrap resolved dynamically from the loaded runtime configuration metadata (`config.json`) rather than build-time environment variables.
  - For the Firebase profile, the abstract repository resolves dynamically to the concrete `FirestoreRepositoryAdapter` implementing the abstract interface.
- **Dependency Injection (DI):** Standardize on React Context Hooks for dependency resolution at the application root.
- **Allowed Adapters:**
  - Transport and database adapters must register themselves dynamically at application bootstrap. The platform profile does not restrict the allowed adapter types; any class implementing the target Repository interface is permitted, enabling dynamic runtime resolution of any protocol or database client (e.g. REST, gRPC, WebSocket, GraphQL, or local storage).
- **Environment Selection Keys:**
  - Resolved dynamically from the platform configuration metadata (e.g., config keys specifying the active persistence adapter injected at bootstrap).
- **Dependencies:**
  - Required: Resolved dynamically from the platform configuration file (parsed from the package dependencies config block).
  - DevDependencies: Resolved dynamically from the platform configuration file.

## 2. Coding Standards & UI Patterns
- **Clean Architecture & Decoupling:** Persistence code must be isolated under the designated persistence directory resolved from configuration (e.g., source persistence adapters directory):
  - Repository interfaces defining CRUD and domain-specific query interfaces.
  - Concrete adapter implementations.
  - Mock implementations for fast unit testing stubs.
- **Naming Conventions:**
  - PascalCase for React components and class-based Adapters.
  - camelCase for interface declarations and instances.
  - kebab-case for folders and file names.
- **Type Strictness:** Strict null checks enabled; use of `any` is strictly prohibited. Every database model must map to a TypeScript interface.
- **Off-Thread Processing:**
  - To prevent main-thread UI starvation during high-frequency data streaming or heavy parsing, all intensive computation and data deserialization MUST execute off the main thread inside a background execution context (such as Web Workers).
  - Pass normalized domain structures to the main thread via asynchronous message passing.
- **Resource Management:**
  - Explicitly manage runtime memory lifecycles for hardware-accelerated viewports or large buffers, releasing memory in component cleanup hooks to prevent leaks.
  - Pre-allocate and reuse memory blocks where possible to avoid continuous runtime memory allocation.
- **UI & Design Aesthetics (Professional High-Density Console Standards):**
  - **Visual Identity:** Interfaces must mimic a clean, high-density, professional management console.
  - **Theme Selection:**
    - Must provide a user interface to select from the dynamic list of theme modes defined in the runtime configuration (Tier 2).
    - The application must map styling parameters dynamically to color tokens matching the active design token namespaces resolved from the loaded configuration to allow dynamic, reload-free theme switching.
    - The theme preference must be resolved dynamically in an SSR-safe and hydration-compatible manner. Visual theme flashes (FOUC) must be prevented using environment-appropriate mechanisms (such as CSS custom properties or native style rules mapped from theme preferences during hydration, or conditional HTML `<head>` theme script injections safely gated checking `typeof window !== 'undefined'` for non-browser/SSR environments) to ensure compatibility with Server-Side Rendering (SSR) environments and headless Node-based unit testing environments.
  - **Dynamic Design Tokens & Alarm Mappings:**
    - Hardcoding visual parameters (e.g., hex colors, margins) or standard-specific mappings (e.g., specific alarm severities or colors) is strictly forbidden.
    - All status colors, brand palettes, and component styles must be loaded dynamically from the active design tokens configuration resolved at runtime.
    - At startup, the application must dynamically resolve and apply styling tokens parsed from the configuration in a testing-safe, headless-compatible manner. The configuration resolution must not rely on blocking head script injection or assume browser-specific DOM API access during startup or unit-test verification loops.
    - Status visualizations, node borders, and alarm indicators must resolve their colors and severity levels dynamically via a metadata-driven UI registry loaded at runtime.
  - **Layout & Structure:**
    - **Global CSS Box Sizing & Root Layout:** To prevent vertical scroll clipping and viewport layout overflow, the stylesheet MUST enforce:
      - Global box-sizing reset (`box-sizing: border-box`) on all elements.
      - Viewport-constrained dimensions on the React root element (`#root` height set to `100vh`, width set to `100vw`, display `flex`, direction `column`, and overflow `hidden`).
      - **CSS Specificity Protection:** To prevent global or ancestor descendant selectors from silently overriding component states (such as active highlighting), all UI components MUST use CSS Modules, styled-components, or strict BEM (Block-Element-Modifier) class naming conventions. Direct tag-descendant rules on broad wrappers (e.g. `.explorer-tree li`) are forbidden for state styling.
      - **Sidebar Column Layout:** The outer `SidebarLayout` container shell must display the sidebar and the main split workspace side-by-side horizontally using a row flex layout (`display: flex; flex-direction: row; height: 100%; width: 100%; overflow: hidden;`). The navigation sidebar column (`HierarchyTreeSelector`) must be constrained as a vertical column with `display: flex; flex-direction: column; flex-shrink: 0;`, a minimum width (e.g., `min-width: 240px;` or resolved from design tokens) to prevent layout splitters from squishing it, and support independent vertical scrolling (`overflow-y: auto; overflow-x: hidden;`).
    - Navigation architecture aligned with hierarchical layout slot containers.
    - **Hierarchy Navigation Component:** (e.g. hierarchy tree or navigation slot resolved from configuration). Exposes a primary navigation slot. Must support:
      - Mapping physical inputs to logical action bindings (such as `NAVIGATE_NEXT`, `NAVIGATE_PREVIOUS`, `EXPAND_NODE`, `COLLAPSE_NODE`) dynamically.
      - Virtualized list row rendering.
      - Dynamic accessibility semantic injection.
      - **Valid HTML Tree Nesting:** The component must output valid HTML structure for nested lists. Sub-lists (`<ul>`/`<ol>`) representing child nodes must be nested directly inside their parent `<li>` element (e.g. `<li> Parent <ul> <li> Child </li> </ul> </li>`), never nested as direct siblings of `<li>` elements under a parent list.
    - **Resizable Splitter Component:** The main workspace area renders pane slots dynamically populated with child components resolved from the runtime layout configuration registry.
      - Default layout: stacked along a configurable split axis. The user can toggle split directions.
      - **DOM State Preservation during Reparenting:** Swapping split axis orientations (vertical/horizontal) or changing pane order must preserve component state. The layout must use structural virtual DOM stability (e.g. keeping container elements persistently mounted in a fixed tree structure and using CSS Flexbox/Grid direction variables) rather than conditional JSX element branching/unmounting to prevent DOM state destruction (such as text input focus, active playback state, or embedded frame/iframe contexts).
      - **Isolating Reflows:** CSS layout/paint containment (`contain: layout paint;` and `container-type: inline-size;`) MUST be applied exclusively to the outer layout splitter containers to isolate layout reflows during active dragging. Containment rules are strictly prohibited on inner scrollable content/child panels (such as list views, log viewers, or tree nodes) where container queries are not actively utilized, as containment can break standard browser scroll track and height calculations.
      - **Virtual DOM State Resizing:** Resizing interactions must update layout state variables or CSS custom properties managed through React state/context or a decoupled state provider, rather than directly mutating the physical DOM bypassing the React virtual DOM tree, ensuring headless testing compatibility (except during active drag gestures where direct DOM inline custom property mutations are permitted solely for 60fps painting optimization).
      - **Snap-to-Edge:** Support snap-to-edge collapse when dragged within the configured threshold boundaries.
      - Child components resolved from the layout configuration (such as viewports, attribute grids, or lists) are dynamically rendered inside the workspace containers.
    - **Property Grid Component:** Key-value attribute grid mapped to a schema. Validation schemas are compiled *once* at initialization into a flat, typed layout descriptor list to avoid render-cycle parsing lag. Input fields validate upon focus loss or edit completion and maintain a local change-buffer to block global state re-renders on keystroke.
    - **Navigation Breadcrumbs Component:** Exposes a breadcrumb path resolved from the current selection. Collapses middle segments dynamically when the path length exceeds available container space.
    - **Ubiquitous Navigation Links:** Whenever the UI presents a managed object or attribute, it must be rendered as a selectable, clickable link that directly navigates to that item.
    - **Density Table Component:** High information-density tables with sortable, filterable columns, row selections, and status badges. Table row sizing must use `min-height: 32px` and compact vertical cell padding of `4px` top/bottom to maximize information density while remaining scale-safe.
  - **Typography:** Resolved dynamically from the typography design tokens (Roboto, Inter, sans-serif, base text size constrained at `12px`–`13px`, section headings at `13px`–`14px`, page title at `18px` max).
  - **Icons & Vector Graphics:** SVG icons must be outline-only, constrained within a fixed `16px` viewport boundary with a stroke weight of `1.0px`–`1.2px` and a bounding padding of `2px`.
  - **Interactivity:** Micro-animations for hover states, side-panel slide-outs, loading skeletons, and inline help tooltips.
  - **Self-Documenting Code & Documentation Mandates:**
    - **Intention-Revealing Names:** Enforce intention-revealing names for all variables, hooks, components, and functions.
    - **JSDoc/TSDoc Comments:** Require JSDoc/TSDoc blocks on all components, custom hooks, public methods, and interfaces (covering purpose, `@param`, `@returns`, and `@throws`).
    - **UML Traceability:** Enforce UML traceability metadata comment tags (e.g. `@realizes UML::ClassName::operationName`) to link code directly to specification diagrams.
    - **Inline Complexity Comments:** Require detailed inline complexity comments explaining the *why* for non-trivial logic.
    - **No Placeholders or Dead Code:** Prohibit dead code, commented-out blocks, placeholders, or undocumented stubs in production files.

## 3. Testing Mandates
- **TDD Requirement:** Strict RED-GREEN-REFACTOR cycle. Write a test before writing the code.
- **Visual & Style Assertions:** Unit/widget tests that verify interactive states, highlight states, active selections, or layout dimensions must perform computed style assertions (such as using `window.getComputedStyle(element)` to verify background colors, display constraints, or active highlight properties) to prevent silent CSS specificity or layout regression errors.
- **TDD Loop Speed:** Unit and widget/component tests must execute against isolated, thread-safe in-memory stubs (Mock Repositories) for fast, sub-second feedback.
- **Integration/E2E Test Instances:** All integration and E2E tests must execute against real, local database service instances (local emulators/containers) loaded with seeded test data. In-memory stubs are prohibited for these tiers.
- **E2E Testing:** E2E tests running against the local dev server and the configured local emulator/services suite during local runs, or targeting a staging/preview deployment URL connected to a staging database environment for hosted runs.
- **Test Code Statement Coverage Target:** Minimum statement coverage targets on core business logic, validation schemas, and calculation engines, excluding simple repository wrappers from the generic line-coverage gate, as defined in configuration.

## 4. Build & Operations
- **Lint Command:** Commands resolved from environment configurations (e.g. `npm run lint` / `npx tsc --noEmit`)
- **Local Dev / Dev Server Command:** Command resolved from environment configurations (e.g. `npm run dev`)
- **Local Emulator Command:** Command resolved from environment configurations (e.g. `npx firebase emulators:start --only firestore`)
- **Build Command:** Command resolved from environment configurations (outputs optimized production bundle in the configured build output directory, e.g. `/dist`)
- **CI/CD Integration:** Triggered on merge to default branch; builds and deploys to Firebase App Hosting, Vercel, or Docker-based private server. Dockerfiles must run as a non-root user.

## 5. Security & Credentials
- **Local Configurations:** API credentials and environment configurations are loaded from a secure, local, git-ignored `.env.local` file. Default mock credentials are used for emulators.
- **Hosted Configurations:** To support the "Build Once, Deploy Anywhere" pattern, production API credentials and environment configurations must be loaded dynamically at runtime (e.g., via a runtime config JSON file fetch at bootstrap or a dynamic config service endpoint) rather than compiling credentials or backend URLs into the client bundle at build/deployment time. Keys must never be committed to git.
- **Secrets Scope & Boundaries:**
  - **ONLY public-facing keys** (such as Firebase client keys that have domain/IP origin restrictions configured on the provider console) are permitted to be compiled into client-side bundles.
  - **Administrative secrets** (such as database write passwords, service account private keys, or API private keys) must **never** be compiled into the frontend. They must be managed via a secure backend vault (like GCP Secret Manager) and accessed through secure backend endpoints with proper IAM controls.
- **CORS/CSP:** Hosted deployments must configure strict server CORS headers and Content Security Policies. HTTPS is mandatory for all network connections.
