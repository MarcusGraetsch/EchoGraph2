# EchoGraph Setup Guide

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Node.js**: Version 18 or higher (for local frontend development)
- **Python**: Version 3.11 or higher (for local backend development)
- **Git**: For version control

### System Requirements

**Minimum:**
- 4 CPU cores
- 8 GB RAM
- 20 GB disk space

**Recommended:**
- 8 CPU cores
- 16 GB RAM
- 50 GB disk space
- GPU (optional, for faster embedding generation)

## Quick Start with Docker Compose

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/echograph.git
cd echograph
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` and update the following critical settings:

```env
# Database
POSTGRES_PASSWORD=your-secure-password

# API Security
API_SECRET_KEY=your-random-secret-key-here

# MinIO
MINIO_ACCESS_KEY=your-minio-access-key
MINIO_SECRET_KEY=your-minio-secret-key

# n8n
N8N_BASIC_AUTH_PASSWORD=your-n8n-password

# Optional: AI APIs
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

### 3. Start All Services

```bash
docker-compose up -d
```

This will start:
- PostgreSQL (port 5432)
- Redis (port 6379)
- MinIO (ports 9000, 9001)
- Qdrant (ports 6333, 6334)
- n8n (port 5678)
- API (port 8000)
- Celery Worker
- Frontend (port 3000)

### 4. Initialize the Database

```bash
docker-compose exec api python -c "from database import init_db; init_db()"
```

### 5. Create Admin User

```bash
docker-compose exec api python scripts/create_admin.py \
  --email admin@example.com \
  --password your-password \
  --username admin
```

### 6. Access the Application

- **Frontend**: http://localhost:3000
- **API Documentation**: http://localhost:8000/docs
- **n8n**: http://localhost:5678
- **MinIO Console**: http://localhost:9001

## Local Development Setup

### Backend Development

#### 1. Set Up Python Environment

```bash
cd api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

#### 2. Start Dependencies

```bash
# Start only database services
docker-compose up -d postgres redis minio qdrant
```

#### 3. Run Database Migrations

```bash
alembic upgrade head
```

#### 4. Start API Server

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 5. Start Celery Worker

```bash
celery -A tasks worker --loglevel=info
```

### Frontend Development

#### 1. Install Dependencies

```bash
cd frontend
npm install
```

#### 2. Configure Environment

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
```

#### 3. Start Development Server

```bash
npm run dev
```

Frontend will be available at http://localhost:3000

### Ingestion & Processing Development

#### 1. Set Up Environment

```bash
cd ingestion
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### 2. Test Document Extraction

```bash
python -c "
from extractors import extract_document
from pathlib import Path

result = extract_document(Path('sample.pdf'), use_ocr=True)
print(result)
"
```

## Database Setup

### PostgreSQL with pgvector

#### 1. Enable pgvector Extension

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

#### 2. Create Tables

```bash
cd api
alembic upgrade head
```

#### 3. Seed Sample Data (Optional)

```bash
python scripts/seed_data.py
```

### Qdrant Setup

Qdrant starts automatically with Docker Compose. To create collections manually:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

client = QdrantClient(host="localhost", port=6333)

client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE)
)
```

## Configuration

### API Configuration

Edit `api/config.py` or set environment variables:

```python
# Database
DATABASE_URL=postgresql://user:pass@host:5432/db

# Vector Store
QDRANT_HOST=localhost
QDRANT_PORT=6333

# Embeddings
EMBEDDING_MODEL=sentence-transformers/multi-qa-mpnet-base-dot-v1
USE_GPU=false

# Document Processing
MAX_UPLOAD_SIZE_MB=100
CHUNK_SIZE=512
CHUNK_OVERLAP=50
OCR_ENABLED=true
```

### Frontend Configuration

Edit `frontend/next.config.js`:

```javascript
module.exports = {
  env: {
    NEXT_PUBLIC_API_URL: 'http://localhost:8000',
    NEXT_PUBLIC_WS_URL: 'ws://localhost:8000',
  },
}
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# View logs
docker-compose logs postgres

# Restart database
docker-compose restart postgres
```

#### 2. Port Already in Use

```bash
# Check what's using the port
lsof -i :8000

# Change port in docker-compose.yml
ports:
  - "8001:8000"
```

#### 3. MinIO Connection Error

```bash
# Check MinIO is running
docker-compose ps minio

# Verify credentials in .env
echo $MINIO_ACCESS_KEY

# Access MinIO console to create bucket
open http://localhost:9001
```

#### 4. Frontend Build Errors

```bash
# Clear cache and reinstall
cd frontend
rm -rf node_modules .next
npm install
npm run build
```

#### 5. Celery Worker Not Processing

```bash
# Check worker status
docker-compose logs celery-worker

# Restart worker
docker-compose restart celery-worker

# Check Redis connection
docker-compose exec redis redis-cli ping
```

### Debugging

#### Enable Debug Logs

```env
LOG_LEVEL=DEBUG
```

#### Access Container Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api

# Last 100 lines
docker-compose logs --tail=100 api
```

#### Database Debugging

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U echograph -d echograph

# List tables
\dt

# Query documents
SELECT id, title, status FROM documents;
```

#### Redis Debugging

```bash
# Connect to Redis
docker-compose exec redis redis-cli

# Check queue length
LLEN celery

# Monitor commands
MONITOR
```

## Production Deployment

### Environment Preparation

1. **Set Strong Passwords**: Update all default passwords
2. **Configure SSL/TLS**: Set up HTTPS certificates
3. **Enable Monitoring**: Configure Prometheus/Grafana
4. **Set Up Backups**: Regular database backups
5. **Configure Scaling**: Set up load balancers

### Kubernetes Deployment

```bash
# Create namespace
kubectl create namespace echograph

# Apply configurations
kubectl apply -f infra/k8s/

# Check status
kubectl get pods -n echograph
```

### Security Checklist

- [ ] Change all default passwords
- [ ] Enable HTTPS/WSS
- [ ] Configure firewall rules
- [ ] Set up rate limiting
- [ ] Enable audit logging
- [ ] Configure backup strategy
- [ ] Set up monitoring and alerts
- [ ] Review CORS settings
- [ ] Enable database encryption
- [ ] Configure secrets management

## Testing

### Run Backend Tests

```bash
cd api
pytest tests/ -v
```

### Run Frontend Tests

```bash
cd frontend
npm test
```

### Run E2E Tests

```bash
cd frontend
npx playwright test
```
## Keycloak SSL Configuration

- The `echograph` Keycloak realm is currently configured with `"sslRequired": "none"` to allow HTTP connections in constrained environments. Re-import the realm with `./keycloak/init-keycloak.sh` after pulling configuration changes so the relaxed policy is applied.
- Plan to re-enable HTTPS before production by either:
  - Terminating TLS in a reverse proxy (e.g., Traefik, Nginx) in front of Keycloak and switching the realm back to `sslRequired: external`.
  - Enabling Keycloak's built-in HTTPS listener with managed certificates and updating client redirect URIs accordingly.
- Document the chosen approach and timeline so the temporary relaxation can be reverted once HTTPS infrastructure is available.

## Next Steps

1. Read the [User Guide](user-guide.md)
2. Explore the [API Documentation](api.md)
3. Review [Contributing Guidelines](contributing.md)
4. Check the [Architecture Overview](architecture.md)

## Support

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Discord**: Join our community (coming soon)
- **Documentation**: https://echograph.io/docs
