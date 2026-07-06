<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

---
name: project-constitution
description: "Establishes and manages a project's two-tier governance constitution: a platform-agnostic functional layer for specification and platform-specific implementation profiles. Use when setting up a new project, onboarding agents, adding a new implementation platform, or updating project-wide coding standards and quality gates."
compatibility: "Works with any agent runtime. No CLI dependencies."
metadata:
  title: "Project Constitution (Layered Governance: Functional + Implementation Profiles)"
  category: governance
  risk: low
  source: custom
  version: "2.0"
---

# Project Constitution (Layered Governance)

Use this skill to establish or update a project's foundational governance documents. The constitution is **two-tiered** to reflect the fundamental separation in this pipeline:

- **Specification** (Epics, Features, User Stories, Use Cases) is **purely functional and platform-independent.**
- **Implementation** (code, tests, deployment) is **platform-specific** and may have multiple variants.

> [!IMPORTANT]
> Epics, Features, User Stories, and Use Cases derived from structural schemas and specifications describe *what* the system must do — never *how* it is built. A single set of functional specs can drive implementations on any target platform, language, or framework simultaneously.

## Architecture: Two Tiers

```
.pipeline/
├── constitution.md                  # Tier 1: Functional (shared, platform-agnostic)
└── profiles/
    └── [platform].md                # Tier 2: Platform-specific implementation profiles
```

**Tier 1 — Functional Constitution** (`.pipeline/constitution.md`)
- Domain rules, specification sources, data model constraints
- Agent behavior rules (commit format, branch naming, documentation)
- Quality gates that apply universally (human approval, The Grill)
- Read by ALL skills (spec-orchestrator, workers, implementation)

**Tier 2 — Implementation Profiles** (`.pipeline/profiles/<platform>.md`)
- Platform & stack constraints (framework, language version, forbidden deps)
- Coding standards (typing rules, naming conventions, architecture pattern)
- Testing mandates (test framework, coverage thresholds, TDD level)
- Operational context (deployment env, CI/CD, security)
- Read ONLY by `feature-driven-implementation` when targeting that platform

> [!TIP]
> Inspired by Spec Kit's `/speckit.constitution` concept. This skill provides persistent principles memory integrated natively into the Digital Pipeline, extended with multi-platform profile support.

## When to Invoke

- **New project setup:** Establish the functional constitution before running any pipeline skill.
- **New platform target:** Create an implementation profile before implementing features on a new platform.
- **Major architectural changes:** When the team adopts new standards or constraints.
- **Agent onboarding:** When a new agent session begins and needs to understand project rules.

## Core Mandates

1. **Functional/Implementation Separation:** Specification skills (`spec-orchestrator`, Workers A-C) MUST NOT read implementation profiles. They operate on the functional constitution only. Implementation profiles contain platform-specific details that would contaminate platform-independent specs.
2. **One Functional Constitution, Many Profiles:** A project has exactly one `.pipeline/constitution.md` (functional) and zero or more `.pipeline/profiles/<platform>.md` (implementation). Multiple platforms can coexist.
3. **Cumulative, Never Destructive:** When updating any constitution document, read the existing file first. Append or refine — never delete established principles without explicit human approval.
4. **Human Authored, Agent Enforced:** The constitution is written by the human (with agent assistance for structure). Agents MUST NOT modify it autonomously.
5. **Profile Selection at Implementation Time:** When invoking `feature-driven-implementation`, the target platform is specified. The agent reads the functional constitution AND the matching implementation profile. If no profile exists for the target platform, halt and prompt the human to create one.

---

## Step-by-Step Workflow

### Step 1: Initialize Constitution Structure

```bash
mkdir -p .pipeline/profiles
```

### Step 2: Gather Functional Principles (Tier 1)

Prompt the human with these categories — all must be **platform-independent** and **protocol-agnostic**. The constitution itself MUST NOT hardcode or assume any specific standard or schema format (such as YANG or RFC 8345) during initialization; all reference models are loaded dynamically at runtime.

1. **Domain Rules**
   - General schema compliance requirements (how constraints, ranges, and patterns are captured)
   - General data model integrity rules (mapping nodes to feature specs, tracking circular dependencies)
   - Semantic invariants (e.g., "every node must resolve to a valid existing parent context")
   - Model Metamodel & Profile Mapping Standard (explicit mappings from source schemas such as YANG, OpenAPI, or Protobuf to target logical modeling elements: Components, Classes, Attributes, Operations, and Constraints)
   - Universal Model Consistency Rules (declarations enforcing that no element/message may be used in dynamic behavior specifications like sequence or state diagrams without being defined in the structural models)

