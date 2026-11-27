# Library API

Ruby on Rails 8 API-only application for a library recruitment task. The repository currently contains the running stack, library catalog, reader registry, and read-only borrowing history. Borrowing and return operations are planned in [BACKLOG.md](BACKLOG.md).

## Start

```bash
docker compose up --build
```

Compose waits for PostgreSQL, prepares the application and queue databases, then starts the API and Solid Queue worker. No manual migration step is needed. The API is at <http://localhost:3000>, the OpenAPI UI at <http://localhost:3000/api-docs>, and the generated specification at <http://localhost:3000/api-docs/v1/swagger.yaml>.

If port 3000 is occupied, use `APP_PORT=3001 docker compose up --build` and replace `3000` with `3001` in the examples. PostgreSQL is also available to local tests at `127.0.0.1:5433` (`DB_PORT` changes this port). The queue database and application database live in PostgreSQL's named `postgres_data` volume. `docker compose down` and rebuilding images preserve data. `docker compose down --volumes` removes it intentionally.

## Example requests

The current HTTP surface exposes a health endpoint, API documentation, books, and readers:

```bash
curl -i http://localhost:3000/up
curl -i http://localhost:3000/api-docs/v1/swagger.yaml
curl -X POST http://localhost:3000/books \
  -H 'Content-Type: application/json' \
  -d '{"book":{"serial_number":123456,"title":"Dune","author":"Frank Herbert"}}'
curl -X POST http://localhost:3000/readers \
  -H 'Content-Type: application/json' \
  -d '{"reader":{"library_card_number":654321,"full_name":"Ada Lovelace","email":"ada@example.com"}}'
curl 'http://localhost:3000/books?page=1&per_page=20'
curl http://localhost:3000/books/123456
curl -X POST http://localhost:3000/books/123456/borrowings \
  -H 'Content-Type: application/json' \
  -d '{"borrowing":{"library_card_number":654321}}'
curl -X POST http://localhost:3000/books/123456/returns
curl -X DELETE -i http://localhost:3000/books/123456
curl http://localhost:3000/readers/654321
```

`GET /up` returns HTTP 200 when Rails starts successfully. `POST /books` and `POST /readers` return `201`; `GET /books` returns only non-archived books and paginates with `page` and `per_page` (default 20, maximum 100). `GET /books/:serial_number` returns the borrowing history from newest to oldest. `POST /books/:serial_number/borrowings` creates a 30-day borrowing, and `POST /books/:serial_number/returns` closes the active borrowing. Both state transitions lock the book row and return `409` for an invalid state. `DELETE /books/:serial_number` archives an available book with `204`; it returns `409` for a borrowed book. Successful responses use `application/json`. Errors use RFC 9457 `application/problem+json` with `type`, `title`, `status`, `detail`, and field-level `errors` where applicable.

## Tests and quality gate

With Ruby 3.4.13, the project bundle, and the Compose database running, run:

```bash
bundle install
docker compose up -d db
bin/quality
```

The pre-commit gate runs RuboCop with autocorrection, Reek, test database preparation, and RSpec with 100% line and branch coverage for `app/`. The pre-push hook then runs Mutant. It currently tests three domain methods and requires every generated mutation to be killed. Reek excludes Rails migration DSL files; application and test code remain checked.

To run the gate inside Docker against a separate test database:

```bash
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
- Books and readers use six-digit integer identifiers with database checks and unique indexes. Reader email uniqueness is case-insensitive. Borrowing history is retained; a partial unique index allows at most one active borrowing per book. The due date is exactly 30 days after borrowing.
- There is no authentication or real email delivery in the task scope. The API contract and reminder payloads are tracked in the backlog.
