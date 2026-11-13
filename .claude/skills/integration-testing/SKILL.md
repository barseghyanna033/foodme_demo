---
name: integration-testing
description: Create and improve integration tests for FoodMe APIs, services, repositories, and database interactions.
---

# Integration Testing Skill

## Goal
Verify that different parts of the FoodMe application work correctly together.

## Instructions
1. Identify the API endpoints, services, repositories, and database interactions involved.
2. Read the existing tests in `apps/backend/src/test`.
3. Test successful responses and error scenarios, including request validation, response data, and status codes.
4. Use the existing `test` profile and the seed data in `apps/backend/src/test/resources/data.sql`.
5. Run the relevant integration tests using the commands under Prerequisites and Commands.
6. Investigate failures and report the results.

## Prerequisites and Commands
Run these from `apps/backend`, and use `gradlew.bat` on Windows.

- JDK 17 must be installed. The Gradle toolchain cannot download it, and a newer JDK does not count. Do not install a JDK without asking.
- PostgreSQL is not needed for tests.
- One class:
  - Unix/Linux/macOS: `./gradlew test --tests "am.foodme.backend.<ClassName>"`
  - Windows PowerShell: `.\gradlew.bat test --tests "am.foodme.backend.<ClassName>"`
- Full suite:
  - Unix/Linux/macOS: `./gradlew test`
  - Windows PowerShell: `.\gradlew.bat test`

## What These Tests Cannot Catch
Tests run on in-memory H2 with Flyway disabled, and Hibernate creates the schema from the entity classes. They do not verify migrations or real seed data.

When a change touches migrations or nullable columns, add a matching case to `data.sql` and state in the final report what was not verified.

## Flaky Tests
Do not copy patterns from tests marked `FM-FLAKE-*`, such as the order-dependent `FM-100001` tests in `OrderControllerTest.java`. If one of these fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## Backend Test Conventions
- Use `@SpringBootTest`, `@AutoConfigureMockMvc` and `@ActiveProfiles("test")`. Model new tests on `ChefControllerTest.java`.
- Existing tests go through controllers with MockMvc. None target repositories directly.

## Shared Seed Data
All Spring tests share `apps/backend/src/test/resources/data.sql`. Before changing it, search for assertions that depend on it, such as the dish count for chef 1 in `DishControllerTest.java` and the active chef count in `ChefControllerTest.java`. Add new rows where no existing count or ordering is affected.

## Reading Results
Check for `BUILD SUCCESSFUL` and exit code 0 before reporting a pass. Old XML files can remain in `build/test-results/test` after a failed run, so confirm their timestamps are from this run before using their counts.

## Scope
Follow the Scope section in `AGENTS.md`. Do not change production code just to make a test pass unless the code is actually wrong. Do not change existing tests unnecessarily, weaken assertions, skip tests, or install tools. Do not commit or push unless asked.

## Final Report
Follow the Reporting section in `AGENTS.md`, and also list the components and interactions tested.
