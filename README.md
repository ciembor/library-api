# Library API

Ruby on Rails 8 API-only application for a library recruitment task. This repository currently contains milestone 1: the running application, PostgreSQL, Solid Queue worker, and OpenAPI preview. Book and borrowing endpoints are planned in [BACKLOG.md](BACKLOG.md).

## Start

```bash
docker compose up --build
```

Compose waits for PostgreSQL, prepares the application and queue databases, then starts the API and Solid Queue worker. No manual migration step is needed. The API is at <http://localhost:3000>, the OpenAPI UI at <http://localhost:3000/api-docs>, and the generated specification at <http://localhost:3000/api-docs/v1/swagger.yaml>.

If port 3000 is occupied, use `APP_PORT=3001 docker compose up --build` and replace `3000` with `3001` in the examples. The queue database and application database live in PostgreSQL's named `postgres_data` volume. `docker compose down` and rebuilding images preserve data. `docker compose down --volumes` removes it intentionally.

## Example requests

The current milestone exposes a health endpoint and documentation:

```bash
curl -i http://localhost:3000/up
curl -i http://localhost:3000/api-docs/v1/swagger.yaml
```

`GET /up` returns HTTP 200 when Rails starts successfully. The OpenAPI file currently has no library operations; request examples for books, readers, and borrowings will be added with their endpoints.

## Tests and quality gate

With Ruby 3.4.8 and the project bundle installed, run:

```bash
bundle install
bin/quality
```

The gate runs RuboCop with autocorrection, Reek, RSpec with 100% line and branch coverage for `app/`, and Mutant in that order. The local pre-commit hook runs the same gate. Mutant currently has no domain methods to mutate; later milestones must add mutation subjects and killing specs.

To run the gate inside Docker against a separate test database:

```bash
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgresql://library:library@db:5432/momentum_task_test web ./bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgresql://library:library@db:5432/momentum_task_test web bin/quality
```

If `POSTGRES_PASSWORD` is set, substitute its value for `library` in those test URLs.

Regenerate the OpenAPI file after adding Rswag request specs:

```bash
SIMPLECOV_ENABLED=false bundle exec rake rswag:specs:swaggerize
```

## Design notes

- PostgreSQL is the source of truth. A separate database in the same server holds Solid Queue's tables, keeping job storage apart from library data.
- A one-shot Compose setup service prepares both databases before web and worker start. Repeated runs are safe.
- Rswag serves a checked-in OpenAPI 3.1 document. Its library operations will be generated from request specs as they are implemented.
- There is no authentication or real email delivery in the task scope. The API contract and reminder payloads are tracked in the backlog.
