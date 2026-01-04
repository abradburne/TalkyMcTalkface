# TalkyMcTalkface

A macOS menu bar app for text-to-speech generation using [Chatterbox TurboTTS](https://github.com/resemble-ai/chatterbox), an open-source voice cloning model from Resemble AI.

## Features

- **Menu Bar Integration** - Lives in your menu bar for quick access
- **Voice Cloning** - Clone any voice from a short audio sample
- **Job Queue** - Queue multiple TTS jobs and track their progress
- **Clipboard Support** - Automatically reads text from clipboard
- **Local Processing** - All processing happens on your machine, no cloud required
- **REST API** - Control via localhost API for automation and scripting

## Requirements

- macOS 14.0 (Sonoma) or later
- ~4GB disk space for the TTS model

## Installation

### Download (Recommended)

Download the latest release from [GitHub Releases](https://github.com/abradburne/TalkyMcTalkface/releases):

1. Download `TalkyMcTalkface.dmg`
2. Open the DMG and drag TalkyMcTalkface to your Applications folder
3. Launch from Applications (you may need to right-click → Open on first launch)

### Building from Source

Requires Python 3.11+ and Xcode 15+.

1. **Clone the repository**
   ```bash
   git clone https://github.com/abradburne/TalkyMcTalkface.git
   cd TalkyMcTalkface
   ```

2. **Set up Python environment**
   ```bash
   python3.11 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   pip install chatterbox-tts
   ```

3. **Build the Python backend**
   ```bash
   ./scripts/build_python_backend.sh
   ```

4. **Open in Xcode and build**
   ```bash
   open TalkyMcTalkface/TalkyMcTalkface.xcodeproj
   ```
   Then press Cmd+R to build and run.

### First Launch

On first launch, the app will download the Chatterbox TurboTTS model (~1.5GB). This only happens once.

## Usage

### Basic Usage

1. Click the menu bar icon to open the popover
2. Type or paste text into the input field
3. Select a voice (optional)
4. Click "Generate" to create speech
5. Play the audio or export to a file

### Adding Voice Samples

Place `.wav` files in the voices directory:
```
~/Library/Application Support/TalkyMcTalkface/voices/
```

Voice files should be:
- WAV format
- 5-30 seconds of clear speech
- Named descriptively (e.g., `Morgan_Freeman.wav`)

The voice picker refreshes automatically when you add new files.

### REST API

The app runs a local server on `http://127.0.0.1:5111`. Example usage:

```bash
# List available voices
curl http://127.0.0.1:5111/voices

# Create a TTS job
curl -X POST http://127.0.0.1:5111/jobs \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello world", "voice_id": null}'

# Check job status
curl http://127.0.0.1:5111/jobs/{job_id}

# Download audio
curl http://127.0.0.1:5111/jobs/{job_id}/audio -o output.wav
```

### CLI Tool

Install the CLI for terminal usage:
```bash
# From the app's Settings
Click "Install CLI Tool"

# Then use from terminal
talky "Hello from the command line"
talky -v Morgan_Freeman "I can do any voice"
```

## Project Structure

```
TalkyMcTalkface/
├── app/                    # Python FastAPI backend
│   ├── routers/           # API endpoints
│   ├── services/          # TTS and job processing
│   └── config.py          # Configuration
├── TalkyMcTalkface/       # Swift macOS app
│   └── TalkyMcTalkface/
│       ├── Views/         # SwiftUI views
│       ├── Services/      # Backend communication
│       └── Models/        # Data models
├── scripts/               # Build and distribution scripts
├── tests/                 # Python test suite
├── server.py              # FastAPI server entry point
└── TalkyMcTalkface.spec   # PyInstaller configuration
```

## Development

### Running Tests

```bash
# Activate virtual environment
source .venv/bin/activate

# Run all tests
pytest tests/ -v

# Run specific test file
pytest tests/test_tts_service.py -v
```

### Running the Backend Standalone

```bash
source .venv/bin/activate
python server.py
```

The server will start on `http://127.0.0.1:5111`.

### Building for Distribution

```bash
# Build the Python backend
./scripts/build_python_backend.sh

# Build the complete .app bundle
./scripts/build_distribution.sh

# Create a signed DMG (requires Apple Developer account)
./scripts/create_dmg.sh
```

## Troubleshooting

### Model Download Fails

If the model download fails, you can manually download it:
```bash
# The model will be saved to:
~/Library/Application Support/TalkyMcTalkface/models/
```

### No Audio Output

1. Check System Preferences > Sound > Output
2. Ensure the app has microphone permissions (for voice preview)
3. Try restarting the app

### High Memory Usage

The TTS model requires ~2-4GB of RAM. If memory is constrained:
1. Close other applications
2. The model unloads after periods of inactivity

## Credits

- [Chatterbox TurboTTS](https://github.com/resemble-ai/chatterbox) by Resemble AI - MIT License
- [Perth](https://github.com/resemble-ai/perth) audio watermarking - MIT License

## License

MIT License - see [LICENSE](LICENSE) for details.
