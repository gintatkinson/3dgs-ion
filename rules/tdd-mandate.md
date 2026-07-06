<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Test-Driven Development (TDD)

**ALWAYS enforce:** All implementation MUST follow the RED-GREEN-REFACTOR cycle.

## The cycle

1. **RED:** Write a failing test FIRST. Run it. Confirm it fails.
2. **GREEN:** Write the minimal code to make the test pass. Run it. Confirm it passes.
3. **REFACTOR:** Clean up the code while keeping tests green.

## Hard constraints

- Code written before its corresponding failing test must be deleted and re-implemented after the test.
- Never skip the "confirm it fails" step — a test that passes before implementation is not a valid driving test.
- Each micro-task (2-5 minutes of work) must have a driving test specified before execution begins.
- Use the test framework specified in the project's implementation profile (`.pipeline/profiles/<platform>.md`).

## Why

TDD prevents false confidence. A test written after the code is confirmation bias — it tests what was built, not what was specified. RED-GREEN-REFACTOR guarantees the test actually validates the requirement.
