---
name: e2e-testing
description: Create and improve end-to-end tests for FoodMe storefront and admin user workflows using Playwright.
---

# E2E Testing Skill

## Goal
Verify that important FoodMe user workflows work correctly from the user interface to the application backend.

## Instructions
1. Identify the user workflow and the test data it needs.
2. Read `playwright.config.ts` and the existing tests for that app.
3. Test through the UI from the user's perspective, checking visible results, navigation, validation, and error handling.
4. Use the selectors under E2E Test Conventions and meaningful assertions.
5. Avoid fixed waits and dependencies on test execution order.
6. Run the relevant Playwright tests using the commands under Prerequisites and Commands.
7. Investigate failures and report the results.

## FoodMe Guidelines
- Storefront E2E tests are located in apps/web/e2e.
- Admin E2E tests are located in apps/admin/e2e.

## Prerequisites and Commands
Before running tests, confirm that:

- Dependencies are installed with `npm ci` in the app being tested.
- The Playwright Chromium browser is installed. If it is missing, ask the user before installing it.
- The backend is running on port 8081, with its PostgreSQL database. Playwright starts only the frontend, on port 5180 for web or 5174 for admin. Do not assume test data exists.

Commands:

- Storefront, from `apps/web`: `npm run test:e2e`
- Storefront then admin, from `apps/web`: `npm run test:e2e:all`
- Admin, from `apps/admin`: `npm run test:e2e`

## Data Safety
E2E tests create accounts and orders and change order status, so they write real data to the target backend.

- Run them only against a local backend unless the user explicitly approves another target.
- Check `VITE_API_BASE_URL`, `PLAYWRIGHT_BASE_URL` and `ADMIN_BASE_URL` before running.
- `apps/web/e2e/layout.spec.ts` always calls `http://localhost:8081`, so setting `VITE_API_BASE_URL` does not redirect every test.
- Never print the credentials used in the tests.

## Flaky Tests
Do not copy patterns from `flake-*.spec.ts` files or tests marked `FM-FLAKE-*`, such as the fixed `waitForTimeout(300)` in `flake-dish-modal.spec.ts`. If one of these fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## E2E Test Conventions
- Prefer `getByRole` and `getByLabel`. Use `page.locator` only when no role or label fits. Existing tests do not use `getByTestId`.
- For storefront tests, reuse the helpers in `apps/web/e2e/auth.ts`, which create accounts with unique emails.
- Name new files like the existing `*.spec.ts` files, without the `flake-` prefix.

## Reading Results
The Playwright configs use only the `html` reporter, so the terminal may not show per-test results. To see them, run `npm run test:e2e -- --reporter=list`. Report only counts from this run.

## Scope
Follow the Scope section in `AGENTS.md`. Do not change application code just to make a test pass unless the code is actually wrong. Do not change existing tests unnecessarily, weaken assertions, skip tests, or install tools. Do not commit or push unless asked.

## Final Report
Follow the Reporting section in `AGENTS.md`, and also list the user workflows covered and the backend target used.
