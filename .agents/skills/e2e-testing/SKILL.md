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

- Dependencies are installed with `npm ci` in the app being tested. `test:e2e:all` needs them in both `apps/web` and `apps/admin`.
- The Playwright Chromium browser is installed. `apps/web` and `apps/admin` pin different Playwright versions, so each may need its own browser build. If it is missing, ask the user before installing it.
- The backend is running on port 8081, with its PostgreSQL database. Playwright starts only the frontend, on port 5180 for web or 5174 for admin.
- Flyway has seeded the database. Tests rely on the admin account and chefs from `V1__init.sql`. Do not assume any other test data exists.
- The backend serves the built admin app at `/backoffice`, which the "admin can login and list orders" test in `apps/web/e2e/happy-path.spec.ts` needs. Only the Docker image bundles it, so this test is likely to fail against a plain local `bootRun`. Report any such failure.

Commands:

- Storefront, from `apps/web`: `npm run test:e2e`
- Storefront then admin, from `apps/web`: `npm run test:e2e:all`. If any storefront test fails, the admin tests do not run, so report them as not run.
- Admin, from `apps/admin`: `npm run test:e2e`

## Data Safety
E2E tests create accounts and orders, and one admin test changes an order's status, so they write real data to the target backend. They do not clean up, so this data builds up with each run.

- Run them only against a local backend unless the user explicitly approves another target.
- Check `VITE_API_BASE_URL`, `PLAYWRIGHT_BASE_URL` and `ADMIN_BASE_URL` before running, in the shell and in any `.env` files. Playwright does not load `.env` files, so a value set there reaches the frontend through Vite but not the tests' direct API calls.
- Check for a dev server already running on either frontend port. Outside CI, Playwright reuses it, along with whatever API target it started with.
- If `PLAYWRIGHT_BASE_URL` or `ADMIN_BASE_URL` points at a deployed site, tests write to that site's backend, whatever `VITE_API_BASE_URL` says.
- `apps/web/e2e/layout.spec.ts` always calls `http://localhost:8081`, so setting `VITE_API_BASE_URL` does not redirect every test. Its cart and checkout test reads from localhost but creates its account through the UI, which does follow that variable, so it can use two backends in one run.
- Never print the credentials used in the tests.

## Flaky Tests
Do not copy patterns from `flake-*.spec.ts` files or tests marked `FM-FLAKE-*`, such as the fixed `waitForTimeout(300)` in `flake-dish-modal.spec.ts`. If one of these fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## E2E Test Conventions
- Prefer `getByRole` and `getByLabel`. Use `page.locator` only when no role or label fits. Existing tests do not use `getByTestId`.
- For storefront tests, reuse the helpers in `apps/web/e2e/auth.ts`, which create accounts with unique emails.
- Name new files like the existing `*.spec.ts` files, without the `flake-` prefix.

## Reading Results
The Playwright configs use only the `html` reporter, so the terminal may not show per-test results. To see them, run `npm run test:e2e -- --reporter=list` in each app. Do not pass the flag to `test:e2e:all`, because it would only reach the admin command. When `CI` is set, Playwright retries failed tests (twice for web, once for admin), so report any test that passed only on retry instead of counting it as a clean pass. Report only counts from this run.

## Scope
Follow the Scope section in `AGENTS.md`. Do not change application code just to make a test pass unless the code is actually wrong. Do not change existing tests unnecessarily, weaken assertions, skip tests, or install tools. Do not commit or push unless asked.

## Final Report
Follow the Reporting section in `AGENTS.md`, and also list the user workflows covered and the backend target used.
