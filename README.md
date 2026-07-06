<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Digital Systems Engineering Pipeline (Builders Project)

Welcome to the Digital Systems Engineering Pipeline. This repository contains a suite of autonomous AI Agent "Skills" designed to:

1. **Specification-engineer protocol standards** into deterministic, behavior-driven Agile tracking matrices in the active issue tracker.
2. **Implement features** from those backlogs using subagent-driven TDD execution discipline with two-stage review gates.

By feeding these agents a Structural Schema and its associated Normative Specification Document, the agents will automatically build your Epics, Features, User Stories, and UML Use Cases, ensuring a 100% mathematically bounded requirements pipeline mapped via UML OOA/OOD methodologies.

## Documentation at: https://github.com/gintatkinson/digital-pipeline-repo

---

## Governance: The Functional Constitution

This pipeline ships with a **default functional constitution** (located at the configured pipeline configuration directory, e.g., `<pipeline_dir>/constitution.md`) that governs all specification generation (Pipeline 1). It defines:

| Section | What it governs |
|---|---|
| **Domain Rules** | Schema compliance, data model integrity, traceability requirements, conflict resolution between normative text and schema |
| **Specification Standards** | Epic/Feature granularity, BDD scenario format, User Story/Use Case formality, labeling taxonomy |
| **Agent Behavior** | Commit format, branch strategy, documentation standards, idempotency, error handling |
| **Universal Quality Gates** | Validation gates per worker phase, 100% model coverage, cross-reference integrity, human approval scope |
| **Forbidden Practices** | No invented requirements, no platform contamination, no skipped error scenarios, no silent node drops |

The constitution is **read by all skills before execution**. It is the single source of truth for specification quality decisions.

For implementation work (Pipeline 2), platform-specific rules live in **Implementation Profiles** (e.g., `<pipeline_dir>/profiles/<platform>.md`). These are created per-project, per-platform, and are never read by specification workers.

```
<pipeline_dir>/
  constitution.md              <-- Governs Pipeline 1 (all agents read this)
  profiles/
    [platform].md              <-- Governs Pipeline 2 for a specific target stack
```

> To customize: edit the constitution file directly. The constitution is human-authored, agent-enforced.

---

## The Agent Architecture

This toolchain operates on a **Master-Worker architecture** with two distinct pipelines:

### Pipeline 1: Specification Generation (Orchestrator + Workers A-D)

#### Orchestration Module (The Master)
The overarching command-and-control module. It triggers workers in sequence, enforces strict validation gates between phases, and includes error recovery (halt-and-escalate on failure). Configured via the orchestration skill guides.

#### Structural Spec Engineering Module (Worker A: Structure)
Parses raw schemas. Breaks down structural models into **Epics** and **Features** with exhaustive Given-When-Then acceptance criteria, platform scoping, and verbatim spec context injection. Includes duplicate detection to ensure idempotent re-runs.

#### Behavioral Spec Engineering Module (Worker B: Behavior)
Parses operational/deployment chapters. Extracts BDD **User Stories** modeled on UML OOA/OOD principles. Builds a "Cross-Cutting Matrix" linking scenarios to Features. Includes duplicate detection.

#### System Interaction Spec Engineering Module (Worker C: System Interaction)
Extracts formal **UML System Use Cases** (Actors, Preconditions, Main Success Scenarios, Alternate Flows, Postconditions) and maps them to User Stories and Features in a Realization Matrix. Includes duplicate detection.

#### Pipeline Utilities (Worker D & Coverage Check)
* **Backlog Reconciliation Tool**: Zero-trust consistency audit. Queries the active issue tracker provider, syncs checkbox states in local markdown configuration, enforces dependency checks, and auto-closes completed Epics/Stories/Use Cases.
* **UML Compliance Linter**: Automated UML compliance linter. Parses input schemas, builds class/sequence/use-case diagram symbol tables, mathematically verifies 100% model coverage, and asserts OMG UML 2.5.1 metamodel conformance and cross-view consistency rules.

### Pipeline 2: Feature Implementation

#### Governance & Persistent Memory Module
Establishes a project's governing principles (platform constraints, coding standards, testing mandates, domain rules) as a persistent constitution file (e.g. `<pipeline_dir>/constitution.md`). All other skills read this before execution.

#### Feature Implementation Module
The execution engine. Implements features from the backlog using a disciplined, verifiable process. Includes an optional tech stack research phase (configured e.g. in `research.md` or as designated) for features involving unfamiliar or rapidly-evolving frameworks.

**Core execution discipline (14 mandates):**

