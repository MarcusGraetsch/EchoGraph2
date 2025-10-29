# GitHub Workflows

## CI/CD Pipeline

The complete GitHub Actions CI/CD workflow configuration is available in this directory.

### Setup Instructions

Due to GitHub App permissions, the workflow file needs to be added manually:

1. Copy the `workflows/ci.yml` file to `.github/workflows/ci.yml` in your repository
2. Commit and push the file
3. The CI/CD pipeline will automatically run on push and pull requests

### Workflow Features

The CI pipeline includes:
- **Backend Linting**: Black, Ruff, MyPy
- **Frontend Linting**: ESLint, TypeScript checking
- **Automated Testing**: pytest (backend), Jest (frontend)
- **Docker Build**: Validates Docker images build correctly
- **Security Scanning**: Trivy vulnerability scanner
- **Code Coverage**: Uploads to Codecov

### Manual Addition

If you have repository permissions, you can add the workflow file directly:

```bash
# The workflow file should be at:
# .github/workflows/ci.yml

# Ensure it's in your repository and commit it
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
git push
```

### Alternative: Use the Workflow File

The complete workflow configuration is available at:
`workflows/ci.yml` in this directory.

Copy it to `.github/workflows/ci.yml` to enable automated CI/CD.
