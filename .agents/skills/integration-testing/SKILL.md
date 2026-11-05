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
7. Use the existing test database configuration.
8. Avoid modifying production code only to make tests pass.
9. Run the relevant integration tests using verified project commands.
10. Investigate failures and report the results.

## FoodMe Guidelines
- Backend uses Spring Boot 3.3.4 and Java 17.
- Existing backend tests use JUnit 5, Spring Boot Test, and MockMvc.
- Existing tests are located under apps/backend/src/test.
- Inspect build.gradle and existing test classes before making changes.
- Do not assume a real PostgreSQL database is available during tests.

## Final Report
Provide:
- Files created or modified.
- Components and interactions tested.
- Commands executed.
- Test results and any remaining issues.
