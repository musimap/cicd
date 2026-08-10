# Musimap CI/CD Workflows

This repository contains **reusable GitHub Actions workflows and composite steps** used across all Musimap projects — including Django services, FastAPI services, and Python packages.

These workflows are designed to enforce **consistency, maintainability, and automation** across repositories while avoiding duplication.

---

## 🧱 Repository Structure

```
.github/
└── workflows/
    ├── python-service-django.yaml
    ├── python-package.yaml
    ├── ...
github-actions/
└── _partials/
    ├── steps-bump-poetry-version.yaml
    ├── steps-build-docker.yaml
    ├── steps-commit-version.yaml
    ├── steps-configure-aws.yaml
    ├── steps-install-poetry.yaml
    ├── steps-publish-codeartifact.yaml
    ├── steps-pytest.yaml
    ├── steps-set-overlay-path.yaml
    ├── steps-slack-notify.yaml
    ├── steps-update-kustomize.yaml
    ├── steps-validate-python.yaml
    ├── steps-validate-repo.yaml
    └── ...
```

---

## ⚙️ Available Workflows

### 🐍 `python-service-django.yaml`
Reusable CI/CD pipeline for Django/DRF services.

**Includes:**
- Poetry setup
- AWS CodeArtifact integration
- PostgreSQL service container (for ORM-backed apps; ignored by dummy-DB apps)
- Docker build & ECR push
- Kustomize image update
- Slack notifications

**Triggered on:** push to `develop` or `main`

**Optional `with` inputs for Postgres-backed apps** (defaults shown):

| Input | Default | Notes |
|-------|---------|-------|
| `postgres_image` | `postgres:16-alpine` | Service image |
| `postgres_db` | `app_test` | Must match app pytest defaults |
| `postgres_user` | `app` | Superuser in the service container |
| `postgres_password` | `app` | |

Example for an ORM-backed service:

```yaml
with:
  postgres_db: "vdr_test"
  postgres_user: "vdr"
  postgres_password: "vdr"
```

The job exports `POSTGRES_HOST=127.0.0.1`, `POSTGRES_PORT=5432`, and the credentials above for pytest.

---

### 📦 `python-package.yaml`
Reusable workflow for publishing Python packages to AWS CodeArtifact.

**Includes:**
- Poetry version bump based on commit message
- Test execution
- Package build & publish
- Slack notifications

**Triggered on:** push to `main`

---

## 🔑 Required Secrets (Organization Level)

| Secret | Description |
|--------|--------------|
| `AWS_ROLE_TO_ASSUME` | IAM role for GitHub OIDC authentication |
| `CODEARTIFACT_DOMAIN_OWNER` | AWS Account ID owning the CodeArtifact domain |
| `SLACK_WEBHOOK_URL` | Incoming Slack webhook for notifications |

---

## 🧩 Usage in Other Repositories

Add the following workflow file inside your service repo (for example `.github/workflows/deploy.yaml`):

```yaml
name: CI - Django Service

on:
  push:
    branches:
      - develop
      - main
  workflow_dispatch:

permissions:
  id-token: write
  contents: write
  actions: read

jobs:
  deploy:
    uses: musimap/cicd/.github/workflows/python-service-django.yaml@main
    secrets: inherit
    with:
      poetry_sources: |
        [
          {"name": "aws-musimap-utils", "repo": "musimap-utils"},
          {"name": "aws-musimap-aws", "repo": "musimap-aws"},
          {"name": "aws-musimap-audiofile", "repo": "musimap-audiofile"},
          ...
        ]
```

Or for a Python package:

```yaml
name: CI – Python Package

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  id-token: write
  contents: write
  actions: read

jobs:
  publish:
    uses: musimap/cicd/.github/workflows/python-package.yaml@main
    secrets: inherit
    with:
      poetry_sources: |
        [
          {"name": "aws-musimap-utils", "repo": "musimap-utils"},
          {"name": "aws-musimap-aws", "repo": "musimap-aws"},
          {"name": "aws-musimap-audiofile", "repo": "musimap-audiofile"},
          ...
        ]
```

You also need to add the following workflows inside your service repo (for example `.github/workflows/error-pipeline.yaml`):

```yaml
name: Error Pipeline Notifications

on:
  workflow_run:
    workflows:
      - "CI - Django Service"
      - "CI – Python Package"
    types:
      - completed

jobs:
  notify_failure:
    uses: musimap/cicd/.github/workflows/error-pipeline.yaml@main
    secrets: inherit
```

and

```yaml
name: Post Release Tasks

on:
  workflow_run:
    workflows:
      - "CI - Django Service"
      - "CI – Python Package"
    types:
      - completed

permissions:
  id-token: write
  contents: write
  actions: read

jobs:
  post-release:
    uses: musimap/cicd/.github/workflows/post-release.yaml@main
    secrets: inherit
```

So, the files structure in your repository should be similar to: 

```
.github/
└── workflows/
    ├── django-deploy.yaml
    ├── or package-publish.yaml
    ├── error-pipeline.yaml
    └── post-release.yaml
```

---

## 🧠 Commit Message Rules

To trigger automatic versioning, include one of these tags in your commit message:

| Tag | Action |
|-----|---------|
| `[init]` | Initialize version (0.1.0) |
| `[patch]` | Increment patch version |
| `[minor]` | Increment minor version |
| `[major]` | Increment major version |

Example:

```
feat: add OAuth2 refresh token support [minor]
```

---

## 📣 Slack Notifications

All pipelines send formatted Slack notifications including:
- Repository name
- Branch
- Version
- Commit message
- Status (success/failure)

Example message:
```
:rocket: *msm-iam* published!
*New Version:* 1.3.2
*Commit:* fix OAuth validation [patch]
*Branch:* develop
```

---

## 🧭 Conventions

- All step files use the `.yaml` extension.
- Every reusable step handles a single responsibility.
- No hard-coded AWS identifiers — all injected via secrets or environment variables.
- All notifications and outputs are standardized.

---

## 👨‍💻 Maintenance

To update a step for all projects:
1. Edit the corresponding `_partials/steps-*.yaml` file.
2. Commit and push to `main`.
3. All services using `@main` will immediately benefit from the update.

To pin to a specific version instead of `@main`, use a tag reference like:

```yaml
uses: musimap/cicd/github-actions/_partials/steps-pytest.yaml@v1.0.0
```

---

© 2025 Musimap — Engineered with ❤️ by Frederic Notet.
