<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Task: Implement a Feature Using TDD

You are given a GitHub repository with an open Feature issue and an approved implementation plan.

Using the `feature-driven-implementation` skill, implement the feature following the full workflow:

1. Read the project constitution and implementation profile
2. Checkout a feature branch
3. Decompose the plan into micro-tasks
4. For each micro-task: write a failing test FIRST, then implement, then verify
5. Provide raw test output as proof of completion
6. Commit with a solution walkthrough and close the issue

## Inputs

- Feature issue: `#42 — Display Network Node Attributes`
- Implementation plan: `inputs/implementation_plan.md`
- Constitution: `inputs/constitution.md`
- Implementation profile: `inputs/react-profile.md`

## Expected Behaviors

- Agent writes a failing test before any implementation code
- Agent provides raw test output (not just "tests pass")
- Agent does NOT start a second feature before closing this one
- Agent creates a solution walkthrough at `docs/designs/feat-42-solution.md`
- Agent closes the GitHub issue with a traceability comment
