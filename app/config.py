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

# Model configuration
MODEL_DEVICE = 'mps'  # Metal Performance Shaders for Apple Silicon

# Clear GPU cache after each generation (reduces peak memory, slight overhead)
MODEL_AGGRESSIVE_MEMORY = True


def ensure_directories():
    """Create required directories if they don't exist."""
    APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    VOICES_DIR.mkdir(parents=True, exist_ok=True)
