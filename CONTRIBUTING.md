# Contributing to TalkyMcTalkface

Thank you for your interest in contributing! This document provides guidelines for contributing to TalkyMcTalkface.

## Code of Conduct

Be respectful and constructive. We're all here to build something useful together.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up the development environment (see README.md)
4. Create a branch for your changes

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Python 3.11+
- Xcode 15+
- Git

### Setting Up

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/TalkyMcTalkface.git
cd TalkyMcTalkface

# Create Python virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install chatterbox-tts

# Run tests to verify setup
pytest tests/ -v
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/voice-preview` - New features
- `fix/audio-playback-crash` - Bug fixes
- `docs/api-examples` - Documentation updates

### Code Style

**Python:**
- Follow PEP 8
- Use type hints where practical
- Keep functions focused and small

**Swift:**
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Keep views small and composable

### Testing

- Add tests for new functionality
- Ensure existing tests pass before submitting
- Run the full test suite:

```bash
pytest tests/ -v
```

### Commit Messages

Write clear, concise commit messages:

```
Add voice preview playback in settings

- Add preview button next to voice selector
- Implement 3-second audio preview
- Handle playback errors gracefully
```

## Submitting Changes

1. Push your branch to your fork
2. Open a Pull Request against `main`
3. Fill out the PR template
4. Wait for review

### Pull Request Guidelines

- Keep PRs focused on a single change
- Include screenshots for UI changes
- Update documentation if needed
- Ensure all tests pass

## Reporting Issues

### Bug Reports

Include:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs from Console.app

### Feature Requests

Describe:
- The problem you're trying to solve
- Your proposed solution
- Alternatives you've considered

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  SwiftUI App                        │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ StatusPopover│  │ SettingsView │  │ JobsView  │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
│                         │                           │
│                    ┌────▼────┐                      │
│                    │ Services │                     │
│                    └────┬────┘                      │
└─────────────────────────┼───────────────────────────┘
                          │ HTTP (localhost:5111)
┌─────────────────────────┼───────────────────────────┐
│                    ┌────▼────┐                      │
│                    │ FastAPI │      Python Backend  │
│                    └────┬────┘                      │
│         ┌───────────────┼───────────────┐           │
│    ┌────▼────┐    ┌─────▼─────┐   ┌─────▼─────┐    │
│    │ Routers │    │TTSService │   │JobProcessor│    │
│    └─────────┘    └───────────┘   └───────────┘    │
│                          │                          │
│                   ┌──────▼──────┐                   │
│                   │  Chatterbox │                   │
│                   │  TurboTTS   │                   │
│                   └─────────────┘                   │
└─────────────────────────────────────────────────────┘
```

## Areas for Contribution

### Good First Issues

- Documentation improvements
- Test coverage expansion
- UI polish and accessibility
- Error message improvements

### Larger Projects

- Windows/Linux support
- Additional TTS model backends
- Batch processing improvements
- Plugin system for voice effects

## Questions?

Open an issue with the "question" label, or start a discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
