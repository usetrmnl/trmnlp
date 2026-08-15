# Hacker News Top Stories

A real, working trmnlp plugin demonstrating the full feature set:

- **Polling strategy** against a real API (`hacker-news.firebaseio.com`)
- **Serverless Python transform** that makes additional HTTP calls (via `urllib`) to enrich the polled response
- **All four screen sizes** rendered with proper TRMNL design-system markup
- **Cross-platform** via Docker — runs on Mac, Windows, or Linux

## What it shows

The HN API's `/v0/topstories.json` endpoint returns a bare JSON array of story IDs. That's not directly useful — for a preview, we want titles, authors, scores, comment counts.

The `src/transform.py` solves that. It defines a `run(input)` function (matching the hosted serverless contract — **same code shape ships to production**):

1. Reads `input["data"]` — the array of top-story IDs
2. Fetches the top 6 stories' detail JSON from `hacker-news.firebaseio.com/v0/item/<id>.json`
3. Returns a clean `{stories: [{rank, title, by, score, comments}, ...]}`

The Liquid templates then iterate the clean list without conditionals. trmnlp executes the Python transform directly inside its own container — no sidecar daemon required.

## Running

```sh
cd examples/hn-stories
docker compose up
```

Then visit **http://localhost:4567/full** in your browser.

The first poll takes a few seconds (one request to the topstories endpoint, then six requests to enrich each story). After that, the framework version, CSS, JS, and rendered HTML are all served locally on your laptop.

## How it's wired

| File | Purpose |
|---|---|
| `.trmnlp.yml` | Local-dev config — enables `transform_runtime: enabled` so trmnlp runs the serverless transform in-process. |
| `src/settings.yml` | Plugin config — `strategy: polling`, the HN polling URL, and `serverless_language: python`. |
| `src/transform.py` | Reads stdin JSON, makes HTTPS requests via `urllib.request`, returns transformed JSON. |
| `src/full.liquid` | Full-screen view. |
| `src/half_horizontal.liquid` | Top or bottom half of a 1Tx1B mashup. |
| `src/half_vertical.liquid` | Left or right half of a 1Lx1R mashup. |
| `src/quadrant.liquid` | One quarter of a 2x2 mashup. |
| `docker-compose.yml` | Wraps `docker run` in a single-service file for quick start. |

## Want stronger sandboxing?

trmnlp executes your transform via a Ruby subprocess inside the container — fast and simple, and the container itself is the isolation boundary. For real microVM isolation (untrusted plugin code), add `serverless_daemon_url: https://...` to `.trmnlp.yml` pointing at a remote transform daemon. The wire format is identical, so your `transform.py` doesn't change.

## Cleaning up

```sh
docker compose down
```