| # | Mandate | Purpose |
|---|---|---|
| 1 | Serial Execution | One feature at a time, fully closed before next |
| 2 | The Grill Approval | Interactive design review before any code |
| 3 | Traceability | Closing comments link to solution walkthroughs |
| 4 | Agentic Epic Closure | Auto-close Epics when all features complete |
| 5 | No Browser Automation | Manual UI verification (unless project uses Playwright) |
| 6 | Issue Tracker as Source of Truth | Tracker CLI, never trust local state |
| 7 | Cumulative Walkthroughs | Append/merge, never destructive overwrite |
| 8 | Validation Isolation | Separate subagent audit or strict self-audit fallback |
| 9 | **TDD (RED-GREEN-REFACTOR)** | Failing test before code, always |
| 10 | **Micro-Task Decomposition** | 2-5 min tasks with driving test + verification |
| 11 | **Subagent-Driven Development** | Fresh isolated context per micro-task |
| 12 | **Two-Stage Review** | Spec compliance → Code quality, both must pass |
| 13 | **Verification-Before-Completion** | Raw proof (test output) required, no assertions |
| 14 | **Inter-Task Code Review** | Diff against plan, log deviations |

**Additional protocols:**
- **Project Constitution:** Persistent principles file read before every execution
- **Tech Stack Research:** Optional `research.md` phase before The Grill for unfamiliar frameworks
- **Parallel Dispatch `[P]`:** Spec-generation phases 2 & 3 can run in parallel on multi-agent runtimes
- **Systematic Debugging (4-phase):** Reproduce → Diagnose (stack trace, no guessing) → Fix (minimal upstream) → Verify (full suite)
- **Data Flow Slicing Order:** Persistence → Transformation → Interface

---

## Always-Loaded Governance Rules

In addition to skills (loaded on-demand), this pipeline includes **rules** — constraints injected into every agent session regardless of which skill is active. When installed via Tessl, these rules are automatically distributed to agent-specific config files (such as `.cursor/rules/`, `CLAUDE.md`, `AGENTS.md`).

| Rule | Enforcement |
|---|---|
| **`serial-execution`** | One feature at a time. No parallel feature work. |
| **`tdd-mandate`** | RED-GREEN-REFACTOR cycle required. Code before test must be deleted. |
| **`verification-required`** | Raw proof (pasted output) required. "It works" without evidence is forbidden. |
| **`constitution-first`** | Read the constitution file (e.g. `<pipeline_dir>/constitution.md`) before any task. Spec workers must NOT read implementation profiles. |
| **`no-browser-automation`** | No ad-hoc browser scripts. Manual verification or project E2E framework only. |
| **`tracker-source-of-truth`** | Use the issue tracker's CLI tool resolved from configuration to query issue state. |
| **`platform-independence`** | Specs must be functional. No framework names in features, stories, or use cases. |

These rules live in the rules directory (e.g. `rules/`) and are packaged into the Tessl plugin alongside skills. Without Tessl, agents can read them directly from the configured rules directory.

---

## Installation

The pipeline requires Python 3, the configured tracker CLI, and git. Python scripts require `PyYAML` to parse configuration and issue frontmatter (install via `pip install -r requirements.txt`). Choose the method that fits your team's workflow.

### Selecting a Version
* **Stable Version (`master` branch)**: The default production release.
* **Refactored Version (`refactor` branch)**: Remediated version featuring the latest geodetic model fixes, UML linter improvements, and all adversarial audit corrections.

---

### Installation Option 1: Native GitHub Template (Recommended)

To create a new project workspace directly from the template repository on GitHub's servers:

1. Use the GitHub CLI to create the repository on GitHub from the template and clone it locally:
   ```bash
   gh repo create my-new-app --template gintatkinson/digital-pipeline-repo --public --clone
   ```

---

### Installation Option 2: Direct Copy (Simplest)

Copy the `skills/`, `rules/`, `.pipeline/`, and `.agents/` directories into your project repository.

**For Stable Version (`master`):**
```bash
git clone https://github.com/<owner>/<template-repo>.git ./.tmp-pipeline
rm -rf ./skills ./rules ./.pipeline ./.agents
cp -RP ./.tmp-pipeline/skills ./
cp -RP ./.tmp-pipeline/rules ./
cp -RP ./.tmp-pipeline/.pipeline ./
cp -RP ./.tmp-pipeline/.agents ./
cp ./.tmp-pipeline/requirements.txt ./
rm -rf ./.tmp-pipeline
```

