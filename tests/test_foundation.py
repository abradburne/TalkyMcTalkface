"""
Task Group 1: Foundation Layer Tests

Tests for server foundation, Perth patch, and health endpoint.
"""
import sys
from unittest.mock import patch, MagicMock

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport


class TestPerthPatch:
    """Tests for Perth watermarker patch."""

    def test_perth_patch_applied_before_chatterbox_import(self):
        """Test that Perth watermarker is patched before Chatterbox import."""
        # The patch must be applied in server.py before importing chatterbox
        try:
            import perth
            # The patch should make PerthImplicitWatermarker == DummyWatermarker
            assert perth.PerthImplicitWatermarker is perth.DummyWatermarker
        except ImportError:
            # If perth is not installed, skip this test
            # The patch is verified when server.py is loaded in production
            pytest.skip('perth module not installed in test environment')

    def test_server_patches_perth_at_top_of_file(self):
        """Test that server.py patches perth before any other chatterbox imports."""
        # Read server.py and verify the patch happens early
        from pathlib import Path
        server_path = Path(__file__).parent.parent / 'server.py'
        content = server_path.read_text()

        # Find where perth patch happens
        perth_patch_pos = content.find('perth.PerthImplicitWatermarker = perth.DummyWatermarker')

        # Find where chatterbox is imported (in app modules)
        chatterbox_import_pos = content.find('from chatterbox')

        # The patch should exist
        assert perth_patch_pos != -1, 'Perth patch not found in server.py'

        # If chatterbox is imported directly in server.py, patch should come first
        if chatterbox_import_pos != -1:
            assert perth_patch_pos < chatterbox_import_pos, \
                'Perth patch must come before chatterbox import'


class TestHealthEndpoint:
    """Tests for GET /health endpoint."""

    @pytest.mark.asyncio
    async def test_health_endpoint_returns_ok(self, client):
        """Test health endpoint returns 200 with status ok."""
        response = await client.get('/health')
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'ok'

    @pytest.mark.asyncio
    async def test_health_endpoint_returns_model_loaded(self, client):
        """Test health endpoint returns model_loaded boolean."""
        response = await client.get('/health')
        data = response.json()
        assert 'model_loaded' in data
        assert isinstance(data['model_loaded'], bool)

    @pytest.mark.asyncio
    async def test_health_endpoint_returns_available_voices(self, client):
        """Test health endpoint returns list of available voices."""
        response = await client.get('/health')
        data = response.json()
        assert 'available_voices' in data
        assert isinstance(data['available_voices'], list)

    @pytest.mark.asyncio
    async def test_health_endpoint_returns_version(self, client):
        """Test health endpoint returns server version string."""
        response = await client.get('/health')
        data = response.json()
        assert 'version' in data
        assert isinstance(data['version'], str)


class TestServerConfiguration:
    """Tests for server configuration."""

    def test_server_binds_to_localhost_only(self):
        """Test server is configured to bind to 127.0.0.1 only."""
        from app.config import SERVER_HOST, SERVER_PORT

        assert SERVER_HOST == '127.0.0.1'
        assert SERVER_PORT == 5111

    def test_app_directories_configured(self):
        """Test application directories are configured correctly."""
        from app.config import APP_SUPPORT_DIR, DATABASE_PATH, AUDIO_DIR

        # Check paths are in Application Support
        assert 'Application Support' in str(APP_SUPPORT_DIR)
        assert 'TalkyMcTalkface' in str(APP_SUPPORT_DIR)
        assert DATABASE_PATH.name == 'talky.db'
        assert AUDIO_DIR.name == 'audio'
