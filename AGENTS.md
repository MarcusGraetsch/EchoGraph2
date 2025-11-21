# Repository Guidelines

## Project Structure & Module Organization
- `api/` FastAPI service (routers, models, schemas, tasks); run locally with `uvicorn main:app --reload`.
- `frontend/` Next.js 14 app (`src/app`, `components/ui`, `services`, `types`); Tailwind + shadcn/ui design system.
- `ingestion/` text/PDF/DOCX extraction and MinIO storage helpers; `processing/` embedding + chunking utilities and vector store client.
- `infra/` deployment configs; Dockerfiles in service folders; root `docker-compose*.yml` and `deploy.sh` orchestrate the full stack.
- `docs/` architecture, setup, contributing; `data/` for raw/processed artifacts; `tests/` contains vector store integration tests.

## Build, Test, and Development Commands
- Bootstrap prod-like stack: `./deploy.sh` (generates .env, runs docker-compose).
- Compose manually: `docker-compose up -d` and `docker-compose logs -f api` to tail API.
- Backend dev: `cd api && uvicorn main:app --reload --host 0.0.0.0 --port 8000`.
- Backend install: `cd api && pip install -r requirements.txt` (or `pip install -e .` if using pyproject).
- Frontend dev: `cd frontend && npm install && npm run dev` (Next.js at port 3000); build with `npm run build`.
- Lint/format: `cd api && ruff check . && black . && mypy .`; `cd frontend && npm run lint`.

## Coding Style & Naming Conventions
- Python: PEP8, 4-space indent, type hints required; prefer `snake_case` for functions/vars, `PascalCase` for classes; Black + Ruff + MyPy gates.
- TypeScript/React: follow Airbnb/Next.js defaults; `camelCase` for vars/hooks, `PascalCase` for components; keep UI components colocated in `components/ui`.
- API routes live under `api/routers`; keep schemas in `schemas.py` and database changes in `models.py`.

## Testing Guidelines
- Framework: `pytest`; primary suite in `tests/` plus service-specific tests under `api/` as added.
- Run full suite with `pytest` from repo root (requires Qdrant service reachable at 6333); target meaningful assertions over random outputs.
- Add regression tests alongside features; prefer fixtures for external services and clean up inserted vectors/documents.
- Frontend: add Jest/React Testing Library tests under `frontend/src/__tests__` (add `npm test` script if new tests are introduced).

## Commit & Pull Request Guidelines
- Commit messages: Conventional Commits (`feat(api): ...`, `fix(frontend): ...`, `docs: ...`); keep scopes aligned to folders.
- PRs: describe intent, list testing done, link issues, and include screenshots for UI changes; ensure lint/tests pass before requesting review.
- Keep changes scoped; update docs/CHANGELOG when behavior or endpoints change; note env or migration steps explicitly.

## Security & Configuration Tips
- Copy `.env.example` to `.env` and set strong secrets (DB, MinIO, Keycloak, OpenAI keys). Never commit real credentials.
- Expose services only as needed; for local dev rely on compose network defaults; rotate default credentials after first run.
