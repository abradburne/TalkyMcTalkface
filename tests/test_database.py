"""
Task Group 2: Database Layer Tests

Tests for SQLite database setup, WAL mode, and Job model.
"""
import pytest
import pytest_asyncio
from datetime import datetime
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.job import Job, JobStatus


class TestDatabaseConfiguration:
    """Tests for database configuration."""

    def test_database_path_in_application_support(self):
        """Test database is configured to be in Application Support."""
        from app.config import DATABASE_PATH

        assert 'Application Support' in str(DATABASE_PATH)
        assert 'TalkyMcTalkface' in str(DATABASE_PATH)
        assert DATABASE_PATH.name == 'talky.db'


class TestWALMode:
    """Tests for SQLite WAL mode."""

    @pytest.mark.asyncio
    async def test_wal_mode_can_be_enabled(self, test_engine):
        """Test that WAL mode can be enabled on the database."""
        async with test_engine.begin() as conn:
            result = await conn.execute(text('PRAGMA journal_mode=WAL'))
            mode = result.scalar()
            # SQLite returns 'wal' when WAL mode is enabled
            assert mode in ('wal', 'WAL')


class TestJobModel:
    """Tests for Job SQLAlchemy model."""

    @pytest.mark.asyncio
    async def test_create_job(self, test_session: AsyncSession):
        """Test creating a job record."""
        job = Job(
            text='Hello world',
            voice_id=None,
            status=JobStatus.pending.value,
        )
        test_session.add(job)
        await test_session.commit()

        # Verify job was created
        result = await test_session.execute(select(Job).where(Job.id == job.id))
        saved_job = result.scalar_one()

        assert saved_job.text == 'Hello world'
        assert saved_job.voice_id is None
        assert saved_job.status == JobStatus.pending.value

    @pytest.mark.asyncio
    async def test_job_has_uuid_id(self, test_session: AsyncSession):
        """Test job gets a UUID ID automatically."""
        job = Job(text='Test text', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        assert job.id is not None
        assert len(job.id) == 36  # UUID format: 8-4-4-4-12

    @pytest.mark.asyncio
    async def test_job_created_at_auto_populates(self, test_session: AsyncSession):
        """Test created_at is automatically populated."""
        job = Job(text='Test text', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        assert job.created_at is not None
        assert isinstance(job.created_at, datetime)

    @pytest.mark.asyncio
    async def test_job_status_transitions(self, test_session: AsyncSession):
        """Test job status can be updated through transitions."""
        job = Job(text='Test text', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        # Transition to processing
        job.status = JobStatus.processing.value
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        updated_job = result.scalar_one()
        assert updated_job.status == JobStatus.processing.value

        # Transition to completed
        job.status = JobStatus.completed.value
        job.completed_at = datetime.utcnow()
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        completed_job = result.scalar_one()
        assert completed_job.status == JobStatus.completed.value
        assert completed_job.completed_at is not None

    @pytest.mark.asyncio
    async def test_job_with_all_fields(self, test_session: AsyncSession):
        """Test job with all fields populated."""
        job = Job(
            text='Test text',
            voice_id='jerry-seinfeld',
            status=JobStatus.completed.value,
            completed_at=datetime.utcnow(),
            audio_path='/path/to/audio.wav',
            error_message=None,
            duration_ms=1500,
            file_size_bytes=123456,
        )
        test_session.add(job)
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        saved_job = result.scalar_one()

        assert saved_job.voice_id == 'jerry-seinfeld'
        assert saved_job.audio_path == '/path/to/audio.wav'
        assert saved_job.duration_ms == 1500
        assert saved_job.file_size_bytes == 123456

    @pytest.mark.asyncio
    async def test_job_failed_status(self, test_session: AsyncSession):
        """Test job with failed status and error message."""
        job = Job(
            text='Test text',
            status=JobStatus.failed.value,
            error_message='Model inference error',
            duration_ms=100,
        )
        test_session.add(job)
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        saved_job = result.scalar_one()

        assert saved_job.status == JobStatus.failed.value
        assert saved_job.error_message == 'Model inference error'


class TestJobStatus:
    """Tests for JobStatus enum."""

    def test_job_status_values(self):
        """Test JobStatus enum has correct values."""
        assert JobStatus.pending.value == 'pending'
        assert JobStatus.processing.value == 'processing'
        assert JobStatus.completed.value == 'completed'
        assert JobStatus.failed.value == 'failed'

    def test_job_status_is_string(self):
        """Test JobStatus inherits from str for JSON serialization."""
        assert isinstance(JobStatus.pending, str)
        assert JobStatus.pending == 'pending'
