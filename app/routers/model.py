"""
Model management endpoints for download and status.

Task 3.4: Backend endpoints for model download with progress tracking.
The Chatterbox model is downloaded via HuggingFace/transformers library.
"""
import asyncio
import threading
from typing import Optional
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException

from app.services.tts_service import get_tts_service


router = APIRouter(prefix='/model', tags=['model'])


class ModelDownloadProgress(BaseModel):
    """Progress information for model download."""
    status: str  # 'idle', 'downloading', 'completed', 'error'
    progress: float  # 0.0 to 1.0
    downloaded_bytes: int
    total_bytes: int
    message: str


class ModelDownloadResponse(BaseModel):
    """Response for triggering model download."""
    status: str
    message: str


# Global state for tracking download progress
_download_state = {
    'status': 'idle',
    'progress': 0.0,
    'downloaded_bytes': 0,
    'total_bytes': 0,
    'message': '',
    'lock': threading.Lock(),
}


def _update_download_state(
    status: Optional[str] = None,
    progress: Optional[float] = None,
    downloaded_bytes: Optional[int] = None,
    total_bytes: Optional[int] = None,
    message: Optional[str] = None,
):
    """Thread-safe update of download state."""
    with _download_state['lock']:
        if status is not None:
            _download_state['status'] = status
        if progress is not None:
            _download_state['progress'] = progress
        if downloaded_bytes is not None:
            _download_state['downloaded_bytes'] = downloaded_bytes
        if total_bytes is not None:
            _download_state['total_bytes'] = total_bytes
        if message is not None:
            _download_state['message'] = message


def _get_download_state() -> dict:
    """Thread-safe read of download state."""
    with _download_state['lock']:
        return {
            'status': _download_state['status'],
            'progress': _download_state['progress'],
            'downloaded_bytes': _download_state['downloaded_bytes'],
            'total_bytes': _download_state['total_bytes'],
            'message': _download_state['message'],
        }


def _download_model_sync():
    """
    Synchronous model download function to run in background thread.

    This calls the TTS service load_model() which triggers HuggingFace
    to download the Chatterbox model if not already cached.
    """
    try:
        _update_download_state(
            status='downloading',
            progress=0.1,
            message='Initializing model download...',
        )

        tts_service = get_tts_service()

        # Check if already loaded
        if tts_service.is_loaded:
            _update_download_state(
                status='completed',
                progress=1.0,
                downloaded_bytes=_download_state['total_bytes'],
                message='Model already loaded',
            )
            return

        _update_download_state(
            progress=0.2,
            message='Downloading model files from HuggingFace...',
        )

        # Load model - this triggers the HuggingFace download
        tts_service.load_model()

        # Scan for voices after model loads
        _update_download_state(
            progress=0.9,
            message='Scanning available voices...',
        )
        tts_service.scan_voices()

        _update_download_state(
            status='completed',
            progress=1.0,
            message='Model download complete',
        )

    except Exception as e:
        _update_download_state(
            status='error',
            message=f'Download failed: {str(e)}',
        )


@router.get('/progress', response_model=ModelDownloadProgress)
async def get_download_progress() -> ModelDownloadProgress:
    """
    Get current model download progress.

    Returns progress information including status, percentage, and bytes.
    """
    state = _get_download_state()
    return ModelDownloadProgress(
        status=state['status'],
        progress=state['progress'],
        downloaded_bytes=state['downloaded_bytes'],
        total_bytes=state['total_bytes'],
        message=state['message'],
    )


@router.post('/download', response_model=ModelDownloadResponse)
async def trigger_model_download() -> ModelDownloadResponse:
    """
    Trigger model download.

    Starts the model download in a background thread.
    Returns immediately while download proceeds asynchronously.
    Use /model/progress to poll for progress updates.
    """
    tts_service = get_tts_service()

    # Check if already loaded
    if tts_service.is_loaded:
        return ModelDownloadResponse(
            status='completed',
            message='Model already loaded',
        )

    # Check if already downloading
    state = _get_download_state()
    if state['status'] == 'downloading':
        raise HTTPException(
            status_code=409,
            detail='Download already in progress',
        )

    # Estimate total bytes (approximate Chatterbox model size)
    # The actual size varies but this gives users a sense of progress
    estimated_size = 1_500_000_000  # ~1.5 GB estimate

    _update_download_state(
        status='downloading',
        progress=0.0,
        downloaded_bytes=0,
        total_bytes=estimated_size,
        message='Starting download...',
    )

    # Start download in background thread
    # We use a thread because model loading is CPU-bound and blocking
    download_thread = threading.Thread(target=_download_model_sync, daemon=True)
    download_thread.start()

    return ModelDownloadResponse(
        status='started',
        message='Model download started',
    )


@router.get('/status')
async def get_model_status() -> dict:
    """
    Get current model status.

    Returns whether the model is loaded and ready for use.
    """
    tts_service = get_tts_service()
    return {
        'loaded': tts_service.is_loaded,
        'voices': tts_service.get_voice_ids() if tts_service.is_loaded else [],
    }
