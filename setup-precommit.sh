#!/bin/bash

# Setup script for pre-commit hooks in Bearound Flutter SDK
# This script installs and configures pre-commit for the project

set -e

echo "🚀 Setting up pre-commit hooks for Bearound Flutter SDK..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "   Please install Python 3 and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed."
    echo "   Please install pip3 and try again."
    exit 1
fi

# Install pre-commit
echo "📦 Installing pre-commit..."
pip3 install pre-commit

# Install detect-secrets
echo "🔐 Installing detect-secrets..."
pip3 install detect-secrets

# Install pre-commit hooks
echo "🔧 Installing pre-commit hooks..."
pre-commit install

# Install commit-msg hook for conventional commits
echo "💬 Installing commit-msg hook..."
pre-commit install --hook-type commit-msg

# Update secrets baseline if needed
echo "🔍 Updating secrets baseline..."
if command -v detect-secrets &> /dev/null; then
    detect-secrets scan --baseline .secrets.baseline --exclude-files '\.lock$|\.g\.dart$' . || true
fi

# Run pre-commit on all files to test setup
echo "🧪 Testing pre-commit setup..."
echo "   Note: This might take a few minutes on first run..."

# Skip the test run if --skip-test argument is provided
if [[ "$1" != "--skip-test" ]]; then
    pre-commit run --all-files || {
        echo "⚠️  Some pre-commit checks failed, but that's expected on first run."
        echo "   The hooks are now installed and will run on future commits."
    }
fi

echo ""
echo "✅ Pre-commit hooks have been successfully installed!"
echo ""
echo "🎯 What happens now:"
echo "   • Pre-commit hooks will run automatically before each commit"
echo "   • Code will be formatted, analyzed, and tested automatically"
echo "   • Commits will be rejected if quality checks fail"
echo ""
echo "📝 Commit message format:"
echo "   Use conventional commits: type(scope): description"
echo "   Examples:"
echo "   • feat(scanner): add background scanning support"
echo "   • fix(permissions): handle Android 12+ permissions"
echo "   • docs(readme): update installation instructions"
echo ""
echo "🔧 Manual commands:"
echo "   • Run hooks manually: pre-commit run --all-files"
echo "   • Update hooks: pre-commit autoupdate"
echo "   • Skip hooks (not recommended): git commit --no-verify"
echo ""
echo "Happy coding! 🎉"