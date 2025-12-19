"""
Voice endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.services.tts_service import TTSService, get_tts_service
from app.schemas.voice import VoiceResponse, VoiceListResponse


router = APIRouter(prefix='/voices', tags=['voices'])


@router.get('', response_model=VoiceListResponse)
async def list_voices(tts: TTSService = Depends(get_tts_service)) -> VoiceListResponse:
    """
    List all available voices.

    Rescans the voices directory on each request to detect newly added voice files.
    Returns voice IDs and display names.
    """
    # Rescan voices directory on each request for on-demand refresh
    tts.scan_voices()
    voices = tts.get_voices()
    return VoiceListResponse(
        voices=[
            VoiceResponse(
                id=v.id,
                display_name=v.display_name,
                file_path=v.file_path,
                duration=v.duration,
            )
            for v in voices
        ]
    )


@router.get('/{voice_id}', response_model=VoiceResponse)
async def get_voice(
    voice_id: str,
    tts: TTSService = Depends(get_tts_service)
) -> VoiceResponse:
    """
    Get details for a specific voice.

    Args:
        voice_id: Voice ID (e.g., 'C3-PO')

    Returns:
        Voice details including file path and duration.

    Raises:
        404: Voice not found
    """
    voice = tts.get_voice(voice_id)
    if not voice:
        raise HTTPException(status_code=404, detail=f'Voice not found: {voice_id}')

    return VoiceResponse(
        id=voice.id,
        display_name=voice.display_name,
        file_path=voice.file_path,
        duration=voice.duration,
    )