**For Refactored Version (`refactor`):**
```bash
git clone -b refactor https://github.com/<owner>/<template-repo>.git ./.tmp-pipeline
rm -rf ./skills ./rules ./.pipeline ./.agents
cp -RP ./.tmp-pipeline/skills ./
cp -RP ./.tmp-pipeline/rules ./
cp -RP ./.tmp-pipeline/.pipeline ./
cp -RP ./.tmp-pipeline/.agents ./
cp ./.tmp-pipeline/requirements.txt ./
rm -rf ./.tmp-pipeline
```

Then point your agent at the `skills/` directory. This is a one-time copy -- you manage updates manually.

---

### Installation Option 3: Git Submodule (Versioned, Updatable)

Add the pipeline as a Git submodule so your project tracks a specific version and can pull updates.

**For Stable Version (`master`):**
```bash
git submodule add https://github.com/<owner>/<template-repo>.git .pipeline-skills
```

**For Refactored Version (`refactor`):**
```bash
git submodule add -b refactor https://github.com/<owner>/<template-repo>.git .pipeline-skills
```

To update to the latest version of the submodule:
```bash
git submodule update --remote .pipeline-skills
git add .pipeline-skills && git commit -m "chore: update pipeline skills"
```

#### Submodule Path Configuration

When using the Git Submodule method, the skills and rules directories are nested inside `.pipeline-skills/`. You must create a `skills.json` file at your project root to register these paths for automatic agent discovery:

```json
{
  "entries": [
    { "path": ".pipeline-skills/skills" }
  ]
}
```

For workspace-scoped rules, update your agent configuration to point to `.pipeline-skills/rules/` instead of `./rules/`.

---

### Installation Option 4: Tessl Registry (Managed Distribution)

