---
name: e2e-testing
description: Create and improve end-to-end tests for FoodMe storefront and admin user workflows using Playwright.
---

# E2E Testing Skill

## Goal
Verify that important FoodMe user workflows work correctly from the user interface to the application backend.

## Instructions
1. Identify the user workflow that needs testing.
2. Inspect existing Playwright configuration and E2E tests.
3. Follow existing test structure and naming conventions.
4. Identify required application services and test data.
5. Test the workflow through the UI, from the user's perspective.
6. Verify visible results, navigation, validation, and error handling.
7. Use stable selectors and meaningful assertions.
8. Avoid arbitrary fixed waits and dependencies on test execution order.
9. Do not change existing tests unnecessarily.
10. Run the relevant Playwright tests using verified project commands.
11. Investigate failures and report the results.

## FoodMe Guidelines
- Storefront E2E tests are located in apps/web/e2e.
- Admin E2E tests are located in apps/admin/e2e.
- The project uses Playwright with Chromium.
- Inspect package.json and Playwright configuration before running tests.
- Verify whether the backend and other required services must be started separately.
- Do not assume the application is available or test data exists.

## Final Report
Provide:
- Files created or modified.
- User workflows covered.
- Commands executed.
- Test results and any remaining issues.
