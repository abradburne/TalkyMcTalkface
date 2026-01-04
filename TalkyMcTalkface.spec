# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for TalkyMcTalkface.

Bundles the Python TTS server with all dependencies including:
- FastAPI/Uvicorn server
- MLX framework for Apple Silicon
- MLX-Audio Chatterbox TTS
- All application source files and data

Usage:
    pyinstaller TalkyMcTalkface.spec

Output:
    dist/TalkyMcTalkface/ - Directory containing bundled executable
"""
import os
import sys
from pathlib import Path

# PyInstaller imports
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_all

# Project root directory
PROJECT_ROOT = Path(SPECPATH)

# Determine if we're on Apple Silicon
IS_ARM64 = os.uname().machine == 'arm64'


# -------------------------------------------------------------------
# Hidden Imports
# -------------------------------------------------------------------
# PyInstaller often misses these dynamic imports

hidden_imports = [
    # FastAPI and dependencies
    'fastapi',
    'uvicorn',
    'uvicorn.logging',
    'uvicorn.loops',
    'uvicorn.loops.auto',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets',
    'uvicorn.protocols.websockets.auto',
    'uvicorn.lifespan',
    'uvicorn.lifespan.on',
    'starlette',
    'starlette.routing',
    'starlette.staticfiles',
    'starlette.responses',
    'pydantic',
    'pydantic_core',
    'anyio',
    'anyio._backends._asyncio',

    # Database
    'sqlalchemy',
    'sqlalchemy.ext.asyncio',
    'aiosqlite',

    # MLX framework
    'mlx',
    'mlx.core',
    'mlx.nn',
    'mlx.optimizers',
    'mlx.utils',

    # MLX-Audio TTS
    'mlx_audio',
    'mlx_audio.tts',
    'mlx_audio.tts.models',
    'mlx_audio.tts.models.chatterbox',
    'mlx_audio.tts.generate',
    'mlx_audio.tts.utils',
    'mlx_audio.tts.audio_player',

    # MLX-LM (required by chatterbox)
    'mlx_lm',
    'mlx_lm.models',
    'mlx_lm.models.cache',

    # Audio I/O
    'sounddevice',

    # Transformers and HuggingFace
    'transformers',
    'transformers.models',
    'tokenizers',
    'safetensors',
    'huggingface_hub',
    'filelock',
    'fsspec',
    'regex',
    'tqdm',

    # Audio processing
    'soundfile',
    'scipy',
    'scipy.signal',
    'scipy.io',
    'scipy.io.wavfile',
    'numpy',

    # Image processing (required by transformers)
    'PIL',
    'PIL.Image',

    # HTTP client
    'httpx',
    'httpcore',

    # App modules
    'app',
    'app.config',
    'app.database',
    'app.models',
    'app.models.job',
    'app.routers',
    'app.routers.health',
    'app.routers.voices',
    'app.routers.jobs',
    'app.routers.model',
    'app.schemas',
    'app.schemas.job',
    'app.schemas.voice',
    'app.services',
    'app.services.tts_service',
    'app.services.job_processor',
]

# Collect all submodules for complex packages
for pkg in ['mlx', 'mlx_audio', 'mlx_lm', 'transformers', 'scipy']:
    try:
        hidden_imports.extend(collect_submodules(pkg))
    except Exception:
        pass  # Package may not be installed during spec analysis


# -------------------------------------------------------------------
# Data Files
# -------------------------------------------------------------------
# Non-Python files that need to be included
# NOTE: Voice prompts are NOT bundled - users manage their own voice library
# in ~/Library/Application Support/TalkyMcTalkface/voices/

datas = [
    # Application data (prompts folder removed - voices managed externally)
    (str(PROJECT_ROOT / 'app' / 'static'), 'app/static'),
    (str(PROJECT_ROOT / 'app' / 'templates'), 'app/templates'),
]

# Collect data files from dependencies
for pkg in ['mlx', 'mlx_audio', 'transformers', 'tokenizers', 'PIL']:
    try:
        pkg_datas = collect_data_files(pkg)
        datas.extend(pkg_datas)
    except Exception:
        pass

# -------------------------------------------------------------------
# Binary Dependencies
# -------------------------------------------------------------------
# Shared libraries and native extensions

binaries = []

# Manually add PIL binary extensions (PyInstaller sometimes misses these)
try:
    import PIL
    pil_path = Path(PIL.__file__).parent
    for so_file in pil_path.glob('*.so'):
        binaries.append((str(so_file), 'PIL'))
except ImportError:
    pass

# Explicitly collect PIL/Pillow (all data, binaries, and submodules)
try:
    pil_datas, pil_binaries, pil_hiddenimports = collect_all('PIL')
    datas.extend(pil_datas)
    binaries.extend(pil_binaries)
    hidden_imports.extend(pil_hiddenimports)
except Exception:
    pass


# -------------------------------------------------------------------
# Analysis
# -------------------------------------------------------------------

a = Analysis(
    [str(PROJECT_ROOT / 'server.py')],
    pathex=[str(PROJECT_ROOT)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude unused heavy packages
        'matplotlib',
        'cv2',
        'opencv',
        'tensorflow',
        'keras',
        'torch',  # Using MLX instead
        'torchaudio',
        'IPython',
        'jupyter',
        'notebook',
        # Exclude test frameworks
        'pytest',
        'pytest_asyncio',
        # Exclude development tools
        'black',
        'mypy',
        'flake8',
        'pylint',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)


# -------------------------------------------------------------------
# PYZ Archive
# -------------------------------------------------------------------

pyz = PYZ(
    a.pure,
    a.zipped_data,
    cipher=None,
)


# -------------------------------------------------------------------
# Executable
# -------------------------------------------------------------------

exe = EXE(
    pyz,
    a.scripts,
    [],  # Exclude binaries from EXE for COLLECT
    exclude_binaries=True,
    name='TalkyMcTalkface',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,  # UPX can cause issues
    console=True,  # Server needs console for logging
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,  # Code signing handled separately
    entitlements_file=None,
)


# -------------------------------------------------------------------
# Collect All Files
# -------------------------------------------------------------------

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='TalkyMcTalkface',
)


# -------------------------------------------------------------------
# Notes for macOS .app Bundle Integration
# -------------------------------------------------------------------
#
# The output from this spec file goes to:
#   dist/TalkyMcTalkface/
#
# For integration with the Swift macOS app:
# 1. Copy dist/TalkyMcTalkface/ to:
#    TalkyMcTalkface.app/Contents/Resources/python-backend/
#
# 2. The Swift app should launch:
#    Contents/Resources/python-backend/TalkyMcTalkface
#
# 3. Voice prompts are managed by users in:
#    ~/Library/Application Support/TalkyMcTalkface/voices/
#
# To build:
#   pyinstaller TalkyMcTalkface.spec
#
# To test standalone:
#   ./dist/TalkyMcTalkface/TalkyMcTalkface
#
