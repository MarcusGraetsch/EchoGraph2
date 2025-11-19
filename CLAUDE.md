# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EchoGraph is a microservices-based document compliance and comparison platform that uses AI-powered semantic analysis to discover relationships between regulatory documents and company guidelines. The system helps compliance teams identify gaps, ensure consistency, and prepare for audits.

**Core Value Proposition**: Automated relationship detection between documents (norms/regulations vs. company guidelines) with human-in-the-loop validation workflow.

## Development Commands

### Backend (FastAPI)

```bash
# Install dependencies
cd api
pip install -r requirements.txt
pip install -e ../ingestion -e ../processing

# Run development server
uvicorn api.main:app --reload --port 8000

# Run Celery worker
celery -A api.tasks worker --loglevel=info

# Type checking
mypy api/

# Code formatting
black api/
ruff api/
```

### Frontend (Next.js)

```bash
cd frontend

# Install dependencies
npm install

# Development server
npm run dev

# Production build
npm run build
npm start

# Linting
npm run lint
```

### Docker Services

```bash
# Start all services (development with hot-reload)
docker-compose up -d

# Production deployment (no code mounts)
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose logs -f api celery-worker

# Rebuild after code changes
docker-compose build --no-cache
docker-compose up -d
```

### Testing

```bash
# Backend tests
cd api
pytest

# Frontend tests
cd frontend
npm test
```

## Architecture

### Service Communication Flow

The system uses a **dual authentication approach** supporting both Keycloak (primary) and legacy JWT (backward compatibility):

1. **Frontend** → Keycloak login → JWT token
2. **Frontend** → API requests with Bearer token
3. **API** verifies token via Keycloak public key
4. **API** extracts user roles and creates `KeycloakUser` object
5. **API** routes use `@Depends(get_current_active_user)` for authentication

### Document Processing Pipeline

```
User Upload → API creates Document record (status: UPLOADING)
           → File uploaded to MinIO
           → Celery task queued (extract_document)
           → Extract text (ingestion.extractors)
           → Chunk text (processing.chunking)
           → Generate embeddings (processing.embeddings)
           → Store in PostgreSQL (document_chunks) + Qdrant (vectors)
           → Update Document status to READY
           → WebSocket broadcasts progress to frontend
```

### Critical Architectural Patterns

1. **Status-Based Document Lifecycle**: Documents progress through explicit states (`UPLOADING` → `PROCESSING` → `EXTRACTING` → `ANALYZING` → `EMBEDDING` → `READY` or `ERROR`). This prevents race conditions and enables meaningful progress tracking.

2. **Lazy Relationship Detection**: Relationships are pre-computed and stored in the database, not calculated on-the-fly. This enables O(1) lookups, manual validation by reviewers, and historical preservation.

3. **Structure-Aware Chunking**: The `StructuredChunker` preserves document hierarchy (section titles, heading levels) in `document_chunks.section_title` and `section_level`. This enables section-level relationship analysis rather than just whole-document comparison.

4. **Presigned URLs for Downloads**: MinIO integration uses presigned URLs (1-hour expiry) so files are downloaded directly from object storage, not proxied through the API.

5. **WebSocket Progress Updates**: Long-running Celery tasks push progress updates via WebSocket to provide real-time feedback without polling.

## Data Models

### Core Entities

- **Document**: Main entity with metadata, file info, processing status, and timestamps
  - Relationships: `chunks` (one-to-many), `relationships_as_source`, `relationships_as_target`
  - Status enum: uploading, processing, extracting, analyzing, embedding, ready, error

- **DocumentChunk**: Text chunks with embeddings (768-dimensional vectors)
  - Includes structure metadata: `section_title`, `section_level`, `page_number`
  - Indexed for vector similarity search using pgvector

- **DocumentRelationship**: Discovered relationships between documents
  - Type enum: compliance, conflict, reference, similar, supersedes
  - Validation workflow: auto_detected → pending_review → approved/rejected
  - Stores matched chunks, LLM analysis, and confidence scores in JSON `details` field

- **User**: Authentication with role-based access control
  - Roles: `is_admin`, `is_reviewer`, `is_active`
  - Keycloak integration via `keycloak_id`

### Database Schema Location

All SQLAlchemy models are defined in `api/models.py`. Pydantic schemas for API validation are in `api/schemas.py`.

