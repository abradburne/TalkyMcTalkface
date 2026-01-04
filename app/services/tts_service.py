"""
TTS Service encapsulating MLX Chatterbox model state.
"""
import asyncio
from pathlib import Path
from typing import Dict, Optional, List
from concurrent.futures import ThreadPoolExecutor
import functools

from app.config import VOICES_DIR, AUDIO_DIR, MLX_MODEL_REPO, TTS_SAMPLE_RATE


class Voice:
    """Represents an available voice for TTS."""
    def __init__(self, id: str, display_name: str, file_path: str, duration: Optional[float] = None):
        self.id = id
        self.display_name = display_name
        self.file_path = file_path
        self.duration = duration


class TTSService:
    """
    Encapsulates TTS model state and generation logic using MLX Chatterbox.

    Provides async-safe methods for TTS generation.
    Uses asyncio.Lock to prevent concurrent model access.
    """

    MODEL_REPO_ID = MLX_MODEL_REPO

    def __init__(self):
        self.model = None
        self._voices: Dict[str, Voice] = {}
        self._lock = asyncio.Lock()
        self._executor = ThreadPoolExecutor(max_workers=1)
        self._loaded = False
        self._loading = False

    @property
    def is_loaded(self) -> bool:
        """Check if the model is loaded."""
        return self._loaded and self.model is not None

    @property
    def is_loading(self) -> bool:
        """Check if the model is currently being loaded."""
        return self._loading

    def is_model_cached(self) -> bool:
        """
        Check if the MLX Chatterbox model is already cached locally.

        This checks HuggingFace's cache without making network requests.
        Returns True if the model files exist locally, False otherwise.
        """
        try:
            from huggingface_hub import try_to_load_from_cache, _CACHED_NO_EXIST

            # Check for MLX model config file to verify download completed
            cached_path = try_to_load_from_cache(self.MODEL_REPO_ID, 'config.json')

            if cached_path is None or cached_path is _CACHED_NO_EXIST:
                return False
            return isinstance(cached_path, str)
        except Exception:
            return False

    def load_model(self, local_only: bool = False):
        """
        Load the MLX Chatterbox model.

        Args:
            local_only: If True, only load from cache (no downloads).
                        Raises FileNotFoundError if not cached.
        """
        from mlx_audio.tts.utils import load_model

        if local_only and not self.is_model_cached():
            raise FileNotFoundError(
                'Model not cached. Use /model/download to download the model first.'
            )

        self._loading = True
        try:
            self.model = load_model(self.MODEL_REPO_ID)
            self._loaded = True
        except OSError as e:
            error_msg = str(e).lower()
            if 'token' in error_msg or 'authentication' in error_msg or '401' in error_msg:
                raise PermissionError(
                    'HuggingFace authentication required. '
                    'Set HF_TOKEN environment variable or run: huggingface-cli login'
                ) from e
            elif 'connection' in error_msg or 'network' in error_msg or 'timeout' in error_msg:
                raise ConnectionError(
                    f'Network error downloading model: {e}. '
                    'Check your internet connection and try again.'
                ) from e
            else:
                raise
        finally:
            self._loading = False

    def scan_voices(self) -> Dict[str, Voice]:
        """
        Scan voices directory for available voice files.

        Uses exact filename stem as both id and display_name:
            C3-PO.wav -> id=C3-PO, display_name=C3-PO
        """
        self._voices = {}

        if VOICES_DIR.exists():
            for f in VOICES_DIR.glob('*.wav'):
                stem = f.stem
                self._voices[stem] = Voice(
                    id=stem,
                    display_name=stem,
                    file_path=str(f),
                    duration=None,
                )

        return self._voices

    def get_voices(self) -> List[Voice]:
        """Get list of all available voices."""
        return list(self._voices.values())

    def get_voice(self, voice_id: str) -> Optional[Voice]:
        """Get a specific voice by ID."""
        return self._voices.get(voice_id)

    def get_voice_ids(self) -> List[str]:
        """Get list of all voice IDs."""
        return list(self._voices.keys())

    def _generate_sync(self, text: str, output_path: Path, voice_path: Optional[str] = None) -> int:
        """
        Synchronous generation using MLX Chatterbox.

        Returns file size in bytes.
        """
        from mlx_audio.tts.generate import generate_audio

        output_dir = output_path.parent
        output_stem = output_path.stem

        # generate_audio creates files with pattern: {prefix}_0.wav
        generate_audio(
            text=text,
            model=self.model,
            ref_audio=voice_path,
            file_prefix=str(output_dir / output_stem),
            audio_format='wav',
            play=False,
            verbose=False,
        )

        # Rename from {stem}_000.wav to expected path
        # mlx_audio generates with 3-digit suffix: prefix_000.wav
        generated_file = output_dir / f'{output_stem}_000.wav'
        if generated_file.exists() and generated_file != output_path:
            generated_file.rename(output_path)

        return output_path.stat().st_size

    async def generate(self, text: str, voice_id: Optional[str] = None) -> tuple:
        """
        Generate TTS audio asynchronously.

        This method maintains API compatibility but now generates directly to a temp file
        and returns the audio data.

        Args:
            text: Text to synthesize
            voice_id: Voice ID (None = default voice)

        Returns:
            Tuple of (audio_array, sample_rate)
        """
        import numpy as np
        import scipy.io.wavfile as wav
        import tempfile

        voice_path = None
        if voice_id:
            voice = self.get_voice(voice_id)
            if voice:
                voice_path = voice.file_path

        async with self._lock:
            loop = asyncio.get_event_loop()

            # Generate to temp file
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                tmp_path = Path(tmp.name)

            await loop.run_in_executor(
                self._executor,
                functools.partial(self._generate_sync, text, tmp_path, voice_path)
            )

            # Read back the audio
            sr, audio = wav.read(str(tmp_path))
            tmp_path.unlink()  # Clean up temp file

            return audio, sr

    async def generate_to_file(self, text: str, output_path: Path, voice_id: Optional[str] = None) -> int:
        """
        Generate TTS audio and save to file.

        Args:
            text: Text to synthesize
            output_path: Path to save the audio file
            voice_id: Voice ID (None = default voice)

        Returns:
            File size in bytes
        """
        voice_path = None
        if voice_id:
            voice = self.get_voice(voice_id)
            if voice:
                voice_path = voice.file_path

        output_path.parent.mkdir(parents=True, exist_ok=True)

        async with self._lock:
            loop = asyncio.get_event_loop()
            file_size = await loop.run_in_executor(
                self._executor,
                functools.partial(self._generate_sync, text, output_path, voice_path)
            )
            return file_size

    def cleanup(self):
        """Clean up resources."""
        self._executor.shutdown(wait=False)
        self.model = None
        self._loaded = False


# Singleton instance
_tts_service: Optional[TTSService] = None


def get_tts_service() -> TTSService:
    """
    Get the TTS service singleton instance.

    Usage with FastAPI dependency injection:
        @app.get('/voices')
        async def get_voices(tts: TTSService = Depends(get_tts_service)):
            return tts.get_voices()
    """
    global _tts_service
    if _tts_service is None:
        _tts_service = TTSService()
    return _tts_service


def reset_tts_service():
    """Reset the TTS service singleton (for testing)."""
    global _tts_service
    if _tts_service is not None:
        _tts_service.cleanup()
    _tts_service = None
