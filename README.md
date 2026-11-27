# Library API

Recruitment task implemented with Ruby on Rails, PostgreSQL and Docker Compose.

## Run with Docker

Start the application and PostgreSQL:

```bash
docker compose up --build
```

The API is available at `http://localhost:3000`; `GET /up` confirms that Rails is running. PostgreSQL data lives in the named `postgres_data` volume, so rebuilding the application image or recreating containers preserves it. Remove the volume only when a clean database is intended:

If port `3000` is occupied, choose another host port without changing the container configuration:

```bash
APP_PORT=3001 docker compose up --build
```

```bash
docker compose down --volumes
```

## Development quality gate

Install the bundle and run the complete gate:

```bash
bundle install
bin/quality
```

The commands run in this order:

1. RuboCop with automatic correction;
2. Reek, with every reported code smell failing the gate;
3. RSpec with 100% line and branch coverage for every file in `app/`;
4. Mutant with the RSpec integration.

Mutation testing intentionally disables SimpleCov for Mutant's child processes. Coverage is already enforced by the preceding RSpec command; disabling it there prevents partial subprocess reports from replacing the full-suite report.

The local Git repository uses `.githooks/pre-commit` through `core.hooksPath`, configured during project setup. Every commit runs `bin/quality`.

At this initial Rails skeleton, Mutant reports zero mutation subjects because no domain methods exist yet. Its exit status is nevertheless a required gate. New production methods must have mutation-killing examples before they can pass the hook.
