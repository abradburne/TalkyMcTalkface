"""
Job model for TTS generation tasks.
"""
import uuid
import enum
from datetime import datetime
from sqlalchemy import Column, String, Text, DateTime, Integer, Enum
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class JobStatus(str, enum.Enum):
    """Status states for TTS jobs."""
    pending = 'pending'
    processing = 'processing'
    completed = 'completed'
    failed = 'failed'


class Job(Base):
    """
    Represents a TTS generation job.

    Attributes:
        id: Unique job identifier (UUID)
        text: The text to synthesize
        voice_id: Voice slug (null = default voice)
        status: Current job status
        created_at: Job creation timestamp
        completed_at: When job finished processing
        audio_path: Path to generated audio file
        error_message: Error details if failed
        duration_ms: Time taken for TTS generation
        file_size_bytes: Size of generated audio file
    """
    __tablename__ = 'jobs'

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    text = Column(Text, nullable=False)
    voice_id = Column(String(100), nullable=True)
    status = Column(String(20), nullable=False, default=JobStatus.pending.value)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    audio_path = Column(Text, nullable=True)
    error_message = Column(Text, nullable=True)
    duration_ms = Column(Integer, nullable=True)
    file_size_bytes = Column(Integer, nullable=True)

    def __repr__(self):
        return f'<Job {self.id} status={self.status}>'
