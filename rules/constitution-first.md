<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Constitution First

**ALWAYS enforce:** Before beginning any pipeline task, read the project constitution.

## Required reads

1. **Functional constitution** (located at the path resolved from configuration, e.g., `.pipeline/constitution.md`) — domain rules, spec standards, agent behavior, quality gates. Read this before ANY task (specification or implementation).
2. **Implementation profile** (located under the profiles directory, e.g., `.pipeline/profiles/<platform>.md`) — platform-specific coding standards, testing mandates, build config. Read this ONLY when implementing features, not during spec generation.

## Hard constraints

- If the functional constitution file exists in the repository, you MUST read it before starting work. Do not skip it.
- If you are implementing a feature and no implementation profile exists for the target platform, HALT and ask the human to create one.
- If a proposed change conflicts with any constitution document, HALT and escalate to the human.
- Specification workers/modules MUST NOT read implementation profiles — they operate on functional specs only.

## Why

The constitution captures non-negotiable project constraints. Without reading it, agents may violate platform rules, skip required test types, use forbidden dependencies, or produce specs that don't conform to domain standards.
