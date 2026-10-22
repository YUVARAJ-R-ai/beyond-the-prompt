# Codebase Analysis

The deck is only as good as this step. The aim: build a faithful model of the project you can present without inventing anything. Work top-down (shape) → bottom-up (details). Write findings to `analysis.md` as you go.

## 0. Get the code in front of you

- **Uploaded folder / workspace path** — `view` the root, then explore.
- **GitHub URL** — clone it: `git clone --depth 1 <url> /tmp/repo`. (github.com and codeload.github.com are reachable.)
- **Zip** — unzip into the working directory first.

Then get a quick map:

```bash
# Tree, skipping noise
find . -type d \( -name node_modules -o -name .git -o -name dist -o -name build -o -name __pycache__ -o -name .venv \) -prune -o -type f -print | head -200
# Language / size sense
cloc . 2>/dev/null || (echo "no cloc"; find . -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' | wc -l)
```

## 1. Identify the stack from manifests (don't guess)

Read whatever exists — these are authoritative:

- `package.json` → JS/TS deps, scripts, framework (React/Next/Vue/Express…)
- `requirements.txt` / `pyproject.toml` / `Pipfile` → Python deps (FastAPI/Flask/Django…)
- `pom.xml` / `build.gradle`, `go.mod`, `Cargo.toml`, `Gemfile`
- `Dockerfile` / `docker-compose.yml` → services, ports, datastores
- `.env.example` → external services (DBs, APIs, auth, queues)
- `README.md` → the authors' own description of architecture (cross-check against reality)

Record: languages, frameworks, datastores, external APIs/SDKs, infra (Docker, cloud).

## 2. Find the entry points and layers

- **Frontend** entry: `src/main.*`, `src/index.*`, `App.*`, routes/pages dirs.
- **Backend** entry: `main.py`, `app.py`, `server.*`, `index.*`, the file that boots the server / defines routes.
- **API surface**: grep for route definitions —
  ```bash
  grep -rEn "@app\.(get|post|put|delete)|router\.(get|post)|app\.(get|post)" --include=*.py --include=*.ts --include=*.js . | head -40
  ```
- **Data layer**: models/schemas/ORM files, migrations, SQL.
- **Background work**: workers, cron, queues, n8n/webhook handlers.
- **ML/AI**: model files, inference code, prompt templates, training scripts.

Group what you find into layers (e.g. Client → API → Services → Data → External). That grouping is your architecture diagram.

## 3. Trace one real data-flow path end-to-end

Pick the project's *primary* user action and follow the data:

1. **Entry** — where input originates (a form submit, an API call, a sensor, a file upload).
2. **Transport** — the request path / function calls it triggers.
3. **Processing** — services, business logic, model inference, transforms.
4. **Persistence** — what gets written, and where.
5. **Output** — response, render, notification, side effect.

Write this as a numbered list of steps with the concrete component names from the code. This becomes the "Data flow" slide — a labeled left-to-right (or top-to-bottom) chain.

If the project has 2–3 meaningfully different paths (e.g. a write path and an ML inference path), capture each; you can give each its own slide or arrow track.

## 4. Pull real, citable numbers

Only numbers you actually measured go on slides:

```bash
# Lines of code by language (best signal if available)
cloc --quiet . 2>/dev/null
# Counts
grep -rEc "@app\.(get|post|put|delete)" --include=*.py . | awk -F: '{s+=$2} END{print s" endpoints"}'
ls -1 **/*.test.* **/*.spec.* 2>/dev/null | wc -l   # test files
```

Good callout stats: total LOC, # of endpoints/routes, # of React components, # of data models, # of services, # of tests, # of external integrations. Skip any you can't verify.

## 5. Note what's worth showcasing

- Standout features (what does it *do* that's impressive?).
- Non-obvious engineering decisions (caching, on-device inference, offline-first, a clever fallback).
- Honest status: what's working, what's stubbed, what's planned.

## Output: analysis.md

Structure it so phase 3 can lift directly from it:

```markdown
# <Project> — Analysis
## One-liner
## Stack
- Languages / frameworks / datastores / external services
## Architecture (layers + components)
## Data flow (primary path, numbered steps with component names)
## Stats (measured)
## Showcase features
## Honest status (working / stubbed / planned)
```

Anything not in this file must not appear on a slide.
