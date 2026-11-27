# Library API

Ruby on Rails 8 API-only application for a library recruitment task. The repository contains the running stack, library catalog, reader registry, borrowing history, and durable return reminders.

## Start

```bash
docker compose up --build
```

Compose waits for PostgreSQL, prepares the application and queue databases, then starts the API and Solid Queue worker. No manual migration step is needed. The API is at <http://localhost:3000>, the OpenAPI UI at <http://localhost:3000/api-docs>, and the generated specification at <http://localhost:3000/api-docs/v1/swagger.yaml>.

If port 3000 is occupied, use `APP_PORT=3001 docker compose up --build` and replace `3000` with `3001` in the examples. PostgreSQL is also available to local tests at `127.0.0.1:5433` (`DB_PORT` changes this port). The queue database and application database live in PostgreSQL's named `postgres_data` volume. `docker compose down` and rebuilding images preserve data. `docker compose down --volumes` removes it intentionally.

Run `bin/compose-smoke` to verify this behavior in a separately named Compose project. It creates a reader, a book, and a borrowing; persists an enqueued reminder while the worker is stopped; recreates the worker and application containers; then confirms the reminder, borrowing history, API, and OpenAPI document remain available. The script removes only its own project and volume on exit. Set `SMOKE_APP_PORT` if port 3005 is occupied.

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
docker compose exec web ./bin/rails runner 'pp BorrowingReminder.order(:created_at).pluck(:kind, :payload)'
```

`GET /up` returns HTTP 200 when Rails starts successfully. `POST /books` and `POST /readers` return `201`; `GET /books` returns only non-archived books and paginates with `page` and `per_page` (default 20, maximum 100). `GET /books/:serial_number` returns the borrowing history from newest to oldest. `POST /books/:serial_number/borrowings` creates a 30-day borrowing, schedules reminders for three days before and on the due date, and `POST /books/:serial_number/returns` closes the active borrowing. The worker rechecks the borrowing before generating a reminder; the generated Action Mailer payload is logged and saved in `borrowing_reminders`. `DELETE /books/:serial_number` archives an available book with `204`; it returns `409` for a borrowed book. Successful responses use `application/json`. Errors use RFC 9457 `application/problem+json` with `type`, `title`, `status`, `detail`, and field-level `errors` where applicable.

## Tests and quality gate

With Ruby 3.4.13, the project bundle, and the Compose database running, run:

```bash
bundle install
docker compose up -d db
bin/quality
```

The pre-commit gate runs RuboCop with autocorrection, Reek, test database preparation, and RSpec with 100% line and branch coverage for `app/`. The pre-push hook then runs Mutant against the domain methods and requires every generated mutation to be killed. Reek excludes Rails migration DSL files and framework callback classes; application and test code remain checked.

To run the gate inside Docker against a separate test database:

```bash
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgresql://library:library@db:5432/momentum_task_test web bin/quality
```

If `POSTGRES_PASSWORD` is set, substitute its value for `library` in those test URLs.

The checked-in OpenAPI 3.1 contract is generated from executable Rswag request specs. Regenerate and verify it after changing an endpoint:

```bash
bash bin/openapi-quality
```

## Production deployment

Pushing to `main` deploys after the `scan_ruby`, `lint`, and `test` jobs finish successfully. GitHub Actions uploads the immutable commit release to `maciej-ciemborowicz.eu`, builds a Podman image there, and restarts the application and Solid Queue worker through systemd. PostgreSQL data is stored outside releases at `/var/lib/library-api/postgres`, so image and release rebuilds do not remove it.

The API is available at <https://maciej-ciemborowicz.eu/library/api/books> and the interactive OpenAPI documentation at <https://maciej-ciemborowicz.eu/library/api/api-docs>. The deployment needs the `DEPLOY_SSH_PRIVATE_KEY` repository secret. The corresponding public key must allow the `ciembor` account to connect to `maciej-ciemborowicz.eu`. The server keeps its production environment in `/etc/library-api/application.env`; create it once from `deploy/env/production.env.example`, replacing `DB_PASSWORD` with a long random value. This file is never uploaded from GitHub.

## Architecture diagrams

`rails-erd` with `ruby-graphviz` generates the entity relationship diagram in UML notation from Active Record associations and `yard` generates the UML class diagram from Ruby source. The ERD labels each end of a relationship with its cardinality, for example `1`, `0..1`, and `0..*`. Both are development-only dependencies. Install Graphviz first (`brew install graphviz` on macOS or `apt-get install graphviz` on Debian/Ubuntu). Start the Compose database, then generate both SVG files against the test database:

```bash
bundle install
docker compose up -d db
RAILS_ENV=test DATABASE_URL=postgresql://library:library@127.0.0.1:5433/momentum_task_test \
  bin/diagrams
```

The command writes `docs/diagrams/erd.svg` and `docs/diagrams/classes.svg`. Pass a destination directory as its only argument when a different location is needed. Commit refreshed diagrams whenever model associations or the application class structure changes.

### Entity relationship diagram

![Entity relationship diagram](docs/diagrams/erd.svg)

### Class diagram

![Class diagram](docs/diagrams/classes.svg)

## HTTP contract

| Endpoint | Success | Error responses |
| --- | --- | --- |
| `POST /books` | `201` with a book | `400`, `422` |
| `GET /books` | `200` with paginated books | `400` |
| `GET /books/:serial_number` | `200` with full borrowing history | `404` |
| `DELETE /books/:serial_number` | `204` | `404`, `409` |
| `POST /readers` | `201` with a reader | `400`, `422` |
| `GET /readers/:library_card_number` | `200` with a reader | `404` |
| `POST /books/:serial_number/borrowings` | `201` with borrowing timestamps | `400`, `404`, `409` |
| `POST /books/:serial_number/returns` | `200` with the return timestamp | `404`, `409` |

Every JSON success response has a top-level `data` object. Error responses follow RFC 9457 and use `application/problem+json`; for example:

```json
{
  "type": "about:blank",
  "title": "Validation failed",
  "status": 422,
  "detail": "The submitted data is invalid.",
  "errors": { "title": ["can't be blank"] }
}
```

## Design notes

- PostgreSQL is the source of truth. A separate database in the same server holds Solid Queue's tables, keeping job storage apart from library data.
- A one-shot Compose setup service prepares both databases before web and worker start. Repeated runs are safe.
- Rswag serves a checked-in OpenAPI 3.1 document. Its library operations will be generated from request specs as they are implemented.
- Books and readers use six-digit integer identifiers with database checks and unique indexes. Reader email uniqueness is case-insensitive. Borrowing history is retained; a partial unique index allows at most one active borrowing per book. The due date is exactly 30 days after borrowing.
- There is no authentication or real email delivery in the task scope. `ReminderDelivery` represents delivery by saving and logging the full Action Mailer payload; the unique `(borrowing_id, kind)` index makes retried jobs idempotent. If logging fails after the payload is saved, the job fails but its retry does not create or log a duplicate; the payload remains available for operational inspection.
- Reminder schedules use a durable outbox created in the same transaction as a borrowing. Failed enqueue attempts leave the affected schedule pending, and the recurring `EnqueuePendingBorrowingRemindersJob` retries it each minute.
