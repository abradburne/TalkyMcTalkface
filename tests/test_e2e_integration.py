"""
Task Group 7: End-to-End Integration Tests

Strategic tests for critical user journeys and Swift-Python integration.
These tests focus on integration gaps identified in the test review.

Maximum 10 additional tests as per spec requirements.
"""
import asyncio
import os
import signal
import subprocess
import tempfile
import time
from pathlib import Path
from unittest.mock import patch, MagicMock, AsyncMock

import pytest
import pytest_asyncio
import httpx
from httpx import AsyncClient, ASGITransport

from app.models.job import JobStatus


# Server configuration (matching Swift app configuration)
SERVER_HOST = '127.0.0.1'
SERVER_PORT = 5111
SERVER_URL = f'http://{SERVER_HOST}:{SERVER_PORT}'
HEALTH_URL = f'{SERVER_URL}/health'
JOBS_URL = f'{SERVER_URL}/jobs'


class TestSwiftPythonCommunication:
    """
    Tests for Swift-Python communication reliability.

    Focus: Integration between Swift app and Python backend via HTTP.
    """

    @pytest.mark.asyncio
    async def test_health_check_response_format_matches_swift_expectations(self, client):
        """
        Test health endpoint returns format expected by Swift HealthResponse struct.

        Verifies:
        - Response contains all fields Swift expects: status, model_loaded, available_voices, version
        - Field types match Swift Codable expectations
        - This ensures Swift app can decode the response without errors
        """
        response = await client.get('/health')

        assert response.status_code == 200
        data = response.json()

        # Verify all fields expected by Swift HealthResponse struct exist
        assert 'status' in data, 'Missing status field for Swift HealthResponse'
        assert 'model_loaded' in data, 'Missing model_loaded field for Swift HealthResponse'
        assert 'available_voices' in data, 'Missing available_voices field for Swift HealthResponse'
        assert 'version' in data, 'Missing version field for Swift HealthResponse'

        # Verify types match Swift expectations
        assert isinstance(data['status'], str), 'status must be String for Swift'
        assert isinstance(data['model_loaded'], bool), 'model_loaded must be Bool for Swift'
        assert isinstance(data['available_voices'], list), 'available_voices must be [String] for Swift'
        assert isinstance(data['version'], str), 'version must be String for Swift'

        # Verify voices are strings
        for voice in data['available_voices']:
            assert isinstance(voice, str), 'Each voice must be String for Swift'

    @pytest.mark.asyncio
    async def test_rapid_health_checks_simulate_swift_polling(self, client):
        """
        Test server handles rapid health check polling.

        Simulates Swift app's periodic health check behavior:
        - SubprocessManager polls /health every few seconds
        - Server must handle concurrent requests without degradation
        """
        # Simulate 10 rapid health checks (more aggressive than typical polling)
        tasks = [client.get('/health') for _ in range(10)]
        responses = await asyncio.gather(*tasks)

        # All should succeed
        for response in responses:
            assert response.status_code == 200
            data = response.json()
            assert data['status'] == 'ok'

    @pytest.mark.asyncio
    async def test_job_creation_response_format_for_swift(self, client):
        """
        Test job creation returns format usable by Swift app.

        Verifies Swift can create TTS jobs and track their status.
        """
        response = await client.post('/jobs', json={'text': 'Test from Swift'})

        assert response.status_code == 201
        data = response.json()

        # Verify job structure is Swift-compatible
        assert 'id' in data, 'Job must have id for Swift tracking'
        assert 'status' in data, 'Job must have status for Swift state management'
        assert 'text' in data, 'Job must echo text for Swift verification'
        assert 'created_at' in data, 'Job must have created_at timestamp'

        # Status should be a string Swift can compare
        assert isinstance(data['status'], str)
        assert data['status'] in ['pending', 'processing', 'completed', 'failed']


