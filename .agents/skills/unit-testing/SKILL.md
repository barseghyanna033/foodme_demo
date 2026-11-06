---
name: unit-testing
description: Write and improve unit tests for FoodMe code. Use when testing individual functions, methods, or components in isolation.
---

# Unit Testing Skill

## Goal
Create reliable unit tests for the FoodMe project.

## Instructions
1. Read the code under test and its existing tests.
2. Write focused tests covering normal, boundary, and error cases.
3. Keep tests independent. Mock only external dependencies, and only when using the real one is not practical.
4. Run the relevant unit tests using the commands under Prerequisites and Commands.
5. Investigate failures and report the results.

## Prerequisites and Commands
These apply to backend tests. Run them from `apps/backend`, and use `gradlew.bat` on Windows.

- JDK 17 must be installed. The Gradle toolchain cannot download it, and a newer JDK does not count. Do not install a JDK without asking.
- PostgreSQL is not needed for tests.
- One class:
  - Unix/Linux/macOS: `./gradlew test --tests "am.foodme.backend.<ClassName>"`
  - Windows PowerShell: `.\gradlew.bat test --tests "am.foodme.backend.<ClassName>"`
- Full suite:
  - Unix/Linux/macOS: `./gradlew test`
  - Windows PowerShell: `.\gradlew.bat test`

## Flaky Tests
Do not copy patterns from `flake-*.spec.ts` files or tests marked `FM-FLAKE-*`. If one of these fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## Frontend Code
`apps/web` and `apps/admin` have no unit-test framework. Do not add one without approval. Tell the user about the gap, run `npm run lint` and `npm run build` in that app, and suggest E2E coverage if the change is user-facing.

## Backend Test Conventions
- Model new tests on `DishDtoTest.java`: plain JUnit 5 with no Spring context, in the package `am.foodme.backend`.
- If a test needs Spring or seed data, use the `integration-testing` skill instead.

## Reading Results
Check for `BUILD SUCCESSFUL` and exit code 0 before reporting a pass. Old XML files can remain in `build/test-results/test` after a failed run, so confirm their timestamps are from this run before using their counts.

## Scope
Follow the Scope section in `AGENTS.md`. Do not change production code just to make a test pass unless the code is actually wrong. Do not change existing tests unnecessarily, weaken assertions, skip tests, or install tools. Do not commit or push unless asked.

## Final Report
Follow the Reporting section in `AGENTS.md`, and also list the behaviors covered by tests.
