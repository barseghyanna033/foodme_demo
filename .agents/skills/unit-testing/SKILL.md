---
name: unit-testing
description: Write and improve unit tests for FoodMe code. Use when testing individual functions, methods, or components in isolation.
---

# Unit Testing Skill

## Goal
Create reliable unit tests for the FoodMe project.

## Instructions
1. Inspect the code that needs testing.
2. Identify its expected behavior, edge cases, and possible errors.
3. Inspect existing tests and follow their conventions.
4. Use the testing framework already configured for the relevant application.
5. Write focused tests for individual units of code.
6. Cover normal cases, boundary cases, and error cases.
7. Keep tests independent and avoid unnecessary mocking.
8. Run the relevant unit tests using the commands under Prerequisites and Commands.
9. Analyze failures and report the results.

## FoodMe Guidelines
- Backend uses Java 17, Spring Boot, and JUnit 5.
- Storefront uses React and TypeScript.
- Admin uses React and JavaScript.
- Do not assume a frontend unit-testing framework is installed.
- Inspect package.json and build.gradle before choosing commands.

## Prerequisites and Commands
These apply to backend tests. Run them from `apps/backend`, and use `gradlew.bat` on Windows.

- JDK 17 must be installed. The Gradle toolchain cannot download it, and a newer JDK does not count. Do not install a JDK without asking.
- PostgreSQL is not needed for tests.
- One class: `./gradlew test --tests "am.foodme.backend.<ClassName>"`
- Full suite: `./gradlew test`

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
