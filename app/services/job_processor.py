"""
Background job processor for TTS generation.
"""
import asyncio
import logging
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import AUDIO_DIR
from app.models.job import Job, JobStatus
from app.database import async_session_factory
from app.services.tts_service import get_tts_service

logger = logging.getLogger(__name__)


class JobProcessor:
    """
    Background job processor using asyncio.Queue.

    Processes TTS jobs sequentially (model requires exclusive access).
    """

    def __init__(self):
        self._queue: asyncio.Queue[str] = asyncio.Queue()
        self._running = False
        self._task: Optional[asyncio.Task] = None

    async def start(self):
        """Start the background job processor."""
        self._running = True
        self._task = asyncio.create_task(self._process_loop())

    async def stop(self):
        """Stop the background job processor gracefully."""
        self._running = False
        if self._task:
            # Put a sentinel to wake up the queue if waiting
            await self._queue.put('')
            try:
                await asyncio.wait_for(self._task, timeout=5.0)
            except asyncio.TimeoutError:
                self._task.cancel()
                try:
                    await self._task
                except asyncio.CancelledError:
                    pass

    async def enqueue(self, job_id: str):
        """Add a job ID to the processing queue."""
        await self._queue.put(job_id)

    async def _process_loop(self):
        """Main processing loop - consumes jobs from queue."""
        while self._running:
            try:
                # Wait for a job with timeout to allow checking _running flag
                try:
                    job_id = await asyncio.wait_for(self._queue.get(), timeout=1.0)
                except asyncio.TimeoutError:
                    continue

                # Check for sentinel value
                if not job_id:
                    continue

                await self._process_job(job_id)
                self._queue.task_done()

            except Exception as e:
                # Log but don't crash the loop
                logger.exception('Error in job processor loop')

    async def _process_job(self, job_id: str):
        """Process a single job."""
        async with async_session_factory() as session:
            # Fetch the job
            result = await session.execute(
                select(Job).where(Job.id == job_id)
            )
            job = result.scalar_one_or_none()

            if not job:
                logger.warning('Job %s not found', job_id)
                return

            if job.status != JobStatus.pending.value:
                logger.warning('Job %s is not pending (status: %s)', job_id, job.status)
                return

            # Update status to processing
            job.status = JobStatus.processing.value
            await session.commit()

            # Process the job
            start_time = time.time()
            try:
                tts_service = get_tts_service()

                # Generate audio
                output_path = AUDIO_DIR / f'{job_id}.wav'
                file_size = await tts_service.generate_to_file(
                    text=job.text,
                    output_path=output_path,
                    voice_id=job.voice_id,
                )

                # Calculate duration
                duration_ms = int((time.time() - start_time) * 1000)

                # Update job with success
                job.status = JobStatus.completed.value
                job.completed_at = datetime.utcnow()
                job.audio_path = str(output_path)
                job.duration_ms = duration_ms
                job.file_size_bytes = file_size

            except Exception as e:
                # Calculate duration even for failures
                duration_ms = int((time.time() - start_time) * 1000)

                # Update job with failure
                job.status = JobStatus.failed.value
                job.completed_at = datetime.utcnow()
                job.error_message = str(e)
                job.duration_ms = duration_ms

                logger.error('Job %s failed: %s', job_id, e)

            await session.commit()


# Singleton instance
_job_processor: Optional[JobProcessor] = None


def get_job_processor() -> JobProcessor:
    """Get the job processor singleton instance."""
    global _job_processor
    if _job_processor is None:
        _job_processor = JobProcessor()
    return _job_processor


def reset_job_processor():
    """Reset the job processor singleton (for testing)."""
    global _job_processor
    _job_processor = None