## Key Integration Points

### MinIO (Object Storage)

- Client wrapper: `ingestion/storage.py` (`StorageClient` class)
- Default bucket: `echograph-documents`
- Files stored at: `documents/{document_id}/{filename}`
- **Important**: Always import `StorageClient` when using: `from ingestion.storage import StorageClient`

### Qdrant (Vector Database)

- Collection: `document_chunks`
- Vector dimensions: 768 (sentence-transformers default)
- Index type: HNSW for efficient similarity search
- Connection: `qdrant_client.QdrantClient(host=QDRANT_HOST, port=6333)`

### Celery + Redis

- Broker: Redis at `redis://redis:6379/0`
- Task definitions: `api/tasks.py`
- **Critical TODOs**:
  - `extract_document` (line 56): Document processing pipeline implementation
  - `extract_relations` (line 91): Relationship discovery implementation

### Keycloak

- OpenID Connect provider at port 8080
- Realm configuration in `keycloak/` directory
- Token verification: `api/keycloak_auth.py`
- Frontend integration: `frontend/src/lib/keycloak.tsx`

## Critical File Locations

### Backend

- **API Routes**: `api/routers/` (auth.py, documents.py, relationships.py, search.py, websocket.py)
- **Main App**: `api/main.py` - FastAPI setup, middleware, CORS
- **Configuration**: `api/config.py` - Pydantic settings from environment variables
- **Database**: `api/database.py` - SQLAlchemy session management
- **Tasks**: `api/tasks.py` - Celery task definitions (needs implementation)

### Frontend

- **Pages**: `frontend/src/app/` - Next.js App Router
- **Components**: `frontend/src/components/` (ui/ for Shadcn, feature components)
- **API Client**: `frontend/src/services/api.ts` - Axios instance with auth interceptors
- **Service Layer**: `frontend/src/services/` (auth, documents, relationships)
- **Keycloak Setup**: `frontend/src/lib/keycloak.tsx`

### Processing

- **Text Extraction**: `ingestion/extractors.py` (PDFExtractor, DOCXExtractor, OCRExtractor)
- **Chunking**: `processing/chunking.py` (DocumentChunker, StructuredChunker)
- **Embeddings**: `processing/embeddings.py` (EmbeddingGenerator, OpenAIEmbedding)

## Common Development Tasks

### Adding a New API Endpoint

1. Create route handler in appropriate router file (`api/routers/`)
2. Define Pydantic request/response schemas in `api/schemas.py`
3. Add authentication dependency: `current_user: User = Depends(get_current_user)`
4. For admin-only routes: use `Depends(get_current_admin)`
5. For reviewer routes: use `Depends(get_current_reviewer)`
6. Update OpenAPI documentation with clear docstrings

### Adding a New Frontend Component

1. Create component in `frontend/src/components/`
2. Define TypeScript interfaces for props in component or `frontend/src/types/`
3. Use Shadcn/ui base components from `components/ui/`
4. For data fetching: create React Query hooks in appropriate service file
5. For API calls: add function to relevant service in `frontend/src/services/`

### Implementing a Celery Task

1. Add task definition to `api/tasks.py`
2. Use `@celery_app.task(bind=True, autoretry_for=(Exception,), retry_kwargs={'max_retries': 3})`
3. Update document status at each pipeline step
4. Send WebSocket notifications for progress updates
5. Handle errors and set status to ERROR on failure
6. Import required modules: `from ingestion.extractors import DocumentExtractor`

### Working with Vector Search

1. Generate embedding: `from processing.embeddings import EmbeddingGenerator`
2. Query Qdrant: `qdrant_client.search(collection_name="document_chunks", query_vector=embedding, limit=20)`
3. Filter results by metadata (document_type, category)
4. Map results back to DocumentChunk records in PostgreSQL
5. Use cosine similarity scores for ranking

## Known Issues and Workarounds

### Import Errors in Docker

**Issue**: `ModuleNotFoundError` for ingestion/processing modules
**Solution**: All API imports use relative imports (e.g., `from .config import settings`). Docker build context is set to repository root, not `./api`.

### StorageClient Not Found

**Issue**: `NameError: name 'StorageClient' is not defined` in documents.py
**Solution**: Always import at top of file: `from ingestion.storage import StorageClient`

### Docker Not Rebuilding After Code Changes

