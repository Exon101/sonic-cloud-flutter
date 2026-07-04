"""
Generate a short tone-burst WAV file to ship with the demo so just_audio
has something real to play even when the device is offline or network
images can't load.

We generate a 5-second 440Hz sine tone at 16-bit / 44.1kHz mono — about
440 KB. Small enough to ship in-repo, big enough to demo position/seek.
"""
import math
import struct
import wave
import os

OUT = "/home/z/my-project/download/sonic_cloud_flutter/assets/audio/sample_track.wav"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

SAMPLE_RATE = 44100
DURATION_S = 5.0  # matches the mock track "Ethereal Resonance" 5:00 (mock)
FREQ = 220.0      # A3 — pleasant low tone

n_samples = int(SAMPLE_RATE * DURATION_S)

with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)  # 16-bit
    w.setframerate(SAMPLE_RATE)
    # 1Hz LFO amplitude wobble for some audible "wave" character
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Slight fade in/out (50ms) to avoid clicks
        fade = 1.0
        fade_s = 0.05
        if t < fade_s:
            fade = t / fade_s
        elif t > DURATION_S - fade_s:
            fade = (DURATION_S - t) / fade_s
        amp = 0.25 * fade * (0.7 + 0.3 * math.sin(2 * math.pi * 1.0 * t))
        sample = int(amp * math.sin(2 * math.pi * FREQ * t) * 32767)
        w.writeframes(struct.pack("<h", sample))

print(f"Wrote {OUT} ({os.path.getsize(OUT)} bytes)")
