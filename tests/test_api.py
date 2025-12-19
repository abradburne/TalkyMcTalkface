"""
Task Group 4: API Layer Tests

Tests for voice and job endpoints.
"""
import pytest
import pytest_asyncio
from unittest.mock import MagicMock, patch
from datetime import datetime

from app.models.job import Job, JobStatus


class TestVoiceEndpoints:
    """Tests for /voices endpoints."""

    @pytest.mark.asyncio
    async def test_list_voices(self, client):
        """Test GET /voices returns list of voices."""
        response = await client.get('/voices')

        assert response.status_code == 200
        data = response.json()
        assert 'voices' in data
        assert isinstance(data['voices'], list)

    @pytest.mark.asyncio
    async def test_list_voices_contains_slug_ids(self, client):
        """Test voices list contains slug IDs."""
        response = await client.get('/voices')
        data = response.json()

        for voice in data['voices']:
            assert 'id' in voice
            assert isinstance(voice['id'], str)
            # Slug should contain hyphens, not underscores
            assert '_' not in voice['id']

    @pytest.mark.asyncio
    async def test_list_voices_contains_display_names(self, client):
        """Test voices list contains display names."""
        response = await client.get('/voices')
        data = response.json()

        for voice in data['voices']:
            assert 'display_name' in voice
            assert isinstance(voice['display_name'], str)

    @pytest.mark.asyncio
    async def test_get_single_voice(self, client):
        """Test GET /voices/{id} returns single voice."""
        response = await client.get('/voices/jerry-seinfeld')

        assert response.status_code == 200
        data = response.json()
        assert data['id'] == 'jerry-seinfeld'
        assert 'display_name' in data
        assert 'file_path' in data

    @pytest.mark.asyncio
    async def test_get_voice_not_found(self, client, mock_tts_service):
        """Test GET /voices/{id} returns 404 for invalid ID."""
        mock_tts_service.get_voice.return_value = None

        response = await client.get('/voices/nonexistent-voice')

        assert response.status_code == 404


class TestJobEndpoints:
    """Tests for /jobs endpoints."""

    @pytest.mark.asyncio
    async def test_create_job_returns_pending(self, client):
        """Test POST /jobs creates job with pending status."""
        response = await client.post('/jobs', json={'text': 'Hello world'})

        assert response.status_code == 201
        data = response.json()
        assert data['status'] == 'pending'
        assert data['text'] == 'Hello world'
        assert 'id' in data

    @pytest.mark.asyncio
    async def test_create_job_with_voice_id(self, client):
        """Test POST /jobs accepts voice_id parameter."""
        response = await client.post('/jobs', json={
            'text': 'Hello world',
            'voice_id': 'jerry-seinfeld',
        })

        assert response.status_code == 201
        data = response.json()
        assert data['voice_id'] == 'jerry-seinfeld'

    @pytest.mark.asyncio
    async def test_create_job_requires_text(self, client):
        """Test POST /jobs requires text field."""
        response = await client.post('/jobs', json={})

        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_create_job_rejects_empty_text(self, client):
        """Test POST /jobs rejects empty text."""
        response = await client.post('/jobs', json={'text': ''})

        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_list_jobs_returns_paginated(self, client):
        """Test GET /jobs returns paginated list."""
        # Create some jobs first
        await client.post('/jobs', json={'text': 'Job 1'})
        await client.post('/jobs', json={'text': 'Job 2'})

        response = await client.get('/jobs')

        assert response.status_code == 200
        data = response.json()
        assert 'jobs' in data
        assert 'total' in data
        assert 'limit' in data
        assert 'offset' in data

    @pytest.mark.asyncio
    async def test_list_jobs_newest_first(self, client):
        """Test GET /jobs returns jobs ordered newest first."""
        await client.post('/jobs', json={'text': 'First job'})
        await client.post('/jobs', json={'text': 'Second job'})

        response = await client.get('/jobs')
        data = response.json()

        jobs = data['jobs']
        if len(jobs) >= 2:
            assert jobs[0]['text'] == 'Second job'
            assert jobs[1]['text'] == 'First job'

    @pytest.mark.asyncio
    async def test_list_jobs_pagination(self, client):
        """Test GET /jobs respects limit and offset."""
        # Create some jobs
        for i in range(5):
            await client.post('/jobs', json={'text': f'Job {i}'})

        response = await client.get('/jobs?limit=2&offset=1')
        data = response.json()

        assert len(data['jobs']) == 2
        assert data['limit'] == 2
        assert data['offset'] == 1

    @pytest.mark.asyncio
    async def test_get_single_job(self, client):
        """Test GET /jobs/{id} returns job details."""
        # Create a job
        create_response = await client.post('/jobs', json={'text': 'Test job'})
        job_id = create_response.json()['id']

        response = await client.get(f'/jobs/{job_id}')

        assert response.status_code == 200
        data = response.json()
        assert data['id'] == job_id
        assert data['text'] == 'Test job'

    @pytest.mark.asyncio
    async def test_get_job_not_found(self, client):
        """Test GET /jobs/{id} returns 404 for invalid ID."""
        response = await client.get('/jobs/nonexistent-id')

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_single_job(self, client):
        """Test DELETE /jobs/{id} removes job."""
        # Create a job
        create_response = await client.post('/jobs', json={'text': 'Test job'})
        job_id = create_response.json()['id']

        # Delete the job
        delete_response = await client.delete(f'/jobs/{job_id}')
        assert delete_response.status_code == 204

        # Verify job is gone
        get_response = await client.get(f'/jobs/{job_id}')
        assert get_response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_job_not_found(self, client):
        """Test DELETE /jobs/{id} returns 404 for invalid ID."""
        response = await client.delete('/jobs/nonexistent-id')

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_all_jobs(self, client):
        """Test DELETE /jobs clears all history."""
        # Create some jobs
        await client.post('/jobs', json={'text': 'Job 1'})
        await client.post('/jobs', json={'text': 'Job 2'})

        # Delete all jobs
        delete_response = await client.delete('/jobs')
        assert delete_response.status_code == 204

        # Verify jobs are gone
        list_response = await client.get('/jobs')
        data = list_response.json()
        assert data['total'] == 0


class TestAudioEndpoint:
    """Tests for /jobs/{id}/audio endpoint."""

    @pytest.mark.asyncio
    async def test_get_audio_not_found_when_pending(self, client):
        """Test GET /jobs/{id}/audio returns 404 when job is pending."""
        # Create a job (will be pending)
        create_response = await client.post('/jobs', json={'text': 'Test'})
        job_id = create_response.json()['id']

        response = await client.get(f'/jobs/{job_id}/audio')

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_audio_job_not_found(self, client):
        """Test GET /jobs/{id}/audio returns 404 for invalid job ID."""
        response = await client.get('/jobs/nonexistent-id/audio')

        assert response.status_code == 404