**Issue**: Container uses old code despite git pull
**Solution**: Use `docker-compose build --no-cache` before `up -d` to force rebuild

### Production vs Development Configuration

**Development**: Use `docker-compose.yml` (has code volume mounts for hot-reload)
**Production**: Use `docker-compose.prod.yml` (no code mounts, only data volumes)

## Security Considerations

1. **Never commit secrets**: All credentials in `.env.example` are placeholders
2. **Change default passwords** for production:
   - PostgreSQL: postgres/postgres
   - MinIO: minioadmin/minioadmin
   - Keycloak: admin/admin_changeme
   - n8n: admin/admin

3. **Use HTTPS in production**: Add nginx reverse proxy with Let's Encrypt

4. **Validate file uploads**:
   - Check file type (only PDF/DOCX allowed)
   - Validate file size (< MAX_UPLOAD_SIZE_MB)
   - Scan for malicious content before processing

5. **Rate limiting**: Implement slowapi or fastapi-limiter middleware

## Code Style

### Python

- Use type hints everywhere: `def process(doc_id: int, db: Session) -> Document:`
- Docstrings in Google style with Args, Returns, Raises sections
- Relative imports for API modules: `from .config import settings`
- Error handling with FastAPI HTTPException and appropriate status codes
- Structured logging: `logger.info("message", document_id=id, user_id=user.id)`

### TypeScript

- Strict mode enabled in `tsconfig.json`
- Define interfaces for all data structures
- Use React Query for data fetching with proper cache invalidation
- Error handling with try/catch and user-friendly toast notifications
- API calls through service layer, not directly in components

## Testing Strategy

- **Backend**: pytest with FastAPI TestClient in `api/tests/`
- **Frontend**: Jest + React Testing Library in `frontend/src/**/*.test.tsx`
- **E2E**: Playwright (to be implemented)
- **Integration**: Test full workflows (upload → process → search)

## Deployment

### Local Development

```bash
./deploy.sh
```

Auto-detects VM IP and configures all services.

### Production

Use `docker-compose.prod.yml` with:
- Strong passwords in `.env`
- HTTPS via nginx reverse proxy
- Monitoring (Prometheus + Grafana)
- Log aggregation (Loki or ELK)
- Backup strategy for PostgreSQL

### Environment Variables

Critical settings in `.env`:
- `API_SECRET_KEY`: JWT signing key
- `DATABASE_URL`: PostgreSQL connection
- `QDRANT_HOST`, `MINIO_ENDPOINT`: Service endpoints
- `KEYCLOAK_SERVER_URL`, `KEYCLOAK_CLIENT_SECRET`: Auth config
- `EMBEDDING_MODEL`: sentence-transformers model name

## Troubleshooting

### API won't start

1. Check logs: `docker-compose logs -f api`
2. Verify imports are relative (not absolute)
3. Ensure PostgreSQL is running: `docker-compose ps postgres`
4. Check DATABASE_URL in `.env`

### Celery tasks not running

1. Check worker logs: `docker-compose logs -f celery-worker`
2. Verify Redis is accessible: `docker-compose exec redis redis-cli ping`
3. Check task queue: `redis-cli LLEN celery`

### Frontend can't connect to API

1. Verify `NEXT_PUBLIC_API_URL` in frontend `.env.local`
2. Check CORS settings in `api/main.py`
3. Ensure Keycloak is configured correctly

### Vector search not working

1. Check Qdrant collection exists: `curl http://localhost:6333/collections/document_chunks`
2. Verify embeddings are being stored
3. Check vector dimensions match (768)

## Priority TODOs

**High Priority** (blocking core functionality):
1. Implement Celery tasks in `api/tasks.py` (extract_document, extract_relations)
2. Complete MinIO integration in `api/routers/documents.py` (upload, delete)
3. Implement semantic search in `api/routers/search.py`
4. Build frontend UI components (DocumentUpload, DocumentLibrary, DocumentCompare)

**Medium Priority** (enhancements):
5. Add comprehensive test coverage
6. Set up monitoring with Prometheus + Grafana
7. Implement database migrations with Alembic
8. Create n8n workflows for automation

**Low Priority** (future features):
9. Graph visualization of document relationships
10. Export functionality (PDF/Excel reports)
11. Multi-language support (i18n)
12. External integrations (SharePoint, Google Drive)
