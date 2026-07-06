<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Verification-Before-Completion

**ALWAYS enforce:** Before declaring any task, micro-task, or feature complete, you MUST provide **concrete proof of correctness**.

## What counts as proof

- Raw test output (pasted terminal output showing test results)
- Build output (pasted compiler/bundler output showing success)
- Explicit file-content verification (showing the actual content of generated/modified files)

## What does NOT count as proof

- "It works" or "tests pass" without pasted evidence
- "I verified it" without showing what was verified
- Summaries of what should have happened
- Assumptions based on previous steps succeeding

## Hard constraints

- Every micro-task completion must include pasted evidence.
- Every feature completion must include full test suite output.
- If you cannot provide proof (e.g., no test runner available), explicitly state this limitation and ask the user to verify manually.

## Why

Agents are prone to hallucinating success. Requiring raw evidence forces ground-truth verification and makes false completions impossible to hide.
