"""
Health check endpoint.
"""
from typing import List
from pydantic import BaseModel
from fastapi import APIRouter, Depends

from app.config import APP_VERSION
from app.services.tts_service import TTSService, get_tts_service


router = APIRouter(tags=['health'])


class HealthResponse(BaseModel):
    """Health check response schema."""
    status: str
    model_loaded: bool
    model_loading: bool  # True while model is loading in background
    model_cached: bool   # True if model is cached locally
    available_voices: List[str]
    version: str


@router.get('/health', response_model=HealthResponse)
async def health_check(tts: TTSService = Depends(get_tts_service)) -> HealthResponse:
    """
    Check server health status.

    Returns model status, available voices, and server version.
    Fast response - no database queries.
    """
    return HealthResponse(
        status='ok',
        model_loaded=tts.is_loaded,
        model_loading=tts.is_loading,
        model_cached=tts.is_model_cached(),
        available_voices=tts.get_voice_ids(),
        version=APP_VERSION,
    )
