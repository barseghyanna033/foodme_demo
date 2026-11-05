# FoodMe

Food-ordering application with a customer storefront, an admin back office, and a REST backend, plus an optional monitoring stack.

Follow [AGENTS.md](AGENTS.md) for all work in this repository.

## Architecture

```
apps/web (storefront SPA) ──┐
                            ├── HTTP ──> apps/backend (Spring Boot) ──> PostgreSQL
apps/admin (admin SPA) ─────┘
```

- **Local development:** each app runs separately. In dev mode, both SPAs call the backend on port 8081 unless `VITE_API_BASE_URL` is set.
- **Deployment (`render.yaml`):** `apps/backend/Dockerfile` builds both SPAs into the backend image, so one service serves everything. The storefront is at `/` and the admin SPA at `/backoffice`. The backend's `/admin/**` paths are the JWT-protected admin API.
- **Database:** Flyway manages the `foodme` schema, and Hibernate only validates it (`ddl-auto=validate`).
- **Images:** chef and dish images are stored in PostgreSQL and seeded from `img-seed` on first start.
- **Monitoring (`render-monitoring.yaml`):** Grafana, Prometheus, and Loki run as a separate service. Errors go to GlitchTip through the Sentry SDKs.

## Technologies

| App | Stack |
|---|---|
| `apps/web` | React 19, TypeScript, Vite 8, Tailwind CSS 4, Radix UI, TanStack Query, React Router 7, React Hook Form, Zod, Dexie, i18next, oxlint |
| `apps/admin` | React 18, JavaScript (JSX), Vite 6, react-admin 5, MUI 6, axios, ESLint |
| `apps/backend` | Java 17, Spring Boot 3.3.4 (Web, Data JPA, Security, Validation, Actuator), Flyway, PostgreSQL, JWT (java-jwt), springdoc-openapi, Lombok, Micrometer |
| Tests | Playwright with Chromium (`web`, `admin`); JUnit 5, Spring Boot Test, MockMvc, and H2 (`backend`) |

## Important Directories

| Path | Contents |
|---|---|
| `apps/web/src` | Storefront code: `pages`, `components`, `api`, `hooks`, `schemas`, `locales` |
| `apps/web/e2e` | Storefront Playwright tests |
| `apps/admin/src` | Admin code: `pages`, `api`, `providers`, `security`, `layout` |
| `apps/admin/e2e` | Admin Playwright tests |
| `apps/backend/src/main/java/am/foodme/backend` | `controller`, `service`, `repository`, `model`, `dto`, `security`, `config`, `observability` |
| `apps/backend/src/main/resources/db/migration` | Flyway migrations |
| `apps/backend/src/test` | Backend tests and H2 seed data (`resources/data.sql`) |
| `infra/monitoring` | Monitoring stack |
| `.claude/rules`, `.claude/skills` | Agent rules and skills |

## Prerequisites

- **Node.js and npm** for `web` and `admin`. The Docker builds use Node 22.
- **JDK 17** for the backend. The Gradle toolchain requires it and has no download repository configured, so a newer JDK alone is not enough.
- **PostgreSQL** for running the backend locally, but not for its tests. Connection settings come from the `DB_*` variables in `application.properties` and default to `localhost:5432/foodme`.

## Running the Applications

Run each command from the directory shown. On Windows, use `gradlew.bat` instead of `./gradlew`.

```bash
# apps/backend: serves on port 8081 (or $PORT)
./gradlew bootRun

# apps/web: uses the same port as the Playwright config
npm ci
npm run dev -- --port 5180

# apps/admin: uses the same port as the Playwright config
npm ci
npm run dev -- --port 5174
```

The backend also exposes `/swagger-ui.html` and `/actuator/health`.

## Tests, Lint, and Build

| App | Directory | Command | Purpose |
|---|---|---|---|
| Backend | `apps/backend` | `./gradlew test` | Runs all tests with the `test` profile and in-memory H2 |
| Backend | `apps/backend` | `./gradlew test --tests "am.foodme.backend.DishControllerTest"` | Runs one test class |
| Web | `apps/web` | `npm run lint` | Lints with oxlint |
| Web | `apps/web` | `npm run build` | Type-checks with `tsc -b`, then builds |
| Web | `apps/web` | `npm run test:e2e` | Runs storefront Playwright tests |
| Web | `apps/web` | `npm run test:e2e:all` | Runs storefront, then admin Playwright tests |
| Admin | `apps/admin` | `npm run lint` | Lints with ESLint |
| Admin | `apps/admin` | `npm run build` | Builds |
| Admin | `apps/admin` | `npm run test:e2e` | Runs admin Playwright tests |

Keep these limits in mind:

- **E2E services:** Playwright starts only the frontend dev server. The tests also call the API on port 8081 by default, so the backend and its database must already be running.
- **E2E browser:** the Playwright Chromium browser must be installed.
- **Missing tooling:** the frontends have no unit-test framework, and the backend has no lint task.
- **Flaky tests:** some tests are marked as flaky by a `flake-*.spec.ts` filename or an `FM-FLAKE-*` tag. Investigate these failures instead of assuming a cause.

## Repository Caveats

- `.env.example` refers to `infra/docker-compose.yml` and `docs/deployment.md`, but neither exists in this repository. Do not rely on Docker Compose commands.
- The root `README.md` is a step-by-step deployment guide for Render, not a developer guide.

## Rules and Skills

These rules apply to all work in this repository:

- [.claude/rules/code-quality.md](.claude/rules/code-quality.md): coding, security, and reporting standards
- [.claude/rules/testing.md](.claude/rules/testing.md): test levels and how to run and report tests

Skills in `.claude/skills/`: `code-review`, `unit-testing`, `integration-testing`, `e2e-testing`.
