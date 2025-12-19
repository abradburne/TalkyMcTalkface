"""
Pydantic schemas for Voice API operations.
"""
from typing import Optional, List
from pydantic import BaseModel


class VoiceResponse(BaseModel):
    """Schema for voice response."""
    id: str
    display_name: str
    file_path: str
    duration: Optional[float] = None  # Approximate duration in seconds


class VoiceListResponse(BaseModel):
    """Schema for voice list response."""
    voices: List[VoiceResponse]
