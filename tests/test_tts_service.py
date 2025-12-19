"""
Task Group 3: TTS Service Layer Tests

Tests for TTSService class and voice scanning.
"""
import asyncio
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock

import pytest
import pytest_asyncio

from app.services.tts_service import TTSService, Voice, get_tts_service, reset_tts_service


class TestTTSServiceInitialization:
    """Tests for TTSService initialization."""

    def test_tts_service_creates_with_defaults(self):
        """Test TTSService initializes with correct defaults."""
        service = TTSService()

        assert service.model is None
        assert service.default_conds is None
        assert service.is_loaded is False
        assert service._lock is not None

    def test_tts_service_singleton(self):
        """Test get_tts_service returns singleton instance."""
        reset_tts_service()

        service1 = get_tts_service()
        service2 = get_tts_service()

        assert service1 is service2

        reset_tts_service()


class TestVoiceScanning:
    """Tests for voice scanning functionality."""

    def test_voice_slug_conversion(self):
        """Test filename stem is used as voice id (no slug conversion)."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR') as mock_dir:
            # Mock path with fake wav files
            mock_file = MagicMock()
            mock_file.stem = 'Jerry_Seinfeld'
            mock_file.__str__ = lambda x: '/path/to/Jerry_Seinfeld.wav'

            mock_dir.exists.return_value = True
            mock_dir.glob.return_value = [mock_file]

            voices = service.scan_voices()

            # Check exact filename stem is used as id
            assert 'Jerry_Seinfeld' in voices

    def test_voice_display_name_conversion(self):
        """Test filename stem is used as display name (no title case conversion)."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR') as mock_dir:
            mock_file = MagicMock()
            mock_file.stem = 'Jerry_Seinfeld'
            mock_file.__str__ = lambda x: '/path/to/Jerry_Seinfeld.wav'

            mock_dir.exists.return_value = True
            mock_dir.glob.return_value = [mock_file]

            voices = service.scan_voices()

            voice = voices.get('Jerry_Seinfeld')
            assert voice is not None
            assert voice.display_name == 'Jerry_Seinfeld'

    def test_scan_voices_returns_empty_when_no_voices_dir(self):
        """Test scan_voices returns empty dict when voices dir doesn't exist."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR') as mock_dir:
            mock_dir.exists.return_value = False

            voices = service.scan_voices()

            assert voices == {}

    def test_get_voices_returns_list(self, voices_dir):
        """Test get_voices returns list of Voice objects."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR', voices_dir):
            service.scan_voices()
            voices = service.get_voices()

            assert isinstance(voices, list)
            assert len(voices) == 2  # Two voice files in fixture

    def test_get_voice_by_id(self, voices_dir):
        """Test get_voice returns Voice by exact filename stem."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR', voices_dir):
            service.scan_voices()
            voice = service.get_voice('Jerry_Seinfeld')

            assert voice is not None
            assert voice.id == 'Jerry_Seinfeld'
            assert voice.display_name == 'Jerry_Seinfeld'

    def test_get_voice_returns_none_for_invalid_id(self, voices_dir):
        """Test get_voice returns None for invalid id."""
        service = TTSService()

        with patch('app.services.tts_service.VOICES_DIR', voices_dir):
            service.scan_voices()
            voice = service.get_voice('nonexistent-voice')

            assert voice is None


class TestAsyncLock:
    """Tests for asyncio.Lock in TTSService."""

    @pytest.mark.asyncio
    async def test_lock_prevents_concurrent_generation(self):
        """Test asyncio.Lock prevents concurrent model access."""
        service = TTSService()

        # Track lock acquisition
        lock_acquired_times = []

        async def mock_generate():
            async with service._lock:
                lock_acquired_times.append(asyncio.get_event_loop().time())
                await asyncio.sleep(0.1)

        # Run two concurrent tasks
        await asyncio.gather(mock_generate(), mock_generate())

        # The second lock acquisition should be after the first completes
        assert len(lock_acquired_times) == 2
        assert lock_acquired_times[1] >= lock_acquired_times[0] + 0.09


class TestVoiceClass:
    """Tests for Voice dataclass."""

    def test_voice_creation(self):
        """Test Voice object creation."""
        voice = Voice(
            id='jerry-seinfeld',
            display_name='Jerry Seinfeld',
            file_path='/path/to/voice.wav',
            duration=5.5,
        )

        assert voice.id == 'jerry-seinfeld'
        assert voice.display_name == 'Jerry Seinfeld'
        assert voice.file_path == '/path/to/voice.wav'
        assert voice.duration == 5.5

    def test_voice_optional_duration(self):
        """Test Voice with optional duration."""
        voice = Voice(
            id='test',
            display_name='Test',
            file_path='/path',
        )

        assert voice.duration is None
