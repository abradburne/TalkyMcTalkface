"""
Pytest fixtures for testing.
"""
import os
import asyncio
import tempfile
from pathlib import Path
from typing import AsyncGenerator
from unittest.mock import MagicMock, patch, AsyncMock

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.models import Base
from app.database import get_db
from app.services.tts_service import TTSService, get_tts_service, reset_tts_service
from app.services.job_processor import reset_job_processor


# Use a temporary database for tests
@pytest.fixture(scope='session')
def temp_db_path():
    """Create a temporary database path for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir) / 'test.db'


@pytest.fixture(scope='session')
def temp_audio_dir():
    """Create a temporary audio directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture(scope='function')
def test_db_url(temp_db_path):
    """Generate test database URL."""
    return f'sqlite+aiosqlite:///{temp_db_path}'


@pytest_asyncio.fixture(scope='function')
async def test_engine(test_db_url):
    """Create a test database engine."""
    engine = create_async_engine(test_db_url, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture(scope='function')
async def test_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    session_factory = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session


@pytest.fixture
def mock_tts_service():
    """Create a mock TTS service for testing."""
    service = MagicMock(spec=TTSService)
    service.is_loaded = True
    service.get_voice_ids.return_value = ['jerry-seinfeld', 'custom-voice']
    service.get_voices.return_value = [
        MagicMock(
            id='jerry-seinfeld',
            display_name='Jerry Seinfeld',
            file_path='/path/to/jerry_seinfeld_prompt.wav',
            duration=None,
        ),
        MagicMock(
            id='custom-voice',
            display_name='Custom Voice',
            file_path='/path/to/custom_voice_prompt.wav',
            duration=None,
        ),
    ]
    service.get_voice.return_value = MagicMock(
        id='jerry-seinfeld',
        display_name='Jerry Seinfeld',
        file_path='/path/to/jerry_seinfeld_prompt.wav',
        duration=None,
    )
    return service


@pytest_asyncio.fixture
async def client(test_engine, mock_tts_service, temp_audio_dir):
    """Create a test client with mocked dependencies."""
    # Reset singletons
    reset_tts_service()
    reset_job_processor()

    # Import app after resetting singletons
    from server import app
    from app.database import async_session_factory
    from app.services.job_processor import get_job_processor

    # Create session factory for test engine
    test_session_factory = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def override_get_db():
        async with test_session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    def override_get_tts_service():
        return mock_tts_service

    # Override dependencies
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_tts_service] = override_get_tts_service

    # Patch config
    with patch('app.config.AUDIO_DIR', temp_audio_dir):
        with patch('app.services.job_processor.AUDIO_DIR', temp_audio_dir):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url='http://test') as client:
                yield client

    # Clean up
    app.dependency_overrides.clear()
    reset_tts_service()
    reset_job_processor()


@pytest.fixture
def prompts_dir(tmp_path):
    """Create a temporary prompts directory with test voice files (legacy)."""
    prompts = tmp_path / 'prompts'
    prompts.mkdir()

    # Create dummy voice files
    (prompts / 'jerry_seinfeld_prompt.wav').write_bytes(b'RIFF' + b'\x00' * 40)
    (prompts / 'custom_voice_prompt.wav').write_bytes(b'RIFF' + b'\x00' * 40)

    return prompts


@pytest.fixture
def voices_dir(tmp_path):
    """Create a temporary voices directory with test voice files."""
    voices = tmp_path / 'voices'
    voices.mkdir()

    # Create dummy voice files with exact filename stems (no _prompt suffix)
    (voices / 'Jerry_Seinfeld.wav').write_bytes(b'RIFF' + b'\x00' * 40)
    (voices / 'Custom_Voice.wav').write_bytes(b'RIFF' + b'\x00' * 40)

    return voices