2. **Specification Standards**
   - Epic/Feature granularity rules
   - BDD scenario format requirements
   - Use Case formality level (UML strict vs lightweight)
   - Acceptance criteria format (Given/When/Then mandatory?)

3. **Agent Behavior Rules** (universal)
   - Commit message format (e.g., `feat:`, `fix:`, `docs:`)
   - Branch naming convention (e.g., `feat/<N>-<desc>`)
   - Documentation standards
   - Drill-down navigation mandate

4. **Universal Quality Gates**
   - Human approval required before code? (The Grill: yes/no)
   - Review required before merge? (yes/no)
   - Spec compliance review mandatory? (yes/no)

### Step 3: Generate Functional Constitution

Write to `.pipeline/constitution.md`:

```markdown
---
title: "Project Constitution — Functional Layer"
project: "[Project Name]"
tier: functional
created: "[ISO Date]"
last_updated: "[ISO Date]"
---

# Project Constitution: [Project Name]

> This document governs specification generation and is platform-independent and protocol-agnostic.
> All agents MUST read this file before beginning any pipeline execution.
> For platform-specific rules, see `.pipeline/profiles/<platform>.md`.

## Domain Rules
- [Captured rules]

### Model Metamodel & Profile Mapping Standard
- [Define rules laying out how incoming schemas (like YANG, OpenAPI, Protobuf) must map to target logical elements: Components, Classes, Attributes, Operations, and Constraints]

### Universal Model Consistency Rules
- [Define consistency rules, including the requirement that no element/message/signal may be used in dynamic behavior specifications without being defined in the structural models]

## Specification Standards
- [Captured standards]

## Agent Behavior
- [Captured rules]

## Universal Quality Gates
- [Captured gates]
```

### Step 4: Gather Implementation Principles (Tier 2, Per Platform)

For each target platform, prompt the human:

1. **Platform & Stack Constraints**
   - Target framework and version (e.g., `<target-framework> <version>`)
   - Language and version (e.g., `<target-language> <version>`)
   - Forbidden dependencies or patterns
   - Required dependencies

2. **Coding Standards**
   - Type strictness level (e.g., strict null checks, type safety rules)
   - Naming conventions (e.g., casing rules for files, directories, and classes)
   - Module/component architecture pattern (e.g., feature-based, layered)

3. **Testing Mandates**
   - Required test types (unit, widget/component, integration, E2E)
   - Test framework(s) (e.g., `<test-framework>`, `<e2e-framework>`)
   - Coverage thresholds (e.g., line and branch coverage limits)
   - TDD enforcement level (mandatory per micro-task, or per feature)

4. **Build & Deployment**
   - Build command (e.g., `<build-command>`)
   - Lint command (e.g., `<lint-command>`)
   - CI/CD pipeline (e.g., `<ci-cd-service>`)
   - Deployment target (e.g., `<cloud-provider>`, `<app-store>`)

5. **Security & Ops**
   - API key management
   - Auth provider
   - CORS/CSP rules

### Step 5: Generate Implementation Profile

Write to `.pipeline/profiles/<platform>.md`:

```markdown
---
title: "Implementation Profile — [Platform]"
project: "[Project Name]"
tier: implementation
platform: "[platform identifier, e.g., react, flutter, dotnet]"
created: "[ISO Date]"
last_updated: "[ISO Date]"
---

# Implementation Profile: [Platform]

> This document governs feature implementation on [Platform] only.
> Read alongside `.pipeline/constitution.md` (functional layer).

## Platform & Stack
- [Captured constraints]

## Coding Standards
- [Captured standards]

## Testing Mandates
- [Captured mandates]

## Build & Deployment
- [Captured config]

## Security & Ops
- [Captured constraints]
```

### Step 6: Commit & Reference

1. Commit all constitution documents:
   ```bash
   git add .pipeline/
   git commit -m "docs: establish project constitution (functional + implementation profiles)"
   ```

2. Ensure the project's `AGENTS.md` (or equivalent) references the constitution:
   ```markdown
   **CRITICAL: Read `.pipeline/constitution.md` before any task execution.**
   **For implementation tasks, also read `.pipeline/profiles/<platform>.md`.**
   ```

