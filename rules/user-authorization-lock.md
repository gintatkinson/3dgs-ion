<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: User Authorization Lock & Karpathy Compliance Check

**ALWAYS enforce:** The agent must run the 4-point Karpathy and Pipeline Compliance Check in every thought block and lock all modifying tools until authorized by the keyword `PROCEED`.

## Hard constraints

- The agent is strictly forbidden from invoking any file-writing tools (`write_to_file`, `replace_file_content`, `multi_replace_file_content`) or terminal execution tools (`run_command`) unless the user's latest message contains the word `PROCEED` (case-insensitive).
- **Subagent Authorization**: To authorize spawned subagents to modify files or execute commands, the coordinator agent MUST append the keyword `PROCEED` (case-insensitive) to the end of the subagent's task prompt. The `invoke_subagent` tool is locked when used to spawn modifying subagents (i.e. those with `PROCEED` in their task prompt), requiring the coordinator to verify that the user's latest message in the main chat explicitly contains the word `PROCEED` (case-insensitive) before dispatching.
- Every agent thought block MUST begin with the 4-point Karpathy and Pipeline Compliance Check:
  * Is the user's message a question/inquiry or a direct command?
  * Has the user explicitly approved a file-write/command execution for this turn? (Yes/No)
  * Am I making any silent assumptions about the user's intent?
  * Does the active skill mandate context-isolated subagent dispatches? (If yes, coordinator direct file-writing is locked).

## Why

To prevent the agent from making silent assumptions, performing unapproved actions, or violating the Karpathy guidelines in response to diagnostic or analytical questions.
