# Contributing to EchoGraph

Thank you for your interest in contributing to EchoGraph! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**When submitting a bug report, include:**

- Clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Screenshots (if applicable)
- Environment details (OS, browser, versions)
- Relevant logs or error messages

**Bug Report Template:**

```markdown
**Description:**
Brief description of the bug

**Steps to Reproduce:**
1. Go to '...'
2. Click on '...'
3. See error

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Environment:**
- OS: [e.g., Ubuntu 22.04]
- Browser: [e.g., Chrome 120]
- EchoGraph Version: [e.g., 0.1.0]

**Additional Context:**
Any other relevant information
```

### Suggesting Features

We welcome feature suggestions! Before submitting:

1. Check if the feature has already been requested
2. Ensure it aligns with project goals
3. Consider implementation complexity

**Feature Request Template:**

```markdown
**Feature Description:**
Clear description of the proposed feature

**Use Case:**
Why is this feature needed?

**Proposed Solution:**
How should this work?

**Alternatives Considered:**
Other approaches you've thought about

**Additional Context:**
Mockups, examples, or references
```

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and linting
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

## Development Workflow

### Setting Up Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/echograph.git
cd echograph

# Add upstream remote
git remote add upstream https://github.com/original/echograph.git

# Create branch
git checkout -b feature/my-feature

# Start development environment
docker-compose up -d
```

### Code Style

#### Python (Backend)

- **Style Guide**: PEP 8
- **Formatter**: Black
- **Linter**: Ruff
- **Type Hints**: Required for all functions

```bash
# Format code
black .

# Lint code
ruff check .

# Type check
mypy .
```

**Example:**

```python
from typing import List, Optional
from pydantic import BaseModel


class Document(BaseModel):
    """Document model."""

    id: int
    title: str
    tags: Optional[List[str]] = None

    def process(self) -> bool:
        """Process the document.

        Returns:
            True if successful, False otherwise
        """
        # Implementation
        return True
```

#### TypeScript/React (Frontend)

- **Style Guide**: Airbnb style guide
- **Formatter**: Prettier
- **Linter**: ESLint

```bash
# Format code
npm run format

# Lint code
npm run lint

# Type check
npm run type-check
```

**Example:**

```typescript
interface DocumentProps {
  id: number
  title: string
  onSelect?: (id: number) => void
}

export function DocumentCard({ id, title, onSelect }: DocumentProps) {
  const handleClick = () => {
    onSelect?.(id)
  }

  return (
    <div onClick={handleClick}>
      <h3>{title}</h3>
    </div>
  )
}
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```bash
feat(api): add document comparison endpoint

fix(frontend): resolve upload progress bar issue

docs(readme): update installation instructions

test(api): add tests for authentication flow
```

### Testing

#### Backend Tests

```bash
cd api

# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test
pytest tests/test_documents.py::test_create_document
```

**Writing Tests:**

```python
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_create_document():
    response = client.post(
        "/api/documents/upload",
        files={"file": ("test.pdf", b"content")},
        data={"title": "Test", "document_type": "norm"}
    )
    assert response.status_code == 201
    assert response.json()["title"] == "Test"
```

#### Frontend Tests

```bash
cd frontend

# Run unit tests
npm test

# Run with coverage
npm test -- --coverage

# Run E2E tests
npm run test:e2e
```

**Writing Tests:**

```typescript
import { render, screen } from '@testing-library/react'
import { DocumentCard } from './DocumentCard'

describe('DocumentCard', () => {
  it('renders document title', () => {
    render(<DocumentCard id={1} title="Test Document" />)
    expect(screen.getByText('Test Document')).toBeInTheDocument()
  })

  it('calls onSelect when clicked', () => {
    const onSelect = jest.fn()
    render(<DocumentCard id={1} title="Test" onSelect={onSelect} />)

    screen.getByText('Test').click()
    expect(onSelect).toHaveBeenCalledWith(1)
  })
})
```

### Documentation

- Update relevant documentation for any changes
- Add docstrings to all functions and classes
- Include examples in API documentation
- Update README if adding new features

**Python Docstring Format:**

```python
def process_document(
    document_id: int,
    use_ocr: bool = False
) -> ProcessResult:
    """Process a document and extract text.

    Args:
        document_id: ID of the document to process
        use_ocr: Whether to use OCR for scanned documents

    Returns:
        ProcessResult containing extracted text and metadata

    Raises:
        DocumentNotFoundError: If document doesn't exist
        ProcessingError: If processing fails

    Example:
        >>> result = process_document(123, use_ocr=True)
        >>> print(result.text)
    """
    # Implementation
```

## Pull Request Process

### 1. Ensure Your PR:

- [ ] Follows code style guidelines
- [ ] Includes tests for new functionality
- [ ] Updates documentation as needed
- [ ] Passes all CI checks
- [ ] Has a clear description
- [ ] References related issues

### 2. PR Description Template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issues
Fixes #123

## Testing
Describe testing done

## Screenshots (if applicable)
Add screenshots

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] No new warnings
```

### 3. Review Process:

1. Automated checks run (linting, tests, build)
2. Maintainers review code
3. Address feedback and update PR
4. Once approved, PR is merged

### 4. After Merge:

- Delete your feature branch
- Pull latest changes from main
- Celebrate! 🎉

## Project Structure

Understanding the project structure helps you navigate the codebase:

```
echograph/
├── api/                    # FastAPI backend
│   ├── routers/           # API endpoints
│   ├── models.py          # Database models
│   ├── schemas.py         # Pydantic schemas
│   └── tests/             # Backend tests
├── frontend/              # Next.js frontend
│   ├── src/
│   │   ├── app/          # Next.js pages
│   │   ├── components/   # React components
│   │   ├── services/     # API clients
│   │   └── types/        # TypeScript types
│   └── __tests__/        # Frontend tests
├── ingestion/            # Document processing
├── processing/           # Embeddings & chunking
├── infra/               # Infrastructure configs
│   ├── docker/          # Dockerfiles
│   └── k8s/             # Kubernetes manifests
└── docs/                # Documentation
```

## Specific Contribution Areas

### Adding New Document Types

1. Update `DocumentType` enum in `api/models.py`
2. Add extraction logic in `ingestion/extractors.py`
3. Update frontend types in `frontend/src/types/index.ts`
4. Add UI components for the new type
5. Update documentation

### Adding New Relationship Types

1. Update `RelationshipType` enum in `api/models.py`
2. Add detection logic in `processing/matching.py`
3. Update frontend types and UI
4. Add tests for new relationship type

### Improving AI/ML Models

1. Research and document alternative models
2. Implement model switcher in `processing/embeddings.py`
3. Benchmark performance improvements
4. Update configuration options
5. Document trade-offs

### Adding Integrations

1. Create integration module in `integrations/`
2. Add configuration options
3. Implement API client
4. Add n8n workflow templates
5. Document setup process

## Getting Help

- **GitHub Discussions**: Ask questions
- **Discord**: Real-time chat (coming soon)
- **Documentation**: Check docs first
- **Issues**: Search existing issues

## Recognition

Contributors are recognized in:
- README.md Contributors section
- Release notes
- Project website (coming soon)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to EchoGraph! Your efforts help make document compliance easier for everyone.
