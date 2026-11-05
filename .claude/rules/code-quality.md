# Code Quality Rules

## General Standards
- Follow the existing coding style and conventions of the project.
- Write clean, readable, and maintainable code.
- Use meaningful names for variables, functions, and classes.
- Avoid unnecessary code duplication.
- Keep changes focused and avoid modifying unrelated files.

## Before Making Changes
- Inspect the existing implementation before editing.
- Check related files and understand the current behavior.
- Do not assume that a function, script, or dependency exists; verify it first.

## Testing
- Add or update tests when changing application behavior.
- Run relevant tests after making changes.
- Never claim that tests passed unless they were actually executed successfully.
- Report any tests that could not be run and explain why.

## Security
- Never expose passwords, API keys, tokens, or other secrets.
- Do not modify `.env` files.
- Do not commit secrets or sensitive configuration.

## Reporting
- Summarize the changes made.
- List the files created or modified.
- Report the tests and checks that were executed and their results.
