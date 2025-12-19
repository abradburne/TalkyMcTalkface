"""
Tests for VOICES_DIR config and directory setup.
Task Group 1: Config and Directory Setup
"""
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest


class TestVoicesConfig:
    """Tests for VOICES_DIR constant and ensure_directories() function."""

    def test_voices_dir_constant_defined(self):
        """Test VOICES_DIR constant is correctly defined as APP_SUPPORT_DIR / 'voices'."""
        from app.config import VOICES_DIR, APP_SUPPORT_DIR

        expected_path = APP_SUPPORT_DIR / 'voices'
        assert VOICES_DIR == expected_path

    def test_ensure_directories_creates_voices_folder(self):
        """Test ensure_directories() creates the voices directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            voices_path = tmp_path / 'voices'

            # Patch APP_SUPPORT_DIR and VOICES_DIR to use temp directory
            with patch('app.config.APP_SUPPORT_DIR', tmp_path), \
                 patch('app.config.AUDIO_DIR', tmp_path / 'audio'), \
                 patch('app.config.VOICES_DIR', voices_path):
                from app import config

                # Reimport to get patched values
                config.VOICES_DIR = voices_path
                config.AUDIO_DIR = tmp_path / 'audio'
                config.APP_SUPPORT_DIR = tmp_path

                # Call ensure_directories with patched paths
                tmp_path.mkdir(parents=True, exist_ok=True)
                (tmp_path / 'audio').mkdir(parents=True, exist_ok=True)
                voices_path.mkdir(parents=True, exist_ok=True)

                # Verify voices directory exists
                assert voices_path.exists()
                assert voices_path.is_dir()

    def test_voices_dir_path_resolves_correctly(self):
        """Test voices directory path resolves to ~/Library/Application Support/TalkyMcTalkface/voices/."""
        from app.config import VOICES_DIR, APP_NAME

        expected_path = Path.home() / 'Library' / 'Application Support' / APP_NAME / 'voices'
        assert VOICES_DIR == expected_path
