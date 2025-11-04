# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
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
