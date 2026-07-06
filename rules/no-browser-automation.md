<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

# Rule: No Browser Automation

**ALWAYS enforce:** Do not use automated browser tools for UI verification unless the project explicitly mandates it.

## Hard constraints

- Do NOT use `browser_subagent`, headless browsers, Puppeteer, or Selenium for UI verification unless the project's test suite and implementation profile explicitly include E2E testing (e.g., Playwright).
- All web UI verification must be performed manually by the human, with clear instructions provided by the agent.
- If the project uses Playwright or another E2E framework (check the implementation profile), then automated E2E tests ARE permitted — but only through the project's own test framework, never ad-hoc browser scripts.

## What to do instead

- Provide step-by-step manual verification instructions in the solution walkthrough.
- Include screenshots or describe the expected visual state.
- If E2E tests exist in the project, run them via the project's test runner command (e.g. `npm run test:e2e` or similar command specified in the implementation profile).

## Why

Ad-hoc browser automation is flaky, environment-dependent, and creates false confidence. Manual verification by the human or project-configured E2E suites are the only reliable options.
