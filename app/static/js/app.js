/**
 * TalkyMcTalkface Web UI Application
 *
 * Handles voice selection, TTS job submission, status polling,
 * audio playback, and recent jobs management.
 */

// Constants
const POLL_INTERVAL = 750; // ms
const STORAGE_KEY = 'talky_selected_voice';

// DOM Elements
const voiceSelect = document.getElementById('voice-select');
const textInput = document.getElementById('text-input');
const charCounter = document.getElementById('char-counter');
const ttsForm = document.getElementById('tts-form');
const submitBtn = document.getElementById('submit-btn');
const submitText = document.getElementById('submit-text');
const submitSpinner = document.getElementById('submit-spinner');
const audioSection = document.getElementById('audio-section');
const audioPlayer = document.getElementById('audio-player');
const downloadBtn = document.getElementById('download-btn');
const errorAlert = document.getElementById('error-alert');
const errorMessage = document.getElementById('error-message');
const errorDismiss = document.getElementById('error-dismiss');
const jobsList = document.getElementById('jobs-list');
const jobsEmpty = document.getElementById('jobs-empty');

// State
let currentPollingInterval = null;

/**
 * Initialize the application
 */
async function init() {
  // Load voices
  await loadVoices();

  // Load recent jobs
  await loadRecentJobs();

  // Set up event listeners
  textInput.addEventListener('input', updateCharCounter);
  ttsForm.addEventListener('submit', handleFormSubmit);
  errorDismiss.addEventListener('click', hideError);

  // Handle autoplay restrictions
  audioPlayer.addEventListener('play', () => {
    // Audio started playing successfully
  });

  audioPlayer.addEventListener('error', (e) => {
    if (audioPlayer.src) {
      showError('Failed to load audio file');
    }
  });
}

/**
 * Load voices from the API and populate the dropdown
 */
async function loadVoices() {
  try {
    const response = await fetch('/voices');
    if (!response.ok) {
      throw new Error('Failed to fetch voices');
    }

    const data = await response.json();
    const voices = data.voices || [];

    if (voices.length === 0) {
      showError('No voices available. Please add voice prompts to the prompts/ directory.');
      return;
    }

    // Clear all existing options
    while (voiceSelect.options.length > 0) {
      voiceSelect.remove(0);
    }

    // Add default voice option first
    const defaultOption = document.createElement('option');
    defaultOption.value = '';  // Empty value means default/no voice_id
    defaultOption.textContent = 'Chatterbox (Default)';
    voiceSelect.appendChild(defaultOption);

    // Add voice options from API
    voices.forEach(voice => {
      const option = document.createElement('option');
      option.value = voice.id;
      option.textContent = voice.display_name;
      voiceSelect.appendChild(option);
    });

    // Restore last selected voice from localStorage
    const savedVoice = localStorage.getItem(STORAGE_KEY);
    if (savedVoice && voiceSelect.querySelector(`option[value="${savedVoice}"]`)) {
      voiceSelect.value = savedVoice;
    }
  } catch (error) {
    console.error('Error loading voices:', error);
    showError('Failed to load voices. Please refresh the page.');
  }
}

/**
 * Load recent jobs from the API
 */
async function loadRecentJobs() {
  try {
    const response = await fetch('/jobs?limit=20');
    if (!response.ok) {
      throw new Error('Failed to fetch jobs');
    }

    const data = await response.json();
    const jobs = data.jobs || [];

    renderJobsList(jobs);
  } catch (error) {
    console.error('Error loading jobs:', error);
    // Don't show error for jobs loading failure - not critical
  }
}

/**
 * Render the jobs list
 */
function renderJobsList(jobs) {
  if (jobs.length === 0) {
    jobsEmpty.classList.remove('hidden');
    // Remove any job items but keep the empty message
    const jobItems = jobsList.querySelectorAll('.job-item');
    jobItems.forEach(item => item.remove());
    return;
  }

  jobsEmpty.classList.add('hidden');

  // Clear existing job items
  const existingItems = jobsList.querySelectorAll('.job-item');
  existingItems.forEach(item => item.remove());

  // Add job items
  jobs.forEach(job => {
    const jobItem = createJobItem(job);
    jobsList.appendChild(jobItem);
  });
}

/**
 * Create an SVG element for icons
 */
