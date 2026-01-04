"""
Model management endpoints for download and status.

The MLX Chatterbox model is downloaded via HuggingFace hub.
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
    'cancel_requested': False,
    'download_thread': None,
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
            progress=0.05,
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

        # Check for cancellation before expensive operations
        if _download_state['cancel_requested']:
            _update_download_state(
                status='idle',
                progress=0.0,
                message='Download cancelled',
            )
            return

        # Check if cached but not loaded
        if tts_service.is_model_cached():
            _update_download_state(
                progress=0.8,
                message='Model found in cache, loading...',
            )
        else:
            _update_download_state(
                progress=0.1,
                message='Downloading model files from HuggingFace (~1.5 GB)... This may take several minutes.',
            )

        # Load model - this triggers the HuggingFace download if not cached
        # Note: HuggingFace download cannot be interrupted mid-file
        tts_service.load_model(local_only=False)

        # Check for cancellation after download (before marking complete)
        if _download_state['cancel_requested']:
            _update_download_state(
                status='idle',
                progress=0.0,
                message='Download cancelled (model files may be partially cached)',
            )
            return

        # Scan for voices after model loads
        _update_download_state(
            progress=0.95,
            message='Scanning available voices...',
        )
        tts_service.scan_voices()

        _update_download_state(
            status='completed',
            progress=1.0,
            message='Model ready! You can now generate speech.',
        )

    except PermissionError as e:
        # Authentication error
        _update_download_state(
            status='error',
            message=str(e),
        )
    except ConnectionError as e:
        # Network error
        _update_download_state(
            status='error',
            message=str(e),
        )
    except FileNotFoundError as e:
        # Model not found (shouldn't happen in this path)
        _update_download_state(
            status='error',
            message=str(e),
        )
    except Exception as e:
        # Check for common HuggingFace errors
        error_msg = str(e).lower()
        if 'token' in error_msg or 'authentication' in error_msg or '401' in error_msg:
            _update_download_state(
                status='error',
                message='HuggingFace authentication required. Set HF_TOKEN environment variable.',
            )
        elif 'connection' in error_msg or 'network' in error_msg:
            _update_download_state(
                status='error',
                message=f'Network error: {e}. Check your internet connection.',
            )
        elif 'space' in error_msg or 'disk' in error_msg:
            _update_download_state(
                status='error',
                message=f'Insufficient disk space. The model requires ~2GB free space.',
            )
        else:
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


@router.post('/cancel', response_model=ModelDownloadResponse)
async def cancel_model_download() -> ModelDownloadResponse:
    """
    Request cancellation of the current model download.

    Note: The download may not stop immediately as HuggingFace downloads
    cannot be interrupted mid-file. The cancellation will take effect
    between file downloads.
    """
    state = _get_download_state()
    if state['status'] != 'downloading':
        return ModelDownloadResponse(
            status='not_downloading',
            message='No download in progress',
        )

    with _download_state['lock']:
        _download_state['cancel_requested'] = True

    return ModelDownloadResponse(
        status='cancelling',
        message='Cancellation requested. Download will stop shortly.',
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

    # Reset state for new download
    with _download_state['lock']:
        _download_state['cancel_requested'] = False

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
    _download_state['download_thread'] = download_thread

    return ModelDownloadResponse(
        status='started',
        message='Model download started',
    )


@router.get('/status')
async def get_model_status() -> dict:
    """
    Get current model status.

    Returns whether the model is loaded, cached, and ready for use.
    """
    tts_service = get_tts_service()
    is_cached = tts_service.is_model_cached()
    is_loaded = tts_service.is_loaded
    download_state = _get_download_state()

    return {
        'loaded': is_loaded,
        'cached': is_cached,
        'download_required': not is_cached and not is_loaded,
        'downloading': download_state['status'] == 'downloading',
        'voices': tts_service.get_voice_ids() if is_loaded else [],
        'message': _get_status_message(is_loaded, is_cached, download_state),
    }


def _get_status_message(is_loaded: bool, is_cached: bool, download_state: dict) -> str:
    """Generate a human-readable status message."""
    if is_loaded:
        return 'Model loaded and ready'
    if download_state['status'] == 'downloading':
        return download_state['message']
    if download_state['status'] == 'error':
        return f"Download error: {download_state['message']}"
    if is_cached:
        return 'Model cached but not loaded. Restart the server to load.'
    return 'Model not downloaded. Click "Download Model" to get started (~1.5 GB).'
