<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Task: Set Up a Project Constitution

You are given a new project repository that needs governance documents established.

Using the `project-constitution` skill:

1. Create the functional constitution (`.pipeline/constitution.md`) with domain rules for the configured domain
2. Create an implementation profile for the target platform (`.pipeline/profiles/{platform}.md`)
3. Ensure the functional constitution contains NO platform-specific details
4. Ensure the implementation profile references the functional constitution

## Inputs

- Project name: "Network Topology Viewer"
- Domain: {domain}
- Target platform: {platform}

## Expected Behaviors

- Agent creates `.pipeline/constitution.md` with domain rules, spec standards, agent behavior, quality gates — all platform-independent
- Agent creates `.pipeline/profiles/{platform}.md` with platform-specific coding standards, testing mandates, build config
- The functional constitution does NOT mention React, TypeScript, Jest, or any framework
- The implementation profile references the functional constitution
- Agent commits both files
