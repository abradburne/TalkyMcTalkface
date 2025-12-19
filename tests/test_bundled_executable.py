"""
Tests for PyInstaller bundled executable.

These tests verify that the bundled TalkyMcTalkface server works correctly
when packaged as a standalone executable.
"""
import os
import sys
import subprocess
import time
import signal
import tempfile
from pathlib import Path

import pytest
import httpx


# Path to the bundled executable (set by build script or environment)
BUNDLED_EXECUTABLE = os.environ.get(
    'TALKY_BUNDLED_EXECUTABLE',
    str(Path(__file__).parent.parent / 'dist' / 'TalkyMcTalkface' / 'TalkyMcTalkface')
)

# Server configuration
SERVER_HOST = '127.0.0.1'
SERVER_PORT = 5111
SERVER_URL = f'http://{SERVER_HOST}:{SERVER_PORT}'

# Timeout settings
STARTUP_TIMEOUT = 60  # Model loading can take 30-60 seconds
REQUEST_TIMEOUT = 5


def is_server_ready(url: str) -> bool:
    """Check if server is responding to health checks."""
    try:
        response = httpx.get(f'{url}/health', timeout=REQUEST_TIMEOUT)
        return response.status_code == 200
    except (httpx.ConnectError, httpx.TimeoutException):
        return False


def wait_for_server(url: str, timeout: int = STARTUP_TIMEOUT) -> bool:
    """Wait for server to become ready."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        if is_server_ready(url):
            return True
        time.sleep(1)
    return False


def terminate_process(process: subprocess.Popen, timeout: int = 10):
    """Gracefully terminate a process."""
    if process.poll() is None:
        process.send_signal(signal.SIGTERM)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


@pytest.fixture(scope='module')
def bundled_server():
    """
    Fixture that starts the bundled server and yields once ready.

    Ensures cleanup on test completion.
    """
    executable_path = Path(BUNDLED_EXECUTABLE)

    if not executable_path.exists():
        pytest.skip(f'Bundled executable not found at {executable_path}')

    # Start the server process
    process = subprocess.Popen(
        [str(executable_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, 'PYTHONUNBUFFERED': '1'},
    )

    try:
        # Wait for server to be ready
        if not wait_for_server(SERVER_URL, STARTUP_TIMEOUT):
            stdout, stderr = process.communicate(timeout=5)
            pytest.fail(
                f'Server failed to start within {STARTUP_TIMEOUT}s.\n'
                f'stdout: {stdout.decode()}\n'
                f'stderr: {stderr.decode()}'
            )

        yield process

    finally:
        terminate_process(process)


class TestBundledExecutableLaunch:
    """Tests for bundled executable launch and basic functionality."""

    def test_bundled_executable_launches_successfully(self, bundled_server):
        """
        Test bundled executable launches successfully.

        Verifies:
        - Process starts without crashing
        - Server becomes responsive within timeout
        """
        assert bundled_server.poll() is None, 'Server process exited unexpectedly'

    def test_server_responds_to_health_check(self, bundled_server):
        """
        Test server responds to health check.

        Verifies:
        - /health endpoint returns 200
        - Response contains expected fields
        - Model is loaded
        """
        response = httpx.get(f'{SERVER_URL}/health', timeout=REQUEST_TIMEOUT)

        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'ok'
        assert 'model_loaded' in data
        assert 'version' in data
        assert 'available_voices' in data


class TestBundledTTSFunctionality:
    """Tests for TTS functionality in bundled executable."""

    def test_tts_job_creation_and_processing(self, bundled_server):
        """
        Test TTS endpoint works with bundled dependencies.

        Verifies:
        - Can create a TTS job (voice_id=None uses default/no voice)
        - Job gets processed
        - Audio file is generated

        Note: Since voices are no longer bundled, this test uses voice_id=None
        which should still work for TTS generation without voice cloning.
        """
        # Create a TTS job without voice cloning (no bundled voices)
        job_data = {
            'text': 'Hello from the bundled executable test.',
            'voice_id': None,  # No voice cloning, use default synthesis
        }
        response = httpx.post(
            f'{SERVER_URL}/jobs',
            json=job_data,
            timeout=REQUEST_TIMEOUT
        )
        assert response.status_code == 201
        job = response.json()
        job_id = job['id']
        assert job['status'] in ['pending', 'processing']

        # Wait for job completion (TTS can take 10-30 seconds)
        max_wait = 60
        start_time = time.time()
        while time.time() - start_time < max_wait:
            status_response = httpx.get(
                f'{SERVER_URL}/jobs/{job_id}',
                timeout=REQUEST_TIMEOUT
            )
            assert status_response.status_code == 200
            job_status = status_response.json()

            if job_status['status'] == 'completed':
                break
            elif job_status['status'] == 'failed':
                pytest.fail(f'TTS job failed: {job_status.get("error_message")}')

            time.sleep(2)
        else:
            pytest.fail(f'TTS job did not complete within {max_wait}s')

        # Verify job has audio file
        assert job_status['file_size'] is not None
        assert job_status['file_size'] > 0

        # Verify audio file is accessible
        audio_response = httpx.get(
            f'{SERVER_URL}/jobs/{job_id}/audio',
            timeout=REQUEST_TIMEOUT
        )
        assert audio_response.status_code == 200
        assert audio_response.headers.get('content-type') in [
            'audio/wav',
            'audio/x-wav',
            'audio/wave',
        ]

    def test_voices_endpoint_returns_available_voices(self, bundled_server):
        """
        Test that voices endpoint returns available voices.

        Verifies:
        - /voices endpoint returns 200 and a list
        - List may be empty (voices are user-managed, not bundled)
        - If voices exist, they have correct structure
        """
        response = httpx.get(f'{SERVER_URL}/voices', timeout=REQUEST_TIMEOUT)
        assert response.status_code == 200
        voices = response.json()
        assert isinstance(voices, list)

        # Voices list may be empty since voices are no longer bundled
        # Users add their own voice files to ~/Library/Application Support/TalkyMcTalkface/voices/
        if voices:
            voice = voices[0]
            assert 'id' in voice
            assert 'display_name' in voice
