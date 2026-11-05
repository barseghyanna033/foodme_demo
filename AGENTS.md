# Agent Guidelines

These rules apply to every agent working in this repository. See [CLAUDE.md](CLAUDE.md) for the architecture and verified commands. Detailed rules are in `.claude/rules/`, and `.agents/rules/` holds the same content.

## Before Changing Code

- Read the code you plan to change, along with its callers, related files, and existing tests.
- Confirm that any function, script, dependency, or service exists before relying on it.
- Use only commands defined in `package.json` or `build.gradle`. Do not invent scripts or assume services are running.
- Check which app the change affects. `apps/web`, `apps/admin`, and `apps/backend` have separate stacks and tooling.

## Coding Standards

- Follow the conventions of the surrounding code. `apps/web` uses TypeScript, `apps/admin` uses JavaScript/JSX, and `apps/backend` uses Java 17.
- Write clean, readable code with meaningful names, and avoid unnecessary duplication.
- Change the database schema by adding a new Flyway migration in `apps/backend/src/main/resources/db/migration`. Do not edit an existing migration.
- Keep a single source of truth: extend existing components, services, and helpers before adding new ones.

## Scope

- Make only the changes the task requires. Do not refactor, reformat, or rename unrelated code.
- Do not add dependencies or change build, deployment, or CI configuration unless the task requires it.
- Do not change application code just to make a test pass unless the code is actually wrong.
- Commit or push only when asked.

## Testing

- Add or update tests when application behavior changes.
- Run the tests relevant to your change after making it:
  - **Backend:** `./gradlew test` in `apps/backend`
  - **Web:** `npm run lint` and `npm run build` in `apps/web`, plus `npm run test:e2e` for user-facing changes
  - **Admin:** `npm run lint` and `npm run build` in `apps/admin`, plus `npm run test:e2e` for user-facing changes
- Before running E2E tests, make sure the backend and database are running. Playwright starts only the frontend.
- Investigate failures. Do not hide them, skip them, or weaken assertions to get a pass.
- Never claim that tests passed unless you ran them and saw them succeed.

## Security

- Never expose, log, print, or commit passwords, API keys, tokens, DSNs, or other secrets.
- Do not modify `.env` files. Add new variable names to the matching `.env.example` with placeholder values only.
- Do not put real credentials in source code, tests, documentation, or command output.
- Do not weaken authentication, authorization, or input validation unless the task explicitly requires it.

## Reporting

Finish each task with:

- A short summary of what changed and why.
- The files created or modified.
- The exact test and check commands you ran, with passed, failed, and skipped results.
- Any tests that could not be run and why, plus any remaining risks.