function createSvgIcon(pathD, additionalPath) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', 'w-4 h-4');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('viewBox', '0 0 24 24');

  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('stroke-linecap', 'round');
  path.setAttribute('stroke-linejoin', 'round');
  path.setAttribute('stroke-width', '2');
  path.setAttribute('d', pathD);
  svg.appendChild(path);

  if (additionalPath) {
    const path2 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path2.setAttribute('stroke-linecap', 'round');
    path2.setAttribute('stroke-linejoin', 'round');
    path2.setAttribute('stroke-width', '2');
    path2.setAttribute('d', additionalPath);
    svg.appendChild(path2);
  }

  return svg;
}

/**
 * Create a job list item element using safe DOM methods
 */
function createJobItem(job) {
  const item = document.createElement('div');
  item.className = 'job-item';
  item.dataset.jobId = job.id;

  // Create content container
  const content = document.createElement('div');
  content.className = 'job-item-content';

  // Text preview (truncated)
  const textDiv = document.createElement('div');
  textDiv.className = 'job-item-text';
  const textPreview = job.text.length > 50 ? job.text.substring(0, 50) + '...' : job.text;
  textDiv.textContent = textPreview;
  content.appendChild(textDiv);

  // Meta information
  const meta = document.createElement('div');
  meta.className = 'job-item-meta';

  const voiceSpan = document.createElement('span');
  voiceSpan.className = 'job-item-voice';
  voiceSpan.textContent = job.voice_id || 'Default';
  meta.appendChild(voiceSpan);

  const bullet1 = document.createElement('span');
  bullet1.textContent = '\u2022';
  meta.appendChild(bullet1);

  const statusSpan = document.createElement('span');
  statusSpan.className = `job-item-status ${job.status}`;
  statusSpan.textContent = job.status;
  meta.appendChild(statusSpan);

  const bullet2 = document.createElement('span');
  bullet2.textContent = '\u2022';
  meta.appendChild(bullet2);

  const timeSpan = document.createElement('span');
  timeSpan.textContent = formatRelativeTime(job.created_at);
  meta.appendChild(timeSpan);

  content.appendChild(meta);
  item.appendChild(content);

  // Actions container
  const actions = document.createElement('div');
  actions.className = 'job-item-actions';

  if (job.status === 'completed') {
    // Replay button
    const replayBtn = document.createElement('button');
    replayBtn.className = 'job-action-btn replay-btn';
    replayBtn.title = 'Play';
    replayBtn.appendChild(createSvgIcon(
      'M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z',
      'M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    ));
    replayBtn.addEventListener('click', () => {
      playJobAudio(job.id, job.voice_id, job.created_at);
    });
    actions.appendChild(replayBtn);

    // Download link
    const downloadLink = document.createElement('a');
    downloadLink.className = 'job-action-btn download-link';
    downloadLink.href = `/jobs/${job.id}/audio`;
    downloadLink.download = `${job.voice_id || 'default'}-${formatTimestampForFilename(job.created_at)}.wav`;
    downloadLink.title = 'Download';
    downloadLink.appendChild(createSvgIcon(
      'M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4'
    ));
    actions.appendChild(downloadLink);
  }

  item.appendChild(actions);

  return item;
}

/**
 * Play audio for a specific job
 */
function playJobAudio(jobId, voiceId, createdAt) {
  audioSection.classList.remove('hidden');
  audioPlayer.src = `/jobs/${jobId}/audio`;
  downloadBtn.href = `/jobs/${jobId}/audio`;
  downloadBtn.download = `${voiceId}-${formatTimestampForFilename(createdAt)}.wav`;

  audioPlayer.play().catch(error => {
    console.warn('Autoplay blocked:', error);
    // User will need to click play manually
  });
}

/**
 * Update character counter
 */
function updateCharCounter() {
  const count = textInput.value.length;
  charCounter.textContent = `${count} character${count !== 1 ? 's' : ''}`;
}

/**
 * Handle form submission
 */
async function handleFormSubmit(event) {
  event.preventDefault();

  const text = textInput.value.trim();
  const voiceId = voiceSelect.value;

  // Validate
  if (!text) {
    showError('Please enter some text to speak.');
    return;
  }

  // Voice is optional - empty means default voice

  // Save voice selection to localStorage (even if empty)
  localStorage.setItem(STORAGE_KEY, voiceId);

  // Disable form and show loading state
  setFormLoading(true);
  hideError();

  try {
    // Submit job
    const response = await fetch('/jobs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text, voice_id: voiceId || null }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || 'Failed to submit job');
    }

    const job = await response.json();

    // Start polling for job status
    pollJobStatus(job.id);
  } catch (error) {
    console.error('Error submitting job:', error);
    showError(error.message || 'Failed to submit job. Please try again.');
    setFormLoading(false);
  }
}

/**
 * Poll for job status until completed or failed
 */
function pollJobStatus(jobId) {
  // Clear any existing polling
  if (currentPollingInterval) {
    clearInterval(currentPollingInterval);
  }

  currentPollingInterval = setInterval(async () => {
    try {
      const response = await fetch(`/jobs/${jobId}`);
      if (!response.ok) {
        throw new Error('Failed to fetch job status');
      }

      const job = await response.json();

      if (job.status === 'completed') {
        // Stop polling
        clearInterval(currentPollingInterval);
        currentPollingInterval = null;

        // Play audio
        audioSection.classList.remove('hidden');
        audioPlayer.src = `/jobs/${jobId}/audio`;
        downloadBtn.href = `/jobs/${jobId}/audio`;
        downloadBtn.download = `${job.voice_id}-${formatTimestampForFilename(job.created_at)}.wav`;

        // Auto-play
        audioPlayer.play().catch(error => {
          console.warn('Autoplay blocked:', error);
          // User will need to click play manually
        });

        // Re-enable form
        setFormLoading(false);

        // Refresh jobs list
        loadRecentJobs();
      } else if (job.status === 'failed') {
        // Stop polling
        clearInterval(currentPollingInterval);
        currentPollingInterval = null;

        // Show error
        showError(job.error_message || 'Job failed. Please try again.');

        // Re-enable form
        setFormLoading(false);

        // Refresh jobs list
        loadRecentJobs();
      }
      // Continue polling for pending/processing
    } catch (error) {
      console.error('Error polling job status:', error);
      clearInterval(currentPollingInterval);
      currentPollingInterval = null;
      showError('Lost connection while processing. Please check the job status.');
      setFormLoading(false);
    }
  }, POLL_INTERVAL);
}

/**
 * Set form loading state
 */
function setFormLoading(loading) {
  voiceSelect.disabled = loading;
  textInput.disabled = loading;
  submitBtn.disabled = loading;

  if (loading) {
    submitText.textContent = 'Generating...';
    submitSpinner.classList.remove('hidden');
  } else {
    submitText.textContent = 'Generate Speech';
    submitSpinner.classList.add('hidden');
  }
}

/**
 * Show error message
 */
function showError(message) {
  errorMessage.textContent = message;
  errorAlert.classList.remove('hidden');
}

/**
 * Hide error message
 */
function hideError() {
  errorAlert.classList.add('hidden');
  errorMessage.textContent = '';
}

/**
 * Format relative timestamp (e.g., "2 minutes ago")
 */
function formatRelativeTime(timestamp) {
  // Python returns timestamps without timezone - treat as local time
  // Append 'Z' if no timezone info to force UTC, then it displays correctly
  let dateString = timestamp;
  if (!timestamp.includes('Z') && !timestamp.includes('+') && !timestamp.includes('-', 10)) {
    // No timezone info - the server returns UTC times, so add Z
    dateString = timestamp + 'Z';
  }
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now - date;
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSeconds < 60) {
    return 'just now';
  } else if (diffMinutes < 60) {
    return `${diffMinutes} minute${diffMinutes !== 1 ? 's' : ''} ago`;
  } else if (diffHours < 24) {
    return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
  } else if (diffDays < 7) {
    return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
  } else {
    return date.toLocaleDateString();
  }
}

/**
 * Format timestamp for filename
 */
function formatTimestampForFilename(timestamp) {
  // Python returns timestamps without timezone - treat as UTC
  let dateString = timestamp;
  if (!timestamp.includes('Z') && !timestamp.includes('+') && !timestamp.includes('-', 10)) {
    dateString = timestamp + 'Z';
  }
  const date = new Date(dateString);
  return date.toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', init);
