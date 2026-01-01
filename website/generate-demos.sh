#!/bin/bash
# Generate demo audio samples for the TalkyMcTalkface website
# Make sure the TalkyMcTalkface app is running before executing this script

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/audio/samples"

echo "Generating demo audio samples..."
echo "Make sure TalkyMcTalkface is running!"
echo ""

# Check if server is accessible
if ! curl -s http://127.0.0.1:5111/health > /dev/null 2>&1; then
  echo "Error: Cannot connect to TalkyMcTalkface server at http://127.0.0.1:5111"
  echo "Please start the TalkyMcTalkface app first."
  exit 1
fi

# List available voices
echo "Available voices:"
curl -s http://127.0.0.1:5111/voices | jq -r '.[] | "  - \(.id): \(.name)"' 2>/dev/null || \
  curl -s http://127.0.0.1:5111/voices
echo ""

# Function to generate and download a sample
generate_sample() {
  local text="$1"
  local voice="$2"
  local output="$3"

  echo "Generating: $output (voice: $voice)"

  # Create job
  response=$(curl -s -X POST http://127.0.0.1:5111/jobs \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$text\", \"voice_id\": \"$voice\"}")

  job_id=$(echo "$response" | jq -r '.id' 2>/dev/null)

  if [ -z "$job_id" ] || [ "$job_id" = "null" ]; then
    echo "  Error creating job: $response"
    return 1
  fi

  echo "  Job ID: $job_id"

  # Wait for job to complete
  echo "  Waiting for generation..."
  for i in {1..60}; do
    status=$(curl -s "http://127.0.0.1:5111/jobs/$job_id" | jq -r '.status' 2>/dev/null)
    if [ "$status" = "completed" ]; then
      break
    elif [ "$status" = "failed" ]; then
      echo "  Job failed!"
      return 1
    fi
    sleep 2
  done

  # Download audio
  curl -s "http://127.0.0.1:5111/jobs/$job_id/audio" -o "$output"
  echo "  Saved: $output"
  echo ""
}

# Generate samples - adjust voice IDs to match your available voices
# Run `curl http://127.0.0.1:5111/voices` to see your voice IDs

# Using your available voice IDs (with spaces)
generate_sample \
  "Hello! I'm demonstrating the voice cloning capabilities of TalkyMcTalkface." \
  "Alan Rickman" \
  "$OUTPUT_DIR/demo-1.wav"

generate_sample \
  "This is just a quick demonstration of how realistic AI-generated speech can sound." \
  "Joanna Lumley" \
  "$OUTPUT_DIR/demo-2.wav"

generate_sample \
  "Remember, always use voice cloning technology responsibly and with consent." \
  "C3-PO" \
  "$OUTPUT_DIR/demo-3.wav"

echo "Done! Demo audio files saved to: $OUTPUT_DIR"
