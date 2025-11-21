# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Phase 2.1: Semantic Search Implementation** (2025-11-21)
  - Implemented vector similarity search in `api/routers/search.py` using Qdrant
  - Generates embeddings for search queries using `EmbeddingGenerator`
  - Returns results ranked by semantic similarity score (0.0-1.0)
  - Supports document type filtering (norm/guideline)
  - Includes fallback to text-based search if vector search fails
  - Added `/search/health` endpoint for monitoring search subsystem health
  - Lazy-loaded singleton pattern for embedding model to optimize memory

- **Phase 3.1: Relationship Extraction Celery Task** (2025-11-21)
  - Fully implemented `extract_relationships()` task in `api/tasks.py`
  - Uses `VectorStore.find_cross_document_similarities()` for chunk-level matching
  - Aggregates chunk similarities to document-level relationships
  - Intelligent relationship type classification:
    - norm → guideline: `COMPLIANCE` (guideline implements norm)
    - guideline → norm: `REFERENCE` (guideline references norm)
    - norm → norm: `SIMILAR` or `SUPERSEDES` (based on similarity/version)
    - guideline → guideline: `SIMILAR`
  - Stores relationships with confidence scores, summaries, and matched chunk details
  - Auto-triggers relationship extraction after document processing completes
  - Prevents duplicate relationships with existence check

- **Phase 2.2: Search Results UI Component** (2025-11-21)
  - New `frontend/src/components/SearchResults.tsx` modal component
  - Displays search results with document title, type, chunk text, and similarity score
  - Filter results by document type (All/Norms/Guidelines)
  - Expandable chunk text preview for long content
  - Loading, error, and empty states with appropriate UI feedback
  - Click handler to navigate to document details
  - Color-coded similarity scores (green >80%, yellow >60%, orange <60%)

- **Phase 4.2: Document Compare UI Component** (2025-11-21)
  - New `frontend/src/components/DocumentCompare.tsx` modal component
  - Select up to 5 documents for relationship comparison
  - Adjustable confidence threshold slider (0-100%)
  - Visual connection diagram showing source → target relationships
  - Displays relationship type, confidence, and validation status
  - Expandable details showing matched chunks and sections
  - Relationship type badges with color coding
  - Integrated with `POST /api/relationships/compare` endpoint

- **Frontend API Client Enhancements** (2025-11-21)
  - Added `relationshipsApi` in `frontend/src/lib/api.ts`:
    - `getByDocument()` - Get all relationships for a document
    - `compare()` - Compare multiple documents
    - `getPending()` - Get pending relationships for review
    - `validate()` - Validate/reject a relationship
    - `delete()` - Delete a relationship
  - Enhanced `documentApi.search()` with options for document_type, limit, threshold
  - Added TypeScript types: `SearchResult`, `SearchResponse` in `frontend/src/types/index.ts`

- **Dashboard Integration** (2025-11-21)
  - Search now opens proper SearchResults modal instead of alert
  - Added document type filter dropdown to search interface
  - Relationships stats card is now clickable - opens DocumentCompare modal
  - Loading state shown during search with spinner
  - Visual hint "Click to compare documents" on Relationships card

### Fixed
- **CRITICAL FIX #9 - DEPLOYMENT SUCCESS**: Missing StorageClient import - API now starts successfully! 🎉
  - **Root cause**: `api/routers/documents.py` line 30 instantiated `StorageClient()` without importing it
  - **Problem**: Persistent `NameError: name 'StorageClient' is not defined` prevented API from starting
  - **Impact**: API container crashed on startup, blocking entire deployment (API, Celery worker, Frontend)
  - **Solution**: Added `from ingestion.storage import StorageClient` import at line 14
  - **Verification from deployment logs**:
    - ✅ API startup: `INFO | ingestion.storage:_ensure_bucket:31 - Created bucket: echograph-documents`
    - ✅ Database: `INFO | api.database:init_db - Database initialized successfully`
    - ✅ Server: `INFO | Uvicorn running on http://0.0.0.0:8000`
    - ✅ Health checks: `INFO | "GET /health HTTP/1.1" 200 OK` (multiple successful checks)
    - ✅ Celery worker: `INFO | celery@1d8bef81f32c ready.`
    - ✅ Frontend: `▲ Next.js 14.1.0 - Ready in 118ms`
  - **Complete fix chain analysis**:
    - Fixes #1-8 addressed infrastructure issues (Docker caching, volume mounts, git pull, etc.)
    - Fix #9 addresses the actual code bug that infrastructure fixes couldn't solve
    - All infrastructure was correct, but code had missing import
  - **Current deployment status**: ✅ **FULLY OPERATIONAL**
  - Files changed: `api/routers/documents.py` (+1 line: import statement)
  - Commit: b99d8ae
  - **Note**: Keycloak shows slow startup (timeout after 60s), but NOT critical - API/Frontend/Celery work independently

