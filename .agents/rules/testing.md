# Testing Rules

## General Testing Principles
- Choose the appropriate test level for each change.
- Write tests that verify observable behavior.
- Keep tests independent and repeatable.
- Use descriptive test names.
- Avoid unnecessary dependencies between tests.

## Unit Tests
- Test individual functions, methods, and components in isolation.
- Cover normal cases, edge cases, and error cases.
- Mock external dependencies when appropriate.
- Keep unit tests fast.

## Integration Tests
- Test interactions between application components.
- Verify API endpoints, services, repositories, and database behavior.
- Use the existing test configuration and conventions.

## End-to-End Tests
- Test important user workflows through the application UI.
- Use stable selectors and meaningful assertions.
- Avoid arbitrary timeouts when better waiting strategies are available.
- Do not make tests depend on execution order.

## Before Running Tests
- Inspect package.json, build.gradle, and existing test configuration.
- Use only test commands that are defined by the project.
- Do not invent test scripts or assume services are running.

## After Running Tests
- Report the exact commands executed.
- Report passed, failed, and skipped tests when available.
- Investigate failures instead of hiding or ignoring them.
- Never claim success without execution evidence.
