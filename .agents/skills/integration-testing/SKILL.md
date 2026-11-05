---
name: integration-testing
description: Create and improve integration tests for FoodMe APIs, services, repositories, and database interactions.
---

# Integration Testing Skill

## Goal
Verify that different parts of the FoodMe application work correctly together.

## Instructions
1. Inspect the components and interactions that need testing.
2. Review existing integration tests and follow their conventions.
3. Identify API endpoints, services, repositories, and database interactions involved.
4. Use the existing test framework and configuration.
5. Test successful responses and error scenarios.
6. Verify request validation, response data, and relevant status codes.
7. Use the existing `test` profile and the seed data in `apps/backend/src/test/resources/data.sql`.
8. Avoid modifying production code only to make tests pass.
9. Run the relevant integration tests using the commands under Prerequisites and Commands.
10. Investigate failures and report the results.

## FoodMe Guidelines
- Backend uses Spring Boot 3.3.4 and Java 17.
- Existing backend tests use JUnit 5, Spring Boot Test, and MockMvc.
- Existing tests are located under apps/backend/src/test.
- Inspect build.gradle and existing test classes before making changes.

## Prerequisites and Commands
Run these from `apps/backend`, and use `gradlew.bat` on Windows.

- JDK 17 must be installed. The Gradle toolchain cannot download it, and a newer JDK does not count. Do not install a JDK without asking.
- PostgreSQL is not needed for tests.
- One class: `./gradlew test --tests "am.foodme.backend.<ClassName>"`
- Full suite: `./gradlew test`

## What These Tests Cannot Catch
Tests run on in-memory H2 with Flyway disabled, and Hibernate creates the schema from the entity classes. They do not verify migrations or real seed data.

When a change touches migrations or nullable columns, add a matching case to `data.sql` and state in the final report what was not verified.

## Flaky Tests
Do not copy patterns from tests marked `FM-FLAKE-*`, such as the order-dependent `FM-100001` tests in `OrderControllerTest.java`. If one of these fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## Final Report
Provide:
- Files created or modified.
- Components and interactions tested.
- Commands executed.
- Test results and any remaining issues.