### Step 7: Profile Lifecycle Management

#### Adding a Profile

1. Human requests: *"I want to implement on [platform]."*
2. Agent runs Step 4 (gather implementation principles for the new platform).
3. Agent generates `.pipeline/profiles/<platform>.md` via Step 5.
4. Agent updates `AGENTS.md` to reference the new profile.
5. Commit:
   ```bash
   git add .pipeline/profiles/<platform>.md
   git commit -m "docs: add implementation profile for <platform>"
   ```
6. Functional specs (Epics, Features, Stories, Use Cases) remain unchanged.

#### Updating a Profile

1. Human requests a change: *"Update the [platform] profile to require Playwright E2E tests."*
2. Agent reads the existing `.pipeline/profiles/<platform>.md`.
3. Agent proposes the amendment and waits for human approval.
4. Agent writes the update (append/refine, never destructive overwrite of unrelated sections).
5. Update `last_updated` in the profile's frontmatter.
6. Commit:
   ```bash
   git add .pipeline/profiles/<platform>.md
   git commit -m "docs: update <platform> implementation profile — <change summary>"
   ```

#### Removing a Profile

1. Human requests: *"We're dropping the [platform] implementation."*
2. Agent confirms with the human: *"This will remove `.pipeline/profiles/<platform>.md`. Functional specs are unaffected. Proceed?"*
3. Agent deletes the profile file:
   ```bash
   rm .pipeline/profiles/<platform>.md
   ```
4. Agent removes any references to the profile from `AGENTS.md` or other config files.
5. Commit:
   ```bash
   git add -A
   git commit -m "docs: remove <platform> implementation profile"
   ```
6. Existing solution walkthroughs (e.g., `feat-82-<platform>-solution.md`) are NOT deleted — they remain as historical records.

#### Listing Active Profiles

To see which platforms are currently configured:
```bash
ls .pipeline/profiles/
```

### Step 8: Ongoing Governance

- **Before every spec-generation run:** Agent reads `.pipeline/constitution.md` only. Implementation profiles are ignored.
- **Before every feature implementation:** Agent reads `.pipeline/constitution.md` AND `.pipeline/profiles/<target-platform>.md`.
- **On conflict:** If a proposed change conflicts with any constitution document, the agent halts and escalates.
- **On evolution:** Human requests an update. Agent reads existing, proposes amendments, waits for approval.

---

## Multi-Platform Scenarios

### Scenario: Same spec, two implementations

```
docs/epics/epic-01-network-topology.md          # Functional (shared)
docs/features/feat-01-node-display.md            # Functional (shared)
docs/user-stories/us-01-view-node-details.md     # Functional (shared)

# [Platform A] implementation
.pipeline/profiles/[platform_a].md
docs/designs/feat-82-[platform_a]-solution.md    # Platform A solution walkthrough

# [Platform B] implementation
.pipeline/profiles/[platform_b].md
docs/designs/feat-82-[platform_b]-solution.md    # Platform B solution walkthrough
```

The agent implements Feature #82 twice — once per platform — each time loading the appropriate profile. The functional specs (Epics, Features, Stories, Use Cases) are written once and shared.

### Scenario: Platform-specific acceptance criteria

If a Feature's acceptance criteria need platform-specific variants, add them as conditional blocks in the Feature markdown:

```markdown
## Acceptance Criteria

### Functional (all platforms)
- Given a network node, When the user selects it, Then the detail panel displays all attributes.

### Platform-Specific
- **[web]**: The detail panel uses a sliding drawer component with smooth transitions.
- **[mobile]**: The detail panel transitions from the bottom of the viewport with brand-specific styling.
```

The spec-generation workers write only the "Functional" criteria. Platform-specific criteria are added during implementation planning (Step 2 of `feature-driven-implementation`).

---

## Integration with Other Skills

| Skill | Reads Functional Constitution? | Reads Implementation Profile? |
|---|---|---|
| `spec-orchestrator` | YES — domain rules, spec standards | NO |
| `schema-specification-engineering` | YES — domain rules, data model constraints | NO |
| `spec-user-story-engineering` | YES — BDD format, domain rules | NO |
| `spec-usecase-engineering` | YES — Use Case formality, domain rules | NO |
| `feature-driven-implementation` | YES — agent behavior, quality gates | YES — platform, coding, testing, build |
