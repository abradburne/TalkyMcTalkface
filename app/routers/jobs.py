"""
Job endpoints for TTS generation.
"""
import os
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.job import Job, JobStatus
from app.schemas.job import JobCreate, JobResponse, JobListResponse
from app.services.job_processor import get_job_processor


router = APIRouter(prefix='/jobs', tags=['jobs'])


@router.get('', response_model=JobListResponse)
async def list_jobs(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
) -> JobListResponse:
    """
    List all TTS jobs with pagination.

    Returns jobs ordered by creation time (newest first).
    """
    # Get total count
    count_result = await db.execute(select(func.count(Job.id)))
    total = count_result.scalar()

    # Get paginated jobs
    result = await db.execute(
        select(Job)
        .order_by(Job.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    jobs = result.scalars().all()

    return JobListResponse(
        jobs=[JobResponse.model_validate(job) for job in jobs],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post('', response_model=JobResponse, status_code=201)
async def create_job(
    job_data: JobCreate,
    db: AsyncSession = Depends(get_db),
) -> JobResponse:
    """
    Create a new TTS generation job.

    Returns immediately with job ID and pending status.
    Job is processed asynchronously in the background.
    """
    # Create job record
    job = Job(
        text=job_data.text,
        voice_id=job_data.voice_id,
        status=JobStatus.pending.value,
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    # Queue job for processing
    processor = get_job_processor()
    await processor.enqueue(job.id)

    return JobResponse.model_validate(job)


@router.get('/{job_id}', response_model=JobResponse)
async def get_job(
    job_id: str,
    db: AsyncSession = Depends(get_db),
) -> JobResponse:
    """
    Get details for a specific job.

    Returns job status, timestamps, and audio path if completed.
    """
    result = await db.execute(select(Job).where(Job.id == job_id))
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail=f'Job not found: {job_id}')

    return JobResponse.model_validate(job)


@router.get('/{job_id}/audio')
async def get_job_audio(
    job_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Stream the audio file for a completed job.

    Returns audio file with proper Content-Type header.

    Raises:
        404: Job not found or audio not ready
    """
    result = await db.execute(select(Job).where(Job.id == job_id))
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail=f'Job not found: {job_id}')

    if job.status != JobStatus.completed.value:
        raise HTTPException(
            status_code=404,
            detail=f'Audio not ready. Job status: {job.status}'
        )

    if not job.audio_path or not Path(job.audio_path).exists():
        raise HTTPException(status_code=404, detail='Audio file not found')

    # Build descriptive filename
    voice_part = job.voice_id or 'default'
    timestamp_part = job.created_at.strftime('%Y%m%d-%H%M%S') if job.created_at else 'audio'
    filename = f'{voice_part}-{timestamp_part}.wav'

    return FileResponse(
        path=job.audio_path,
        media_type='audio/wav',
        filename=filename,
    )


@router.delete('/{job_id}', status_code=204)
async def delete_job(
    job_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Delete a specific job and its associated audio file.
    """
    result = await db.execute(select(Job).where(Job.id == job_id))
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail=f'Job not found: {job_id}')

    # Delete audio file if exists
    if job.audio_path and Path(job.audio_path).exists():
        try:
            os.remove(job.audio_path)
        except OSError:
            pass  # Ignore file deletion errors

    # Delete job record
    await db.delete(job)
    await db.commit()


@router.delete('', status_code=204)
async def delete_all_jobs(db: AsyncSession = Depends(get_db)):
    """
    Delete all jobs and their associated audio files.

    Used for clearing history.
    """
    # Get all jobs with audio paths
    result = await db.execute(select(Job.audio_path).where(Job.audio_path.isnot(None)))
    audio_paths = [row[0] for row in result.fetchall()]

    # Delete audio files
    for audio_path in audio_paths:
        if audio_path and Path(audio_path).exists():
            try:
                os.remove(audio_path)
            except OSError:
                pass  # Ignore file deletion errors

    # Delete all job records
    await db.execute(delete(Job))
    await db.commit()