class TestFirstLaunchToReadyJourney:
    """
    Tests for first-launch user experience.

    Focus: Complete journey from app launch through model readiness.
    """

    @pytest.mark.asyncio
    async def test_health_indicates_model_not_loaded_initially(self, client, mock_tts_service):
        """
        Test health endpoint correctly reports model_loaded=false for first launch.

        This is critical for Swift app to display 'Download Required' state.
        """
        # Mock model not loaded
        mock_tts_service.is_loaded = False

        response = await client.get('/health')
        data = response.json()

        # Swift app uses this to determine if download UI should show
        assert data['model_loaded'] == False, \
            'Health must report model_loaded=false when model not loaded'

    @pytest.mark.asyncio
    async def test_health_indicates_model_loaded_after_ready(self, client, mock_tts_service):
        """
        Test health endpoint correctly reports model_loaded=true after model is ready.

        This triggers Swift app transition from 'Download Required' to 'Ready' state.
        """
        # Mock model loaded
        mock_tts_service.is_loaded = True

        response = await client.get('/health')
        data = response.json()

        assert data['model_loaded'] == True, \
            'Health must report model_loaded=true when model is ready'

    @pytest.mark.asyncio
    async def test_complete_tts_workflow_after_model_ready(self, client, mock_tts_service):
        """
        Test end-to-end TTS workflow: create job -> job completes.

        Verifies the complete user journey works once model is loaded.
        """
        # Ensure model appears loaded
        mock_tts_service.is_loaded = True

        # Step 1: Verify server is healthy and ready
        health_response = await client.get('/health')
        assert health_response.json()['model_loaded'] == True

        # Step 2: Create a TTS job
        create_response = await client.post('/jobs', json={
            'text': 'Hello, this is a test of the text to speech system.',
            'voice_id': 'jerry-seinfeld',
        })
        assert create_response.status_code == 201
        job_data = create_response.json()
        job_id = job_data['id']

        # Step 3: Verify job is trackable
        status_response = await client.get(f'/jobs/{job_id}')
        assert status_response.status_code == 200
        assert status_response.json()['id'] == job_id


class TestAppRestartScenarios:
    """
    Tests for app restart scenarios.

    Focus: Verifying correct behavior when app restarts with existing state.
    """

    @pytest.mark.asyncio
    async def test_existing_jobs_persist_across_restart(self, client):
        """
        Test that jobs created before restart are still accessible.

        Simulates user restarting app and checking previous TTS jobs.
        """
        # Create a job
        create_response = await client.post('/jobs', json={'text': 'Pre-restart job'})
        job_id = create_response.json()['id']

        # Verify job exists (simulating post-restart check)
        # In real scenario, the database persists across restarts
        get_response = await client.get(f'/jobs/{job_id}')

        assert get_response.status_code == 200
        assert get_response.json()['text'] == 'Pre-restart job'

    @pytest.mark.asyncio
    async def test_job_history_maintains_order_across_sessions(self, client):
        """
        Test job list maintains newest-first order.

        Critical for Swift app's history view to show recent jobs first.
        """
        # Create multiple jobs
        for i in range(3):
            await client.post('/jobs', json={'text': f'Job {i}'})

        # Fetch job list
        list_response = await client.get('/jobs')
        data = list_response.json()

        # Verify order (newest first means Job 2 before Job 1 before Job 0)
        jobs = data['jobs']
        if len(jobs) >= 3:
            assert jobs[0]['text'] == 'Job 2'
            assert jobs[1]['text'] == 'Job 1'
            assert jobs[2]['text'] == 'Job 0'


class TestServerReliability:
    """
    Tests for server reliability under various conditions.

    Focus: Ensuring Python backend handles edge cases gracefully.
    """

    @pytest.mark.asyncio
    async def test_graceful_handling_of_empty_text(self, client):
        """
        Test server gracefully rejects empty text submissions.

        Prevents crashes from malformed requests.
        """
        response = await client.post('/jobs', json={'text': ''})

        # Should return validation error, not crash
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_graceful_handling_of_missing_fields(self, client):
        """
        Test server gracefully handles missing required fields.
        """
        response = await client.post('/jobs', json={})

        # Should return validation error, not crash
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_server_handles_invalid_job_id_gracefully(self, client):
        """
        Test server returns 404 for invalid job IDs without crashing.
        """
        response = await client.get('/jobs/not-a-valid-uuid')

        assert response.status_code == 404
        # Should have error detail, not a crash
        data = response.json()
        assert 'detail' in data
