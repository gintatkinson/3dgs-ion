<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Task: Specification-Engineer a Protocol Standard

You are given a structural schema file and its associated normative specification document.

Using the `spec-orchestrator` skill, execute the full digital engineering pipeline:

1. Parse the structural schema and extract Epics and Features (Worker A)
2. Extract BDD User Stories from the normative text (Worker B)
3. Extract UML Use Cases from the normative text (Worker C)
4. Run backlog reconciliation and model coverage verification (Worker D)

## Inputs

- Structural schema: `inputs/schema.[ext]`
- Normative text: `inputs/specification.txt`

## Expected Outputs

- Epic markdown files in `docs/epics/`
- Feature markdown files in `docs/features/` with Given-When-Then acceptance criteria
- User Story markdown files in `docs/user-stories/` with BDD scenarios
- Use Case markdown files in `docs/use-cases/` with UML flows
- GitHub issues created with correct labels and cross-references
- 100% model coverage verification passing
