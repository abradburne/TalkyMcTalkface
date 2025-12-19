"""
Task Group 5: Background Processing Tests

Tests for job queue and background processing.
"""
import asyncio
import tempfile
from datetime import datetime
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.job import Job, JobStatus
from app.services.job_processor import JobProcessor, get_job_processor, reset_job_processor


class TestJobStatusTransitions:
    """Tests for job status transitions."""

    @pytest.mark.asyncio
    async def test_job_starts_as_pending(self, test_session: AsyncSession):
        """Test newly created jobs have pending status."""
        job = Job(text='Test', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        saved_job = result.scalar_one()

        assert saved_job.status == JobStatus.pending.value

    @pytest.mark.asyncio
    async def test_job_transitions_to_processing(self, test_session: AsyncSession):
        """Test job transitions from pending to processing."""
        job = Job(text='Test', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        # Transition to processing
        job.status = JobStatus.processing.value
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        updated_job = result.scalar_one()

        assert updated_job.status == JobStatus.processing.value

    @pytest.mark.asyncio
    async def test_job_transitions_to_completed(self, test_session: AsyncSession):
        """Test job transitions from processing to completed."""
        job = Job(text='Test', status=JobStatus.processing.value)
        test_session.add(job)
        await test_session.commit()

        # Transition to completed
        job.status = JobStatus.completed.value
        job.completed_at = datetime.utcnow()
        job.audio_path = '/path/to/audio.wav'
        job.duration_ms = 1500
        job.file_size_bytes = 12345
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        completed_job = result.scalar_one()

        assert completed_job.status == JobStatus.completed.value
        assert completed_job.completed_at is not None
        assert completed_job.audio_path is not None
        assert completed_job.duration_ms == 1500
        assert completed_job.file_size_bytes == 12345

    @pytest.mark.asyncio
    async def test_job_transitions_to_failed(self, test_session: AsyncSession):
        """Test job transitions from processing to failed on error."""
        job = Job(text='Test', status=JobStatus.processing.value)
        test_session.add(job)
        await test_session.commit()

        # Transition to failed
        job.status = JobStatus.failed.value
        job.completed_at = datetime.utcnow()
        job.error_message = 'Model inference failed'
        job.duration_ms = 100
        await test_session.commit()

        result = await test_session.execute(select(Job).where(Job.id == job.id))
        failed_job = result.scalar_one()

        assert failed_job.status == JobStatus.failed.value
        assert failed_job.error_message == 'Model inference failed'
        assert failed_job.completed_at is not None


class TestJobProcessor:
    """Tests for JobProcessor class."""

    def test_job_processor_creates(self):
        """Test JobProcessor initializes correctly."""
        processor = JobProcessor()

        assert processor._queue is not None
        assert processor._running is False
        assert processor._task is None

    @pytest.mark.asyncio
    async def test_job_processor_starts_and_stops(self):
        """Test JobProcessor can start and stop."""
        processor = JobProcessor()

        await processor.start()
        assert processor._running is True
        assert processor._task is not None

        await processor.stop()
        assert processor._running is False

    @pytest.mark.asyncio
    async def test_job_processor_enqueues_job(self):
        """Test jobs can be enqueued."""
        processor = JobProcessor()
        await processor.enqueue('test-job-id')

        # Job should be in queue
        assert processor._queue.qsize() == 1

    @pytest.mark.asyncio
    async def test_job_processor_singleton(self):
        """Test get_job_processor returns singleton."""
        reset_job_processor()

        processor1 = get_job_processor()
        processor2 = get_job_processor()

        assert processor1 is processor2

        reset_job_processor()


class TestAudioFileManagement:
    """Tests for audio file creation and management."""

    def test_audio_directory_path(self):
        """Test audio directory is in Application Support."""
        from app.config import AUDIO_DIR

        assert 'Application Support' in str(AUDIO_DIR)
        assert 'TalkyMcTalkface' in str(AUDIO_DIR)
        assert AUDIO_DIR.name == 'audio'

    @pytest.mark.asyncio
    async def test_audio_path_uses_job_id(self, test_session: AsyncSession):
        """Test audio files are named with job ID."""
        from app.config import AUDIO_DIR

        job = Job(text='Test', status=JobStatus.pending.value)
        test_session.add(job)
        await test_session.commit()

        expected_path = AUDIO_DIR / f'{job.id}.wav'
        assert expected_path.name == f'{job.id}.wav'


class TestSequentialProcessing:
    """Tests for sequential job processing."""

    @pytest.mark.asyncio
    async def test_processor_handles_single_job(self):
        """Test processor can handle a single job."""
        processor = JobProcessor()
        processed_jobs = []

        # Mock the _process_job method
        async def mock_process(job_id):
            processed_jobs.append(job_id)

        processor._process_job = mock_process

        await processor.start()
        await processor.enqueue('job-1')

        # Give time for processing
        await asyncio.sleep(0.2)

        await processor.stop()

        assert 'job-1' in processed_jobs

    @pytest.mark.asyncio
    async def test_processor_processes_jobs_sequentially(self):
        """Test multiple jobs are processed one at a time."""
        processor = JobProcessor()
        processing_order = []
        concurrent_count = 0
        max_concurrent = 0

        async def mock_process(job_id):
            nonlocal concurrent_count, max_concurrent
            concurrent_count += 1
            max_concurrent = max(max_concurrent, concurrent_count)
            processing_order.append(job_id)
            await asyncio.sleep(0.05)  # Simulate processing time
            concurrent_count -= 1

        processor._process_job = mock_process

        await processor.start()

        # Enqueue multiple jobs
        await processor.enqueue('job-1')
        await processor.enqueue('job-2')
        await processor.enqueue('job-3')

        # Wait for all to process
        await asyncio.sleep(0.3)

        await processor.stop()

        # Verify sequential processing
        assert max_concurrent == 1  # Never more than 1 concurrent
        assert len(processing_order) == 3
        assert processing_order == ['job-1', 'job-2', 'job-3']
