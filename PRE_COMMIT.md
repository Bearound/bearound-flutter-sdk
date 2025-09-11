# Pre-commit Hooks Setup

This project uses pre-commit hooks to maintain code quality automatically.

## Quick Setup

```bash
./setup-precommit.sh
```

## What it Does

✅ **Code Quality Checks:**
- Formats Dart code
- Runs Flutter analyze
- Executes unit tests
- Validates dependencies
- Checks pub.dev readiness

✅ **Security Checks:**
- Detects potential secrets
- Validates file permissions
- Checks for large files

✅ **Commit Standards:**
- Enforces conventional commit messages
- Validates YAML/JSON syntax
- Fixes line endings and whitespace

## Manual Commands

```bash
# Run all hooks
pre-commit run --all-files

# Update hooks
pre-commit autoupdate

# Skip hooks (emergency only)
git commit --no-verify
```

## Commit Format

Use conventional commits:

```
feat(scope): description
fix(scope): description
docs(scope): description
```

Examples:
- `feat(scanner): add background scanning`
- `fix(permissions): handle Android 12+ permissions`
- `docs(readme): update installation guide`

For more details, see [CONTRIBUTING.md](CONTRIBUTING.md#-pre-commit-hooks).