- **CRITICAL FIX #8**: Docker rebuild enforcement - forces fresh image build to prevent cached old code
  - Root cause: `docker-compose up -d` doesn't rebuild if image already exists, just starts containers
  - Problem: After git pull, new code is on VM but Docker still uses OLD cached image from previous build
  - Git repo line 30 of `api/routers/documents.py`: `file: UploadFile = File(...)` (correct, no StorageClient)
  - But container still had line 30: `storage_client = StorageClient()` (old cached code)
  - Result: Even with docker-compose.prod.yml (Fix #7), StorageClient error persisted
  - Solution: Added `docker-compose build --no-cache api celery-worker frontend` BEFORE `docker-compose up -d`
  - This forces Docker to:
    1. Ignore existing cached image layers
    2. Rebuild from scratch using code from git repo (after git pull)
    3. Create fresh image with latest code
  - Added intelligent error detection:
    - Detects NameError (specifically StorageClient pattern)
    - Shows clear explanation of root cause (old cached code)
    - Automatically triggers rebuild with --no-cache
  - **Complete Fix Chain** (all 4 pieces required):
    1. Fix #5 (git pull): Gets latest code to VM filesystem
    2. Fix #6 (script self-update): Ensures deployment script itself has git pull
    3. Fix #7 (docker-compose.prod.yml): Removes volume mounts that override container code
    4. Fix #8 (docker build --no-cache): Ensures container built with latest code, not cached ✅
  - Without ALL 4 fixes, StorageClient error would persist
  - Files changed: `scripts/deploy-contabo.sh` (+32 lines)
  - Commit: c942eb9

- **CRITICAL**: Production deployment configuration - separate compose file without code volume mounts
  - Root cause: Docker volume mounts (`./api:/app/api`, `./ingestion:/app/ingestion`, `./processing:/app/processing`) override container code with VM filesystem
  - Problem: All previous 6 critical fixes (git pull, script self-update, etc.) couldn't help because volumes ALWAYS use VM files
  - VM had old `documents.py` with `storage_client = StorageClient()` at line 30, which doesn't exist in git repo
  - Resulted in persistent `NameError: name 'StorageClient' is not defined` that survived all previous fixes
  - Created new `docker-compose.prod.yml` specifically for production deployments:
    - Removed code volume mounts from `api` and `celery-worker` services
    - Only mounts `./data:/app/data` for data persistence
    - Code is now read from Docker image (built via Dockerfile), not VM filesystem
  - Updated `scripts/deploy-contabo.sh` to use production compose file:
    - Changed `COMPOSE_CMD` to include `-f docker-compose.prod.yml`
    - Added informational message about production mode
    - Updated help text to explain dev vs prod configurations
  - Development vs Production:
    - **Dev** (`docker-compose.yml`): Mounts all code directories for hot-reload during development
    - **Prod** (`docker-compose.prod.yml`): No code mounts, uses immutable code from Docker image
  - This architectural fix solves the fundamental mismatch between development and production environments
  - Note: `docker-compose.yml` remains unchanged for local development with hot-reload
  - Files changed: new `docker-compose.prod.yml`, modified `scripts/deploy-contabo.sh`

- **CRITICAL**: Fixed deployment script self-update and log file display
  - Root cause: VM runs old script version without git pull functionality (chicken-and-egg problem)
  - Log file path display was broken after `exec tee` redirection
  - Added self-update mechanism at script start (before any operations):
    - Compares local vs remote git refs via `git fetch`
    - Automatically pulls updates if available
    - Re-executes itself with `--no-update` flag to prevent loops
    - Ensures script always runs latest version
  - Fixed log file path display:
    - Calculate paths BEFORE `exec tee` redirect
    - Store both `LOGFILE` (full path) and `LOGFILE_NAME` (basename)
    - Display both at end: filename for quick reference, full path for absolute location
  - This solves persistent StorageClient errors by ensuring VM always has latest code
  - Commit: 36cce23

- **CRITICAL**: Fixed deployment script not pulling latest code updates
  - Root cause: Deployment script clones repo on first run but never pulls updates on subsequent runs
  - Docker volume mounts (`./api:/app/api`) override container code with VM filesystem
  - Outdated code on VM caused errors like: `NameError: name 'StorageClient' is not defined`
  - Added automatic `git pull` in two scenarios:
    1. When already inside EchoGraph2 repository
    2. When EchoGraph2 exists as subdirectory
  - Pulls from current branch automatically with clear status messages
  - This ensures every deployment uses latest GitHub code, preventing old code errors
  - Commit: 95e6250

- **CRITICAL**: Fixed ImportError preventing API and Celery containers from starting
  - Root cause: After changing CMD to `uvicorn api.main:app`, all imports broke due to absolute import paths
  - All API files used absolute imports like `from config import settings` which failed with new package structure
  - Changed all imports in api/ directory to relative imports (e.g., `from .config import settings`)
  - Affected files: main.py, database.py, models.py, auth.py, tasks.py, and all routers (auth, documents, relationships, search)
  - This fix resolves the persistent "api failed to start properly" error after previous fixes
  - Issue: Container built successfully, health check worked, but application failed to import internal modules
  - Commit: 4daa440

- **CRITICAL**: Fixed Docker health check failure for API container
  - Root cause: Health check used `requests` module which wasn't installed in requirements.txt
  - Changed health check from `python -c "import requests; requests.get(...)"` to `curl -f http://localhost:8000/health || exit 1`
  - Solution uses `curl` which is already installed in the container (more lightweight and reliable)
  - This fix resolves the "container echograph-api is unhealthy" error preventing service deployment
  - Issue: Container built successfully but marked as unhealthy, blocking dependent services
  - Commit: 3d0c9df

- **CRITICAL**: Fixed Docker build failure with invalid COPY command syntax
  - Root cause: Used shell redirection syntax `2>/dev/null || true` in Dockerfile COPY commands
  - Error: `failed to calculate checksum of ref...: "/2>/dev/null": not found`
  - Docker's COPY is a native command without shell context - shell syntax only works in RUN commands
  - Removed all shell redirection from COPY commands in `api/Dockerfile`
  - Cleaned up RUN pip install commands to use simple chaining with `&&`
  - This fix allows Docker build to complete successfully
  - Issue: Docker build process failed before creating container image

- **CRITICAL**: Fixed ModuleNotFoundError for `ingestion` and `processing` modules in Docker containers
  - Updated `docker-compose.yml` to change build context from `./api` to `.` (root directory)
  - Modified `api/Dockerfile` to copy `ingestion/` and `processing/` modules into container
  - Added `PYTHONPATH=/app` environment variable to both `api` and `celery-worker` services
  - Updated volume mounts to include `/app/ingestion` and `/app/processing` for development hot-reload
  - Changed Celery worker command from `celery -A tasks` to `celery -A api.tasks`
  - Changed uvicorn command from `main:app` to `api.main:app`
  - This fix resolves deployment failures where API and Celery worker services fail to start
  - Issue: API service was continuously crashing with import errors preventing deployment success

### Added
- **Deployment Script**: Added comprehensive logging to deploy-contabo.sh
  - All deployment output now logged to timestamped file (e.g., deployment_20251104_143022.log)
  - Log file location displayed at end of deployment for easy troubleshooting
  - Helps diagnose deployment issues and track deployment history

- Initial project setup with mono-repo structure
- FastAPI backend with RESTful API
- Next.js frontend with modern UI
- Document upload and management
- Document type classification (Norms vs Guidelines)
- PostgreSQL database with pgvector support
- Qdrant vector database integration
- MinIO S3-compatible object storage
- Document text extraction (PDF, DOCX)
- OCR support for scanned documents
- Text chunking with structure awareness
- Embedding generation using sentence-transformers
- Semantic search functionality
- Document comparison interface
- Relationship discovery engine
- Human validation workflow
- JWT authentication and authorization
- Role-based access control (Admin, Reviewer, User)
- Real-time progress tracking via WebSocket
- Celery task queue for async processing
- n8n workflow automation
- Docker and Docker Compose configuration
- Comprehensive documentation
- CI/CD pipeline with GitHub Actions
- Code of conduct and contributing guidelines

### Coming Soon
- Advanced analytics dashboard
- Multi-language support
- Collaborative features (comments, annotations)
- Document versioning
- Export functionality (PDF, DOCX, Excel)
- Graph visualization
- External integrations (SharePoint, Google Drive)
- Improved ML models
- Mobile app

## [0.1.0] - 2025-01-15

### Added
- Initial release
- Core document management features
- Basic AI-powered relationship discovery
- Simple validation workflow
- Docker deployment support

---

## Version History

- **0.1.0** - Initial alpha release (2025-01-15)

## Migration Guides

### Upgrading to v0.1.0

This is the initial release. No migration needed.

## Breaking Changes

None yet.

## Deprecations

None yet.

## Security

For security vulnerabilities, please email security@echograph.io or create a private security advisory on GitHub.
