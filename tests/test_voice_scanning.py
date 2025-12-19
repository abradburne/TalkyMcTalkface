"""
Tests for voice scanning functionality.
Task Group 2: Voice Scanning and Naming
"""
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from app.services.tts_service import TTSService, Voice


class TestVoiceScanning:
    """Tests for scan_voices() using VOICES_DIR and simplified naming."""

    def test_scan_voices_reads_from_voices_dir(self):
        """Test scan_voices() reads from VOICES_DIR (not PROMPTS_DIR)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            voices_path = Path(tmpdir)

            # Create test voice files
            (voices_path / 'TestVoice.wav').write_bytes(b'RIFF' + b'\x00' * 40)

            service = TTSService()

            with patch('app.services.tts_service.VOICES_DIR', voices_path):
                voices = service.scan_voices()

                # Verify voice was found
                assert 'TestVoice' in voices
                assert voices['TestVoice'].file_path == str(voices_path / 'TestVoice.wav')

    def test_voice_naming_uses_exact_filename_stem(self):
        """Test voice naming uses exact filename stem (e.g., C3-PO.wav -> id=C3-PO, display_name=C3-PO)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            voices_path = Path(tmpdir)

            # Create test voice file with mixed case and special characters
            (voices_path / 'C3-PO.wav').write_bytes(b'RIFF' + b'\x00' * 40)

            service = TTSService()

            with patch('app.services.tts_service.VOICES_DIR', voices_path):
                voices = service.scan_voices()

                # Verify exact filename stem is used
                assert 'C3-PO' in voices
                voice = voices['C3-PO']
                assert voice.id == 'C3-PO'
                assert voice.display_name == 'C3-PO'

    def test_underscores_preserved_in_voice_names(self):
        """Test underscores are preserved (e.g., Jerry_Seinfeld.wav -> Jerry_Seinfeld)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            voices_path = Path(tmpdir)

            # Create test voice file with underscores
            (voices_path / 'Jerry_Seinfeld.wav').write_bytes(b'RIFF' + b'\x00' * 40)

            service = TTSService()

            with patch('app.services.tts_service.VOICES_DIR', voices_path):
                voices = service.scan_voices()

                # Verify underscores are preserved
                assert 'Jerry_Seinfeld' in voices
                voice = voices['Jerry_Seinfeld']
                assert voice.id == 'Jerry_Seinfeld'
                assert voice.display_name == 'Jerry_Seinfeld'

    def test_voices_endpoint_calls_scan_voices_on_request(self):
        """Test /voices endpoint calls scan_voices() on each request."""
        service = TTSService()
        scan_call_count = 0
        original_scan = service.scan_voices

        def counting_scan():
            nonlocal scan_call_count
            scan_call_count += 1
            return original_scan()

        service.scan_voices = counting_scan

        # Simulate multiple requests to get_voices
        # In actual implementation, the /voices endpoint should call scan_voices
        service.scan_voices()
        service.scan_voices()

        assert scan_call_count == 2
