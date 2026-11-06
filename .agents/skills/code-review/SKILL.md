---
name: code-review
description: Review FoodMe code changes for bugs, security issues, maintainability, and opportunities for improvement.
---

# Code Review Skill

## Goal
Review code changes and identify real problems before they are merged.

## Instructions
1. Inspect the changed files and understand the purpose of the changes.
2. Review surrounding code and related implementations.
3. Look for bugs, incorrect logic, and edge cases.
4. Check error handling and input validation.
5. Check security risks, including exposed secrets and unsafe operations.
6. Look for duplicated code and unnecessary complexity.
7. Check whether relevant tests were added or updated.
8. Run appropriate checks when requested and when safe.
9. Do not modify files during a review unless explicitly asked.
10. Prioritize findings by severity and explain their impact.

## Review Priorities
- Critical: security vulnerabilities, data loss, or application-breaking issues.
- High: major functional bugs.
- Medium: incorrect behavior in specific scenarios.
- Low: maintainability and style improvements.

## FoodMe Guidelines
- Follow the existing architecture and coding conventions.
- Consider the React storefront, React admin, and Spring Boot backend separately.
- Inspect existing tests and project configuration before recommending changes.
- Never expose secrets or modify .env files.

## Final Report
Provide:
- Findings ordered by severity.
- File names and relevant line numbers.
- Explanation of each issue and its impact.
- Recommended fixes.
- Tests or checks executed.
- Any remaining risks.
