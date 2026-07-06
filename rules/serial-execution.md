<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: Serial Execution

**ALWAYS enforce:** Implement strictly **one feature at a time**. Do not start feature N+1 until feature N is completely verified, merged, documented, and closed.

## What this means

- Never work on multiple features simultaneously.
- A feature is "closed" only when: tests pass, code is merged, solution walkthrough is committed, the tracker issue/ticket is closed with a traceability comment, and the parent Epic checklist is updated.
- If the user asks you to start a new feature while one is in progress, remind them of this mandate and confirm they want to abandon or pause the current feature.

## Why

Parallel feature work causes context drift, merge conflicts, and incomplete verification. Serial execution guarantees each feature is fully validated before moving on.
