# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TalkyMcTalkface is a macOS menu bar app for text-to-speech using Chatterbox TurboTTS voice cloning. It combines a Swift/SwiftUI frontend with a Python FastAPI backend, communicating via REST API on localhost:5111.

## Architecture

```
┌─────────────────────────────────────┐
│         SwiftUI MenuBarExtra        │
│   (TalkyMcTalkface.xcodeproj)       │
└──────────────┬──────────────────────┘
               │ HTTP localhost:5111
┌──────────────▼──────────────────────┐
│         FastAPI Backend             │
│   (server.py → app/)                │
│         ┌───────────┐               │
│         │Chatterbox │               │
│         │ TurboTTS  │               │
│         └───────────┘               │
└─────────────────────────────────────┘
```

- **Swift app** spawns Python backend as subprocess via `SubprocessManager.swift`
- **Python backend** is bundled via PyInstaller into `dist/TalkyMcTalkface/`
- **Data storage**: `~/Library/Application Support/TalkyMcTalkface/` (database, models, voices, audio)

## Development Commands

### Python Backend

```bash
# Setup
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install chatterbox-tts

# Run server standalone
python server.py

# Run tests
pytest tests/ -v
pytest tests/test_tts_service.py -v  # single file
pytest tests/test_api.py::test_health -v  # single test

# Build Python bundle for app
./scripts/build_python_backend.sh
```

### Swift App

```bash
# Open in Xcode
open TalkyMcTalkface/TalkyMcTalkface.xcodeproj

# Build and run: Cmd+R in Xcode
# Run tests: Cmd+U in Xcode
```

### Distribution

```bash
# Full build (Python + Swift + sign + notarize + DMG)
./scripts/build_distribution.sh

# Skip rebuilding Python/Swift, just recreate DMG
./scripts/build_distribution.sh --skip-python --skip-swift

# Output locations
# - App: build/Release/TalkyMcTalkface.app
# - DMG: dist/TalkyMcTalkface.dmg
```

## Key Files

### Python Backend
- `server.py` - FastAPI entry point, runs on 127.0.0.1:5111
- `app/routers/` - API endpoints (health, voices, jobs, model)
- `app/services/tts_service.py` - Chatterbox TTS wrapper
- `app/services/job_processor.py` - Async job queue
- `app/config.py` - Configuration and paths

### Swift Frontend
- `TalkyMcTalkface/TalkyMcTalkfaceApp.swift` - App entry point (@main)
- `TalkyMcTalkface/Views/StatusPopoverView.swift` - Main popover UI
- `TalkyMcTalkface/SubprocessManager.swift` - Python backend lifecycle
- `TalkyMcTalkface/Services/` - API clients and app state

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| /health | GET | Server health check |
| /voices | GET | List available voices |
| /jobs | POST | Create TTS job |
| /jobs/{id} | GET | Job status |
| /jobs/{id}/audio | GET | Download audio |
| /model/status | GET | Model download status |
| /model/download | POST | Trigger model download |

## Tech Stack

- **Frontend**: Swift 6, SwiftUI, macOS 14+, Xcode 15+
- **Backend**: Python 3.11+, FastAPI, Uvicorn, SQLAlchemy (async), SQLite
- **TTS**: Chatterbox TurboTTS, PyTorch with MPS acceleration
- **Bundling**: PyInstaller for Python, Xcode for Swift
- **Distribution**: Developer ID signing, Apple notarization
