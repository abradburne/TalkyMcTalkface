#!/usr/bin/env python3
"""
TalkyMcTalkface FastAPI Server

A job-based TTS generation server using Chatterbox TurboTTS.
Provides async API endpoints for voice listing, job management, and audio retrieval.
"""
# CRITICAL: Must be first for PyInstaller multiprocessing support
import multiprocessing
if __name__ == '__main__':
    multiprocessing.freeze_support()
    multiprocessing.set_start_method('spawn', force=True)

import os

# Disable torch multiprocessing workers
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'

# Suppress tokenizers parallelism warning
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

# CRITICAL: Patch Perth watermarker for macOS compatibility
# Must be done before ANY Chatterbox imports
import perth
perth.PerthImplicitWatermarker = perth.DummyWatermarker

from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse
from starlette.staticfiles import StaticFiles

from app.config import APP_NAME, APP_VERSION, SERVER_HOST, SERVER_PORT, STATIC_DIR, TEMPLATES_DIR
from app.database import init_db, close_db
from app.services.tts_service import get_tts_service
from app.services.job_processor import get_job_processor
from app.routers import health_router, voices_router, jobs_router, model_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan context manager.

    Startup:
        - Initialize database and create tables
        - Load TTS model (if available/cached)
        - Scan available voices
        - Start job processor

    Shutdown:
        - Stop job processor
        - Clean up model resources
        - Close database connections
    """
    print(f'Starting {APP_NAME} v{APP_VERSION}...')

    # Initialize database
    print('Initializing database...')
    await init_db()

    # Try to load TTS model (will succeed if model is already cached)
    # Task 3.2: If model not cached, health endpoint will show model_loaded=false
    print('Checking for TTS model...')
    tts_service = get_tts_service()

    try:
        tts_service.load_model()
        print('Model loaded!')

        # Scan voices
        voices = tts_service.scan_voices()
        if voices:
            print(f'Available voices: {", ".join(voices.keys())}')
        else:
            print('No voices found. Add .wav files to ~/Library/Application Support/TalkyMcTalkface/voices/')
    except Exception as e:
        # Model not available yet - this is expected on first launch
        # User will need to trigger download via /model/download endpoint
        print(f'Model not loaded (first launch or download required): {e}')
        print('Use /model/download endpoint to download the model')

    # Start job processor
    print('Starting job processor...')
    job_processor = get_job_processor()
    await job_processor.start()

    print(f'Server ready at http://{SERVER_HOST}:{SERVER_PORT}')
    print('API documentation available at /docs')
    print('Web UI available at /')

    yield

    # Shutdown
    print('Shutting down...')

    # Stop job processor
    await job_processor.stop()

    # Cleanup TTS service
    tts_service.cleanup()

    # Close database
    await close_db()

    print('Shutdown complete.')


# Create FastAPI application
app = FastAPI(
    title=APP_NAME,
    description='A job-based TTS generation server using Chatterbox TurboTTS.',
    version=APP_VERSION,
    lifespan=lifespan,
)

# Register routers
app.include_router(health_router)
app.include_router(voices_router)
app.include_router(jobs_router)
app.include_router(model_router)

# Mount static files
app.mount('/static', StaticFiles(directory=str(STATIC_DIR)), name='static')


@app.get('/', include_in_schema=False)
async def root():
    """Serve the web UI."""
    return FileResponse(str(TEMPLATES_DIR / 'index.html'))


if __name__ == '__main__':
    uvicorn.run(
        app,
        host=SERVER_HOST,
        port=SERVER_PORT,
        reload=False,
        log_level='info',
    )
