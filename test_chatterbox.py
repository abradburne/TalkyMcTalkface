# Patch Perth watermarker for macOS compatibility
import perth
perth.PerthImplicitWatermarker = perth.DummyWatermarker

from chatterbox.tts_turbo import ChatterboxTurboTTS
import torchaudio as ta

# Use MPS for Apple Silicon (not cuda)
model = ChatterboxTurboTTS.from_pretrained(device='mps')

text = 'Hi there, how are you? This is a test of Chatterbox TTS.'
wav = model.generate(text)
ta.save('output.wav', wav, model.sr)
print('Saved output.wav')
