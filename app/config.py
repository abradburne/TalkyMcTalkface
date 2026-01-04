"""
Application configuration and paths.
"""
from pathlib import Path

# Application identity
APP_NAME = 'TalkyMcTalkface'
APP_VERSION = '0.1.0'

# Server configuration
SERVER_HOST = '127.0.0.1'
SERVER_PORT = 5111

# Paths
SCRIPT_DIR = Path(__file__).parent.parent

# Static files and templates
STATIC_DIR = Path(__file__).parent / 'static'
TEMPLATES_DIR = Path(__file__).parent / 'templates'

# Application Support directory (macOS standard)
APP_SUPPORT_DIR = Path.home() / 'Library' / 'Application Support' / APP_NAME

# Database configuration
DATABASE_PATH = APP_SUPPORT_DIR / 'talky.db'
DATABASE_URL = f'sqlite+aiosqlite:///{DATABASE_PATH}'

# Audio storage
AUDIO_DIR = APP_SUPPORT_DIR / 'audio'

# Voice prompts storage (user-managed voice library)
VOICES_DIR = APP_SUPPORT_DIR / 'voices'

# MLX Model configuration (Turbo = faster, 1-step diffusion)
MLX_MODEL_REPO = 'mlx-community/chatterbox-turbo-6bit'

# Chatterbox sample rate (fixed by model)
TTS_SAMPLE_RATE = 24000


def ensure_directories():
    """Create required directories if they don't exist."""
    APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    VOICES_DIR.mkdir(parents=True, exist_ok=True)
