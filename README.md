# Nepean Circular

A Phoenix web app that automatically scrapes weekly grocery flyers from local Nepean-area stores and emails subscribers a combined flyer every week.

## Features

- **Automated flyer scraping** — Oban cron jobs scrape store websites daily at 6 AM for new flyers
- **PDF processing** — Uses Python (via `pythonx`) with `pypdf` and `Pillow` to extract flyer pages as images
- **Weekly email digest** — Sends subscribers a combined flyer email every Thursday at 8 AM
- **Email subscriptions** — Subscribe/unsubscribe with token-based one-click unsubscribe
- **Per-store views** — Browse current flyers by store
- **Combined PDF download** — Download all current flyers as a single PDF

## Tech Stack

- **Elixir / Phoenix 1.8** with LiveView
- **Ash Framework** for domain modelling (stores, flyers, subscribers)
- **SQLite** via `ecto_sqlite3` / `ash_sqlite`
- **Oban** (Lite engine) for background jobs and cron scheduling
- **Pythonx** for PDF-to-image extraction (`pypdf`, `Pillow`)
- **Swoosh + Postmark** for transactional email
- **Tailwind CSS v4** for styling
- **Deployed** to DigitalOcean Kubernetes (DOKS) via GitHub Actions CI/CD

## Prerequisites

- Elixir ~> 1.18 / OTP 27
- Python 3.13 (for `pythonx` PDF processing)

## Getting Started

```bash
# Install dependencies and set up the database
mix setup

# Start the Phoenix server
mix phx.server

# Or start inside IEx
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000) in your browser.

## Development

```bash
# Run the precommit checks (compile warnings, format, tests)
mix precommit

# Run tests
mix test

# Run a specific test file
mix test test/nepean_circular/flyers_test.exs
```

## Environment Variables (Production)

| Variable | Description |
|---|---|
| `DATABASE_PATH` | Absolute path to the SQLite database file |
| `SECRET_KEY_BASE` | Phoenix secret key (`mix phx.gen.secret`) |
| `PHX_HOST` | Public hostname (e.g. `nepean.example.com`) |
| `POSTMARK_API_KEY` | Postmark Server API Token for email delivery |
| `PHX_SERVER` | Set to `true` to start the web server |
| `PORT` | HTTP port (default `4000`) |

## Deployment

The app is containerised with a multi-stage Dockerfile and deployed to DigitalOcean Kubernetes. On every push to `main`, the GitHub Actions workflow:

1. Runs tests (`mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix test`)
2. Builds and pushes a Docker image to GitHub Container Registry
3. Applies Kubernetes manifests and rolls out the new image

## Project Structure

```
lib/
├── nepean_circular/
│   ├── flyers.ex            # Ash domain (stores, flyers, subscribers)
│   ├── flyers/              # Ash resources
│   ├── scraping/            # Per-store scraper modules
│   ├── workers/             # Oban workers (scrape, email)
│   ├── pdf.ex               # PDF processing via pythonx
│   ├── emails.ex            # Email templates
│   └── http.ex              # HTTP client helpers
├── nepean_circular_web/
│   ├── live/                # LiveView pages (home, store)
│   ├── controllers/         # Flyer download, unsubscribe, health
│   └── router.ex
```
