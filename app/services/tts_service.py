"""
TTS Service encapsulating Chatterbox TurboTTS model state.
"""
import asyncio
from pathlib import Path
from typing import Dict, Optional, List
from concurrent.futures import ThreadPoolExecutor
import functools

from app.config import VOICES_DIR, MODEL_DEVICE, AUDIO_DIR, MODEL_AGGRESSIVE_MEMORY


class Voice:
    """Represents an available voice for TTS."""
    def __init__(self, id: str, display_name: str, file_path: str, duration: Optional[float] = None):
        self.id = id
        self.display_name = display_name
        self.file_path = file_path
        self.duration = duration


class TTSService:
    """
    Encapsulates TTS model state and generation logic.

    Provides async-safe methods for TTS generation using Chatterbox TurboTTS.
    Uses asyncio.Lock to prevent concurrent model access (model is not thread-safe).
    """

    def __init__(self):
        self.model = None
        self.default_conds = None
        self._voices: Dict[str, Voice] = {}
        self._lock = asyncio.Lock()
        self._executor = ThreadPoolExecutor(max_workers=1)
        self._loaded = False

    @property
    def is_loaded(self) -> bool:
        """Check if the model is loaded."""
        return self._loaded and self.model is not None

    def load_model(self):
        """
        Load the Chatterbox TurboTTS model.

        Must be called from the main thread during startup.
        The Perth watermarker patch must be applied before importing chatterbox.
        """
        import torch
        from chatterbox.tts_turbo import ChatterboxTurboTTS

        self.model = ChatterboxTurboTTS.from_pretrained(device=MODEL_DEVICE)
        self.default_conds = self.model.conds
        self._loaded = True

    def scan_voices(self) -> Dict[str, Voice]:
        """
        Scan voices directory for available voice files.

        Uses exact filename stem as both id and display_name:
            C3-PO.wav -> id=C3-PO, display_name=C3-PO
            Jerry_Seinfeld.wav -> id=Jerry_Seinfeld, display_name=Jerry_Seinfeld
        """
        self._voices = {}

        if VOICES_DIR.exists():
            for f in VOICES_DIR.glob('*.wav'):
                # Use exact filename stem for both id and display name
                stem = f.stem

                self._voices[stem] = Voice(
                    id=stem,
                    display_name=stem,
                    file_path=str(f),
                    duration=None,  # Could be populated by analyzing audio file
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

    def _generate_sync(self, text: str, voice_path: Optional[str] = None) -> tuple:
        """
        Synchronous generation method to run in executor.

        Returns tuple of (wav_tensor, sample_rate).
        """
        import torch

        with torch.inference_mode():
            if voice_path:
                wav = self.model.generate(text, audio_prompt_path=voice_path)
            else:
                # Restore default voice conditionals
                self.model.conds = self.default_conds
                wav = self.model.generate(text)

            # Synchronize MPS to ensure GPU operations complete before returning
            # This prevents Metal assertion failures when tensors are freed
            if torch.backends.mps.is_available():
                torch.mps.synchronize()

        # Move result to CPU and free GPU memory
        wav_cpu = wav.cpu()
        del wav

        if MODEL_AGGRESSIVE_MEMORY and torch.backends.mps.is_available():
            torch.mps.empty_cache()

        return wav_cpu, self.model.sr

    async def generate(self, text: str, voice_id: Optional[str] = None) -> tuple:
        """
        Generate TTS audio asynchronously.

        Uses asyncio.Lock to ensure exclusive model access.
        Runs actual generation in thread pool to avoid blocking event loop.

        Args:
            text: Text to synthesize
            voice_id: Voice ID (None = default voice)

        Returns:
            Tuple of (wav_tensor, sample_rate)
        """
        voice_path = None
        if voice_id:
            voice = self.get_voice(voice_id)
            if voice:
                voice_path = voice.file_path

        async with self._lock:
            loop = asyncio.get_event_loop()
            wav, sr = await loop.run_in_executor(
                self._executor,
                functools.partial(self._generate_sync, text, voice_path)
            )
            return wav, sr

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
        import torchaudio as ta

        wav, sr = await self.generate(text, voice_id)

        # Ensure output directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Save audio file
        ta.save(str(output_path), wav, sr)

        return output_path.stat().st_size

    def cleanup(self):
        """Clean up resources."""
        self._executor.shutdown(wait=False)
        self.model = None
        self.default_conds = None
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