Use Tessl for version-locked, team-wide distribution with automated rule injection and quality evaluation. See the [Tessl Integration](#tessl-integration-skill-registry--evaluation) section below for full details.

**For Stable Version (`master`):**
```bash
tessl init --agent gemini --agent claude-code --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo
```

**For Refactored Version (`refactor`):**
```bash
tessl init --agent gemini --agent claude-code --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo#refactor
```

### Setup for Google Antigravity / Gemini CLI

After installing the pipeline via any method above, configure Gemini to load the skills and rules:

1. **Point Gemini at the skills directory.** In your Gemini CLI session or Antigravity project config, reference the skill files:

   ```
   # If using direct copy or submodule:
   Read the files in ./skills/ and ./rules/ directories.

   # If using Tessl:
   Tessl auto-injects rules. Skills are loaded via MCP or the .tessl/ directory.
   ```

2. **AGENTS.md (recommended).** Create an `AGENTS.md` file in your project root that tells Gemini (and any other agent) where to find the pipeline:

   ```markdown
   # Agent Instructions

   ## Pipeline Skills
   This project uses the Digital Systems Engineering Pipeline.
   - Skills: read all SKILL.md files in the configured skills directory (e.g., `skills/` or `.pipeline-skills/skills/`)
   - Rules: read all files in the configured rules directory (e.g., `rules/` or `.pipeline-skills/rules/`) -- these are mandatory constraints that apply to every task
   - Constitution: read the constitution file (e.g. `<pipeline_dir>/constitution.md`) before any task
   - Implementation profiles: read the implementation profile (e.g. `<pipeline_dir>/profiles/<platform>.md`) before implementing features
   ```

3. **Subagent dispatch.** Gemini CLI supports subagent tool calls with curated context. The `feature-driven-implementation` skill includes Gemini-specific dispatch instructions in Step 3.

### Setup for Claude Code

```bash
# If using Tessl (auto-configures CLAUDE.md and MCP):
tessl init --agent claude-code
tessl install github:gintatkinson/digital-pipeline-repo

# If using direct copy, add to CLAUDE.md:
echo "Read all SKILL.md files in skills/ and all rule files in rules/ before starting any task." >> CLAUDE.md
```

### Setup for Cursor / Windsurf / Cascade

```bash
# If using Tessl (auto-configures .cursor/rules/):
tessl init --agent cursor
tessl install github:gintatkinson/digital-pipeline-repo

# If using direct copy, create .cursor/rules/pipeline.mdc or .windsurf/rules/pipeline.md
# referencing the skills/ and rules/ directories.
```

---

## Supported Runtimes

The skills are runtime-agnostic markdown files. The `feature-driven-implementation` skill includes runtime-specific dispatch instructions:

| Runtime | Subagent Dispatch | Two-Stage Review |
|---|---|---|
| **Claude Code** | `Task("prompt")` — native isolated subagent | Separate reviewer subagents |
| **Gemini CLI** | Subagent tool call with curated context | Separate reviewer subagents |
| **Cascade (Windsurf/Devin)** | Coordinator re-reads files per task to simulate isolation; user opens new chat for true isolation | Explicit self-audit documented in `task.md` |

---

## How to Run the Specification Pipeline

**Prerequisites:** AI agent framework capable of reading `.md` skill files + executing CLI commands required by the configured tracker (e.g. git, tracker CLI).

1. Ensure your AI agent has access to the configured skills directory.
2. Provide your agent with the following prompt:

> **Specification Generation Prompt:**
>
> "Adopt the specification orchestrator skill. I want to specification-engineer [Protocol Standard, e.g., standard protocol schemas].
>
> 1. The structural schemas are located at `[path to schemas]`.
> 2. The normative specification documents are located at `[path to specs]`.
>
> Execute the full digital engineering pipeline."

---

## How to Implement a Feature

**Prerequisites:**
- AI agent framework capable of reading `.md` skill files.
- The target implementation profile configured (e.g. `.pipeline/profiles/react.md`).
- For Firestore target profiles, the local Firestore database emulator must be running (start via: `npx firebase-tools emulators:start --only firestore`).

> **Feature Implementation Prompt:**
>
> "Adopt the feature driven implementation skill. I want to implement Feature [Issue Number, e.g., #82] targeting platform [react | flutter].
>
> Execute the full delivery workflow with TDD execution discipline:
>
> 0. Pre-Execution Seeding & Rules Verification:
>    - Ensure the downstream workspace is correctly initialized using the native GitHub Template or one of the manual installation methods.
>    - Read and adhere to the Project Constitution (`.pipeline/constitution.md`), specifically Section 4.5 (Downstream Conformance Gates) and Section 5 (Forbidden Practices - do NOT delete or bypass the layout splitters, timeline scrubber, or focus-loss property grid).
>    - Adhere to the Section 1.9 Zero-Mocking Live Persistence Mandate (no in-memory mock repositories in final DI).
>
> 1. Map dependencies from the backlog directory (e.g. `docs/epics/`, `docs/features/`).
> 2. Draft an implementation plan covering the full vertical slice:
>    - Database/Persistence Layer (abstract repository interfaces, concrete transport adapters, zero-mocking local emulator integration)
>    - Logic & Parser Layer (decoupled clean domain models, types, validation, hooks)
>    - UI & Presentation Layer (logical components, container queries, resizable layout splitters, SVG outline icons)
>    - Test Plan (failing integration/unit tests to write BEFORE implementation)
> 3. Decompose into micro-tasks (2-5 min each, with driving test per task).
> 4. Present the plan for approval (The Grill).
> 5. Execute via subagent-driven TDD loop (RED-GREEN-REFACTOR per task).
> 6. Two-stage review after each task (spec compliance, then code quality).
> 7. Verification Proof:
>    - Run the compliance engine: `python3 scripts/verify_downstream_baseline.py [react | flutter] <destination_path>`.
>    - Provide the raw test/build output of this script as proof of conformance.
> 8. Provide step-by-step human manual testing instructions.
> 9. Deliver the cumulative solution walkthrough and close the issue upon human approval."

---

## Downstream Baseline Compliance

To enforce consistent architecture, layout controls, and validation gates across downstream repositories, the pipeline includes automation scripts for compliance verification.

### Running Compliance Verification Gates
To verify that a downstream workspace adheres to the Project Constitution (including mandated types and passing compilation/tests) run:
```bash
python3 scripts/verify_downstream_baseline.py [react | flutter] <destination_path>
```
* **React Checks**: Asserts presence of core React baseline files, checks for mandated domain classes in `types.ts` (loaded dynamically from target config files like `.pipeline/logical-ui/codebase_rules.json`, `codebase_rules.json`, or `baseline_manifest.json` under `"validation_rules" -> "mandated_classes"` or at root; otherwise falls back to defaults), and verifies compilation/packaging via `npm run build`.
* **Flutter Checks**: Asserts presence of core Flutter baseline files, checks for mandated domain classes in `types.dart` (loaded dynamically from target config files if present; otherwise falls back to defaults), and runs full diagnostics and test suite via `flutter analyze && flutter test`.

---

## Expected Outputs

### Specification Pipeline
A perfectly synchronized taxonomy on your live issue tracker board:

1. **Epics (`epic`)**: High-level structural containers.
2. **Features (`feature`)**: Granular technical building blocks with verbatim spec text and dependency links.
3. **User Stories (`user-story`)**: Object-oriented BDD scenarios mapped to required Features.
4. **Use Cases (`use-case`)**: Formal UML system interactions mapped down to User Stories and Features.

### Implementation Pipeline
For each delivered feature:

1. **Solution Walkthrough** (`<walkthrough_dir>/feat-<Issue_Number>-solution.md` or as configured): Cumulative record of changes, testing, and verification, including a **Code Realization Table** mapping features/attributes to implemented source files, classes, and functions.
2. **Passing test suite**: All tests green with raw output as evidence.
3. **Closed Tracker Issue**: With direct link to the committed solution walkthrough.
4. **Updated Epic checklist**: Feature marked `[x]`, Epic auto-closed when all features complete.

*Note: Skills automatically bootstrap repository labels (epic, feature, user-story, use-case) via the configured label bootstrap command.*

---

## Tessl Integration (Skill Registry & Evaluation)

This pipeline's skills conform to the [Agent Skills specification](https://agentskills.io/specification) and are compatible with [Tessl](https://tessl.io/) — the package manager and governance platform for AI agent skills.

### Install Skills via Tessl

**For Stable Version (`master`):**
```bash
tessl init --agent claude-code --agent cursor --agent gemini
tessl install github:gintatkinson/digital-pipeline-repo
tessl install github:gintatkinson/digital-pipeline-repo --skill spec-orchestrator
```

**For Refactored Version (`refactor`):**
```bash
tessl init --agent claude-code --agent cursor --agent gemini
tessl install github:gintatkinson/digital-pipeline-repo#refactor
tessl install github:gintatkinson/digital-pipeline-repo#refactor --skill spec-orchestrator
```

### Publish to a Private Registry

Package your organization's customized pipeline skills for team-wide distribution:

```bash
# Import a skill into Tessl plugin format
tessl skill import skills/spec-orchestrator

# Review and auto-optimize skill quality
tessl skill review skills/spec-orchestrator --optimize

# Publish to your org's private workspace
tessl skill publish skills/spec-orchestrator --workspace your-org
```

### Evaluate Skill Quality

Tessl provides three evaluation layers critical for safety-critical domains:

- **Skill Review** — `tessl skill review skills/spec-orchestrator --threshold 80` scores structural quality and compliance with the Agent Skills spec. Use as a CI gate.
- **Task Evals** — `tessl eval run` tests whether agents perform better *with* your skills vs *without*, measuring specification accuracy and compliance.
- **Scenario Evals** — `tessl scenario generate` creates realistic evaluation scenarios from your skills to regression-test agent behavior.

### MCP Integration

```bash
# Start the Tessl MCP server for structured agent access
tessl mcp start
```

Agents pull version-locked context from the registry via MCP instead of parsing raw markdown files — preventing context-window overflow and ensuring version consistency across teams.

### Tessl + This Pipeline Architecture

```
┌──────────────────────────────────────────┐
│        TESSL REGISTRY (SaaS/Private)     │
│  Versioned, evaluated plugin packages    │
│  for all domain-specific pipelines       │
└─────────────────────┬────────────────────┘
                      │  tessl install / MCP
                      ▼
┌──────────────────────────────────────────┐
│         AI AGENT (any runtime)           │
│  Claude Code / Gemini / Cursor / Copilot │
│  Pulls verified skills + context bundles │
└─────────────────────┬────────────────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
┌──────────────────┐  ┌──────────────────┐
│  RULES (always)  │  │ SKILLS (on-task) │
│  serial-exec     │  │ spec-orchestrator│
│  tdd-mandate     │  │ Workers A/B/C    │
│  verification    │  │ feature-impl     │
│  constitution    │  │ constitution     │
│  platform-indep  │  │                  │
│  tracker-sot     │  │                  │
│  no-browser      │  │                  │
└──────────────────┘  └──────────────────┘
     Always loaded       Loaded per task
```

---

## Spec Kit Compatibility

This pipeline can also be used **alongside** [Spec Kit](https://github.com/github/spec-kit) without conflict:

- **`specify init`** can bootstrap agent-specific config files (`.claude/`, `.windsurf/`, etc.) in project repos.
- **`.specify/memory/constitution.md`** is analogous to this pipeline's constitution — use whichever convention your project prefers.
- **This pipeline replaces** `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, and `/speckit.implement` with its own more rigorous equivalents (schema-to-spec automation, The Grill, micro-task TDD, two-stage review).
- **This pipeline does NOT depend on Spec Kit.** All skills are pure markdown files that any agent can read directly — no CLI installation required.

## Documentation at: https://github.com/gintatkinson/digital-pipeline-repo

