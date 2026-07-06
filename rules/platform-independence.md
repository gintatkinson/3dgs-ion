<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Platform Independence in Specifications

**ALWAYS enforce:** Epics, Features, User Stories, and Use Cases must be purely functional and platform-independent.

## Hard constraints

- Specification documents MUST describe *what* the system does, never *how* it is built.
- Feature specs MUST NOT contain framework-specific component names (e.g., no `<Drawer>`, no `showModalBottomSheet`).
- Feature specs MUST NOT contain a `platform` field in their YAML frontmatter.
- Acceptance criteria MUST be platform-independent (e.g., "the detail view displays the address" — not "the React Drawer component renders the address").
- The `Interface Requirements` section describes data, payloads, layout, or protocols logically, without referencing specific frameworks or transport libraries.

## Where platform-specific details belong

- Implementation profiles: `.pipeline/profiles/<platform>.md`
- Implementation plans: `implementation_plan.md` created during The Grill (Step 2 of feature-driven-implementation)
- Solution walkthroughs: paths defined by design and implementation guidelines (e.g. `<walkthrough_dir>/feat-<N>-solution.md` or as configured)

## Why

A single set of functional specs can drive implementations on React, Flutter, .NET, or any other platform. Contaminating specs with platform details forces re-specification when targeting a new platform and violates the two-tier constitution architecture.
