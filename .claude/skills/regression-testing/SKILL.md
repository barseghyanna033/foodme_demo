---
name: regression-testing
description: Reproduce FoodMe bugs and add focused regression tests that fail before the fix and pass after it. Use when fixing a bug or guarding against one coming back.
---

# Regression Testing Skill

## Goal
Show that a bug is real, then add the smallest test that fails with the bug and passes without it.

## Prerequisites and Commands
Run these from `apps/backend`. Use `./gradlew` in a POSIX shell and `.\gradlew.bat` in Windows PowerShell.

- JDK 17 must be installed. The Gradle toolchain cannot download it, and a newer JDK does not count. Do not install a JDK without asking.
- PostgreSQL is not needed for tests. They use the `test` profile with in-memory H2.
- One test method:
  - `./gradlew test --tests "am.foodme.backend.<ClassName>.<methodName>"`
  - `.\gradlew.bat test --tests "am.foodme.backend.<ClassName>.<methodName>"`
- One class:
  - `./gradlew test --tests "am.foodme.backend.<ClassName>"`
  - `.\gradlew.bat test --tests "am.foodme.backend.<ClassName>"`
- Full suite:
  - `./gradlew test`
  - `.\gradlew.bat test`
- If the output shows `:test UP-TO-DATE`, the tests did not run. Add `--rerun-tasks` to the same command, which also reruns the other tasks in the build, such as compilation:
  - `./gradlew test --rerun-tasks`
  - `.\gradlew.bat test --rerun-tasks`

Do not run `gradlew clean` inside OneDrive. If Gradle reports `Unable to delete directory`, run the tests from a copy outside OneDrive, keep the source changes in the repository in sync, and say in the report that you used a copy.

## Instructions
1. Read the bug report, the code involved, its callers, and its existing tests.
2. Reproduce the bug before fixing it, when feasible.
3. Choose the lowest test level that shows the bug.
4. Write the test and run only that test. Confirm that it fails for the expected reason.
5. Make the smallest fix for the root cause.
6. Run the narrow test again, then the class, then the full suite.
7. Investigate any failure and report the results.

## Reproducing the Bug
- A failing test is the preferred reproduction because it needs no PostgreSQL and can be rerun.
- Record the actual symptom, such as the status code, exception, or wrong value.
- A failure counts only if it matches the reported bug. A compile error, a context startup failure, or a bad test setup does not count. Check the test output, or the XML in `build/test-results/test`, for the actual failure.
- If you cannot reproduce the bug, for example because it depends on production data or an external service, do not claim that you did. Report what you tried and what remains unverified.

If the fix already exists, as it did for FOOD-1:
1. Add the test and confirm that it passes.
2. Temporarily remove only the fix, without staging or committing the change.
3. Run the narrow test and confirm that it fails with the original symptom.
4. Restore the fix, check with `git diff` that the production file is back to its original state, and run the test again.

If the file has unrelated uncommitted changes, reverse your edit by hand. Do not discard them with a git command.

## Writing the Test
- Test one behavior, and assert the behavior the bug broke. A status check alone is often too weak. The FOOD-1 endpoint tests also check that the affected dish is in the response.
- For mapping or other pure logic, use plain JUnit 5 with no Spring context, as in `DishDtoTest.java`.
- For endpoint behavior, use `@SpringBootTest`, `@AutoConfigureMockMvc`, and `@ActiveProfiles("test")`, as in `ChefControllerTest.java` and `DishControllerTest.java`.
- Use both levels when the bug appears at an endpoint but starts in lower-level logic. FOOD-1 covers `DishDto.mapEntityToDto` directly, and also covers `/api/chef/{id}` and `/api/dish/{chefId}/active`.
- Put new tests in the package `am.foodme.backend`, name them `method_expectedBehavior`, and put the ticket ID in a comment above the test, such as `// FOOD-1`.
- Add a test next to related tests in an existing class when one fits.

## H2, Flyway, and Seed Data
Tests run on H2 in PostgreSQL mode with Flyway disabled, and Hibernate creates the schema from the entity classes. This has several consequences:

- Tests do not run migrations or use the real seed data. A passing test does not prove that a migration works.
- H2 nullability comes from the entity annotations, while production nullability comes from the migrations. If a bug depends on a column's nullability, read both and report any difference.
- H2 is not PostgreSQL. Do not treat a passing test as proof of PostgreSQL-specific SQL behavior.
- To fix a schema bug, add a new Flyway migration. Do not edit an existing one.
- State in the final report what could not be verified on H2.

All Spring tests share `apps/backend/src/test/resources/data.sql`:

- Before changing it, search for assertions that depend on it, such as the dish count for chef 1 in `DishControllerTest.java`, the active chef count in `ChefControllerTest.java`, and the first dish result for chef 1.
- Add rows where no existing count or ordering is affected. FOOD-1 added dish 5, with a null `name_am`, to chef 2 for this reason.
- Use explicit, unused IDs and keep the file in UTF-8, because it contains Armenian and Russian text.
- Do not put real credentials in seed data.

## Avoiding Flaky Tests
Do not copy patterns from tests marked `FM-FLAKE-*`:

- `FM-FLAKE-02` in `OrderControllerTest.java` depends on execution order and on the order number sequence.
- `FM-FLAKE-03` in `DishControllerTest.java` depends on which row comes first in a list.
- `FM-FLAKE-04` in `OrderControllerTest.java` compares a stored timestamp with the current date.

Instead:

- Find list items by a stable ID, as in `$.dishes[?(@.id == 5)]`, rather than by position.
- Do not use `@Order`, `Thread.sleep`, or the current date or time in assertions.
- Do not rely on data left behind by another test. Spring tests that use the same configuration can share a context and database, so changes made by one test can affect others. Creating an order also advances the sequence that `FM-FLAKE-02` depends on.
- Generate unique values for data a test creates, as `customerToken()` does in `OrderControllerTest.java`.

If a flaky-marked test fails, investigate and report it. Do not assume it is flaky, and do not retry until it passes.

## Frontend Bugs
`apps/web` and `apps/admin` have no unit-test framework. Do not add one without approval. Use the `e2e-testing` skill for a regression test of a user-facing bug.

## Reading Results
Check for `BUILD SUCCESSFUL` and exit code 0 before reporting a pass. Old XML files can remain in `build/test-results/test` after a failed run, so confirm their timestamps are from this run before using their counts. A passing narrow test does not replace the full suite.

## Scope
Follow the Scope section in `AGENTS.md`. Fix production code only when it is actually wrong, not just to make a test pass. Do not weaken assertions, skip or disable tests, delete failing tests, change unrelated tests, add dependencies, or install tools. Do not commit or push unless explicitly asked.

## Final Report
Follow the Reporting section in `AGENTS.md`, and also include:

- The original symptom, and whether you reproduced it.
- The narrow command and how the test failed before the fix. If you did not see it fail, say so.
- The narrow and full-suite commands after the fix, with passed, failed, and skipped results.
- Anything not verified, including H2 and Flyway gaps.
