"""
Task Group 6: Integration Tests

End-to-end workflow tests and integration verification.
"""
import asyncio
from unittest.mock import MagicMock, patch, AsyncMock

import pytest
import pytest_asyncio

from app.models.job import JobStatus


class TestEndToEndWorkflow:
    """Tests for complete job workflow."""

    @pytest.mark.asyncio
    async def test_create_job_returns_immediately(self, client):
        """Test POST /jobs returns immediately with pending status."""
        response = await client.post('/jobs', json={'text': 'Hello world'})

        assert response.status_code == 201
        data = response.json()
        assert data['status'] == 'pending'
        # Should return quickly (not wait for processing)
        assert 'id' in data

    @pytest.mark.asyncio
    async def test_job_list_after_creation(self, client):
        """Test job appears in list after creation."""
        # Create a job
        create_response = await client.post('/jobs', json={'text': 'Test job'})
        job_id = create_response.json()['id']

        # List jobs
        list_response = await client.get('/jobs')
        data = list_response.json()

        job_ids = [job['id'] for job in data['jobs']]
        assert job_id in job_ids

    @pytest.mark.asyncio
    async def test_job_details_accessible(self, client):
        """Test job details can be retrieved after creation."""
        # Create a job
        create_response = await client.post('/jobs', json={
            'text': 'Detailed job',
            'voice_id': 'jerry-seinfeld',
        })
        job_id = create_response.json()['id']

        # Get job details
        detail_response = await client.get(f'/jobs/{job_id}')
        data = detail_response.json()

        assert data['id'] == job_id
        assert data['text'] == 'Detailed job'
        assert data['voice_id'] == 'jerry-seinfeld'
        assert 'created_at' in data


class TestVoiceSelection:
    """Tests for voice selection in job creation."""

    @pytest.mark.asyncio
    async def test_create_job_with_valid_voice(self, client):
        """Test creating job with valid voice_id."""
        response = await client.post('/jobs', json={
            'text': 'Hello',
            'voice_id': 'jerry-seinfeld',
        })

        assert response.status_code == 201
        data = response.json()
        assert data['voice_id'] == 'jerry-seinfeld'

    @pytest.mark.asyncio
    async def test_create_job_with_null_voice(self, client):
        """Test creating job with null voice uses default."""
        response = await client.post('/jobs', json={
            'text': 'Hello',
            'voice_id': None,
        })

        assert response.status_code == 201
        data = response.json()
        assert data['voice_id'] is None

    @pytest.mark.asyncio
    async def test_create_job_without_voice(self, client):
        """Test creating job without voice_id parameter."""
        response = await client.post('/jobs', json={
            'text': 'Hello',
        })

        assert response.status_code == 201
        data = response.json()
        assert data['voice_id'] is None


class TestErrorHandling:
    """Tests for error handling."""

    @pytest.mark.asyncio
    async def test_missing_text_returns_422(self, client):
        """Test missing text field returns validation error."""
        response = await client.post('/jobs', json={})

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_empty_text_returns_422(self, client):
        """Test empty text field returns validation error."""
        response = await client.post('/jobs', json={'text': ''})

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_invalid_job_id_returns_404(self, client):
        """Test invalid job ID returns 404."""
        response = await client.get('/jobs/invalid-uuid-12345')

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_invalid_voice_id_returns_404(self, client, mock_tts_service):
        """Test invalid voice ID returns 404."""
        mock_tts_service.get_voice.return_value = None

        response = await client.get('/voices/invalid-voice')

        assert response.status_code == 404


class TestConcurrentRequests:
    """Tests for handling concurrent requests."""

    @pytest.mark.asyncio
    async def test_multiple_jobs_queued_correctly(self, client):
        """Test multiple concurrent job creations are queued."""
        # Create multiple jobs concurrently
        texts = [f'Job {i}' for i in range(5)]

        responses = await asyncio.gather(*[
            client.post('/jobs', json={'text': text})
            for text in texts
        ])

        # All should succeed with pending status
        for response in responses:
            assert response.status_code == 201
            assert response.json()['status'] == 'pending'

        # All should appear in job list
        list_response = await client.get('/jobs?limit=100')
        data = list_response.json()

        created_texts = [job['text'] for job in data['jobs']]
        for text in texts:
            assert text in created_texts


class TestHistoryManagement:
    """Tests for history management."""

    @pytest.mark.asyncio
    async def test_bulk_delete_clears_all_jobs(self, client):
        """Test DELETE /jobs clears all job history."""
        # Create some jobs
        for i in range(3):
            await client.post('/jobs', json={'text': f'Job {i}'})

        # Verify jobs exist
        list_before = await client.get('/jobs')
        assert list_before.json()['total'] > 0

        # Delete all
        delete_response = await client.delete('/jobs')
        assert delete_response.status_code == 204

        # Verify all cleared
        list_after = await client.get('/jobs')
        assert list_after.json()['total'] == 0

    @pytest.mark.asyncio
    async def test_individual_job_deletion(self, client):
        """Test individual job can be deleted."""
        # Create jobs
        response1 = await client.post('/jobs', json={'text': 'Keep me'})
        response2 = await client.post('/jobs', json={'text': 'Delete me'})

        job_to_delete = response2.json()['id']
        job_to_keep = response1.json()['id']

        # Delete one job
        await client.delete(f'/jobs/{job_to_delete}')

        # Verify correct job deleted
        get_deleted = await client.get(f'/jobs/{job_to_delete}')
        assert get_deleted.status_code == 404

        get_kept = await client.get(f'/jobs/{job_to_keep}')
        assert get_kept.status_code == 200


class TestAPIDocumentation:
    """Tests for API documentation."""

    @pytest.mark.asyncio
    async def test_openapi_schema_available(self, client):
        """Test OpenAPI schema is available at /openapi.json."""
        response = await client.get('/openapi.json')

        assert response.status_code == 200
        data = response.json()
        assert 'paths' in data
        assert 'info' in data

    @pytest.mark.asyncio
    async def test_openapi_includes_endpoints(self, client):
        """Test OpenAPI schema includes all endpoints."""
        response = await client.get('/openapi.json')
        data = response.json()

        paths = data['paths']
        assert '/health' in paths
        assert '/voices' in paths
        assert '/voices/{voice_id}' in paths
        assert '/jobs' in paths
        assert '/jobs/{job_id}' in paths
        assert '/jobs/{job_id}/audio' in paths
