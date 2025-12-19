"""
Pydantic schemas for Job API operations.
"""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict

from app.models.job import JobStatus


class JobCreate(BaseModel):
    """Schema for creating a new TTS job."""
    text: str = Field(..., min_length=1, description='The text to synthesize')
    voice_id: Optional[str] = Field(None, description='Voice slug (null = default voice)')


class JobResponse(BaseModel):
    """Schema for job response."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    text: str
    voice_id: Optional[str]
    status: str
    created_at: datetime
    completed_at: Optional[datetime]
    audio_path: Optional[str]
    error_message: Optional[str]
    duration_ms: Optional[int]
    file_size_bytes: Optional[int]


class JobListResponse(BaseModel):
    """Schema for paginated job list response."""
    jobs: List[JobResponse]
    total: int
    limit: int
    offset: int
