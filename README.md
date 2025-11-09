# EchoGraph

**Document Compliance & Comparison Platform**

EchoGraph is an open-source platform for managing, analyzing, and comparing regulatory documents and company guidelines. It uses AI-powered semantic analysis to discover relationships, identify compliance gaps, and ensure consistency across your documentation.

## Features

- **Dual Document Management**: Handle both official norms/regulations and company guidelines
- **AI-Powered Analysis**: Semantic embeddings and LLM-based relationship discovery
- **Modern UI**: Beautiful, responsive interface with real-time progress tracking
- **Human-in-the-Loop**: Validation workflow for compliance officers
- **Document Comparison**: Multi-document analysis with conflict detection
- **Open Source**: MIT licensed, community-driven development

## Architecture

```
EchoGraph/
├── ingestion/      # Document processing and extraction
├── processing/     # Embedding generation and chunking
├── api/            # FastAPI backend service
├── frontend/       # Next.js React application
├── infra/          # Docker, K8s, and deployment configs
├── docs/           # Comprehensive documentation
└── data/           # Storage for raw and processed documents
```

## Tech Stack

- **Frontend**: Next.js 14, React 18, Tailwind CSS, Shadcn/ui
- **Backend**: FastAPI, Python 3.11+, SQLAlchemy
- **Database**: PostgreSQL 15+ with pgvector
- **Vector Store**: Qdrant / pgvector
- **Storage**: MinIO (S3-compatible)
- **Automation**: n8n workflows
- **AI/ML**: sentence-transformers, OpenAI API (optional)

## Quick Start

### Deploy to Server (Any Linux VM)

**One-command automated deployment:**

```bash
# SSH into your server, then run:
git clone https://github.com/MarcusGraetsch/EchoGraph2.git
cd EchoGraph2
./deploy.sh
```

**What this does automatically:**
- ✅ Detects your VM's IP address
- ✅ Generates .env configuration
- ✅ Starts all Docker services
- ✅ Initializes Keycloak authentication
- ✅ Ready to use in ~3-5 minutes

📖 **See [DEPLOYMENT.md](DEPLOYMENT.md)** for detailed deployment options.

📚 **Troubleshooting**: [APPLY_FIX_NOW.md](APPLY_FIX_NOW.md)

### Local Development

1. **Clone and deploy**
   ```bash
   git clone https://github.com/MarcusGraetsch/EchoGraph2.git
   cd EchoGraph2
   ./deploy.sh
   ```

2. **Access the application**
   - Frontend: http://localhost:3000 (or http://YOUR_IP:3000)
   - API: http://localhost:8000
   - API Docs: http://localhost:8000/docs
   - Keycloak: http://localhost:8080
   - Keycloak Admin: http://localhost:8080/admin
   - n8n: http://localhost:5678
   - MinIO Console: http://localhost:9001

3. **Default credentials**
   - Keycloak Admin: `admin` / `admin_changeme`
   - EchoGraph User: `admin` / `admin` (change on first login)

**Note:** The deploy script automatically detects your IP and configures all services.

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for local frontend development)
- Python 3.11+ (for local backend development)
- 4GB+ RAM, 20GB+ disk space

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Setup Guide](docs/setup.md)
- [User Guide](docs/user-guide.md)
- [API Reference](docs/api.md)
- [Contributing](docs/contributing.md)
- [Deployment](docs/deployment.md)

## Use Cases

- **Regulatory Compliance**: Compare company policies against industry regulations
- **Standards Management**: Track ISO, GDPR, SOC2, and other compliance frameworks
- **Policy Consistency**: Ensure internal guidelines align with each other
- **Gap Analysis**: Identify missing requirements and conflicts
- **Audit Preparation**: Generate compliance reports and documentation

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/contributing.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Community

- [GitHub Discussions](https://github.com/yourusername/echograph/discussions)
- [Issue Tracker](https://github.com/yourusername/echograph/issues)
- [Discord Community](https://discord.gg/echograph)

## Acknowledgments

Built with open-source tools and inspired by the need for better compliance management in modern organizations.

---

**Status**: 🚧 Active Development

Made with ❤️ by the EchoGraph community
